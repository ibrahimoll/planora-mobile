import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../storage/token_storage.dart';
import 'push_notification_api.dart';

class PushNotificationPayload {
  final String? messageId;
  final String title;
  final String body;
  final Map<String, String> data;

  const PushNotificationPayload({
    this.messageId,
    required this.title,
    required this.body,
    required this.data,
  });

  factory PushNotificationPayload.fromRemoteMessage(RemoteMessage message) {
    final data = message.data.map(
      (key, value) => MapEntry(key, value.toString()),
    );

    final title = _firstNonEmpty([
      message.notification?.title,
      data['title'],
      data['notification_title'],
    ]);

    final body = _firstNonEmpty([
      message.notification?.body,
      data['body'],
      data['message'],
      data['notification_body'],
    ]);

    return PushNotificationPayload(
      messageId: message.messageId,
      title: title ?? 'Planora update',
      body: body ?? 'Tap to view your latest update.',
      data: data,
    );
  }

  factory PushNotificationPayload.fromLocalPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) {
      return const PushNotificationPayload(
        title: 'Planora update',
        body: 'Tap to view your latest update.',
        data: {},
      );
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        return const PushNotificationPayload(
          title: 'Planora update',
          body: 'Tap to view your latest update.',
          data: {},
        );
      }

      final rawData = decoded['data'];
      final data = <String, String>{};
      if (rawData is Map) {
        for (final entry in rawData.entries) {
          data[entry.key.toString()] = entry.value.toString();
        }
      }

      return PushNotificationPayload(
        messageId: decoded['message_id']?.toString(),
        title: (decoded['title'] ?? data['title'] ?? 'Planora update')
            .toString(),
        body: (decoded['body'] ?? data['message'] ?? data['body'] ?? '')
            .toString(),
        data: data,
      );
    } catch (error, stackTrace) {
      debugPrint('Planora local notification payload decode failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const PushNotificationPayload(
        title: 'Planora update',
        body: 'Tap to view your latest update.',
        data: {},
      );
    }
  }

  String toLocalPayload() {
    return jsonEncode({
      'message_id': messageId,
      'title': title,
      'body': body,
      'data': data,
    });
  }

  String get type => _firstNonEmpty([
        data['type'],
        data['notification_type'],
        data['event_type'],
        data['category'],
      ]) ?? 'system';

  int? intValue(String key) {
    return int.tryParse(data[key]?.toString() ?? '');
  }

  static String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final cleaned = value?.trim();
      if (cleaned != null && cleaned.isNotEmpty) {
        return cleaned;
      }
    }

    return null;
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const String _deviceKeyKey = 'planora_push_device_key';
  static const String _deviceTokenIdKey = 'planora_push_device_token_id';
  static const String _lastFcmTokenKey = 'planora_push_last_fcm_token';

  static const String _channelId = 'planora_updates';
  static const String _channelName = 'Planora updates';
  static const String _channelDescription =
      'Project, task, team, comment, AI, and deadline updates from Planora.';

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDescription,
    importance: Importance.high,
  );

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final PushNotificationApi _api = const PushNotificationApi();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final StreamController<PushNotificationPayload> _foregroundMessageController =
      StreamController<PushNotificationPayload>.broadcast();
  final StreamController<PushNotificationPayload> _notificationTapController =
      StreamController<PushNotificationPayload>.broadcast();

  StreamSubscription<String>? _tokenRefreshSubscription;
  PushNotificationPayload? _pendingInitialTap;
  bool _initialized = false;
  bool _localNotificationsReady = false;

  Stream<PushNotificationPayload> get foregroundMessages =>
      _foregroundMessageController.stream;

  Stream<PushNotificationPayload> get notificationTaps =>
      _notificationTapController.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (!kIsWeb) {
      await _initializeLocalNotifications();
    }

    FirebaseMessaging.onMessage.listen((message) {
      unawaited(_handleForegroundMessage(message));
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteNotificationTap);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _pendingInitialTap = PushNotificationPayload.fromRemoteMessage(
        initialMessage,
      );
    }

    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) async {
      final hasSession = await TokenStorage.hasAccessToken();
      if (!hasSession) return;

      await _registerToken(token);
    });
  }

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsReady) return;

    const androidSettings = AndroidInitializationSettings('ic_stat_planora');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleLocalNotificationTap,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);

    _localNotificationsReady = true;
  }

  PushNotificationPayload? takePendingInitialNotificationTap() {
    final payload = _pendingInitialTap;
    _pendingInitialTap = null;
    return payload;
  }

  Future<void> registerCurrentDevice() async {
    if (kIsWeb) return;

    final hasSession = await TokenStorage.hasAccessToken();
    if (!hasSession) return;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Push notification permission denied.');
      return;
    }

    final token = await _messaging.getToken();

    if (token == null || token.trim().isEmpty) {
      debugPrint('FCM token is empty.');
      return;
    }

    await _registerToken(token);
  }

  Future<void> _registerToken(String token) async {
    final platform = _platform;
    if (platform == null) {
      debugPrint('Unsupported push platform.');
      return;
    }

    final deviceKey = await _getOrCreateDeviceKey();

    final response = await _api.registerDeviceToken(
      token: token,
      platform: platform,
      deviceKey: deviceKey,
    );

    final id = response['device_token_id'] ?? response['id'];
    if (id is int) {
      await _storage.write(key: _deviceTokenIdKey, value: id.toString());
    }

    await _storage.write(key: _lastFcmTokenKey, value: token);

    debugPrint('Planora push token registered for $platform.');
  }

  Future<void> heartbeatCurrentDevice() async {
    final deviceKey = await _storage.read(key: _deviceKeyKey);
    final idValue = await _storage.read(key: _deviceTokenIdKey);

    if (deviceKey == null || deviceKey.trim().isEmpty) return;

    await _api.heartbeatCurrentDeviceToken(
      deviceKey: deviceKey,
      deviceTokenId: int.tryParse(idValue ?? ''),
    );
  }

  Future<void> deactivateCurrentDevice() async {
    final deviceKey = await _storage.read(key: _deviceKeyKey);
    final token = await _storage.read(key: _lastFcmTokenKey);
    final idValue = await _storage.read(key: _deviceTokenIdKey);

    if ((deviceKey == null || deviceKey.trim().isEmpty) &&
        (token == null || token.trim().isEmpty) &&
        idValue == null) {
      return;
    }

    await _api.deactivateCurrentDeviceToken(
      deviceKey: deviceKey,
      token: token,
      deviceTokenId: int.tryParse(idValue ?? ''),
    );

    await clearLocalPushTokenState();
  }

  Future<void> clearLocalPushTokenState() async {
    await _storage.delete(key: _deviceTokenIdKey);
    await _storage.delete(key: _lastFcmTokenKey);
  }

  Future<String> _getOrCreateDeviceKey() async {
    final existing = await _storage.read(key: _deviceKeyKey);

    if (existing != null && existing.trim().length >= 8) {
      return existing;
    }

    final random = Random.secure().nextInt(1 << 32);
    final generated = 'mobile-${DateTime.now().millisecondsSinceEpoch}-$random';

    await _storage.write(key: _deviceKeyKey, value: generated);
    return generated;
  }

  String? get _platform {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return null;
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final payload = PushNotificationPayload.fromRemoteMessage(message);

    debugPrint('Foreground push received: ${message.messageId}');
    debugPrint('Title: ${payload.title}');
    debugPrint('Body: ${payload.body}');
    debugPrint('Data: ${payload.data}');

    _foregroundMessageController.add(payload);
    await _showForegroundNotification(payload);
  }

  Future<void> _showForegroundNotification(
    PushNotificationPayload payload,
  ) async {
    if (kIsWeb || !_localNotificationsReady) return;

    final title = payload.title.trim().isEmpty
        ? 'Planora update'
        : payload.title.trim();
    final body = payload.body.trim().isEmpty
        ? 'Tap to view your latest update.'
        : payload.body.trim();

    final notificationId = _notificationIdFor(payload);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_planora',
        ticker: title,
        category: AndroidNotificationCategory.status,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: 'Planora',
        ),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      notificationId,
      title,
      body,
      details,
      payload: payload.toLocalPayload(),
    );
  }

  void _handleRemoteNotificationTap(RemoteMessage message) {
    final payload = PushNotificationPayload.fromRemoteMessage(message);

    debugPrint('Push opened: ${message.messageId}');
    debugPrint('Push data: ${payload.data}');

    _notificationTapController.add(payload);
  }

  void _handleLocalNotificationTap(NotificationResponse response) {
    final payload = PushNotificationPayload.fromLocalPayload(response.payload);

    debugPrint('Local push opened: ${payload.messageId}');
    debugPrint('Local push data: ${payload.data}');

    _notificationTapController.add(payload);
  }

  int _notificationIdFor(PushNotificationPayload payload) {
    final notificationId = payload.intValue('notification_id') ??
        payload.intValue('notificationId') ??
        payload.intValue('id');

    if (notificationId != null && notificationId > 0) {
      return notificationId;
    }

    final seed = payload.messageId ??
        '${payload.title}-${payload.body}-${DateTime.now().microsecondsSinceEpoch}';
    return seed.hashCode & 0x7fffffff;
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
  }
}
