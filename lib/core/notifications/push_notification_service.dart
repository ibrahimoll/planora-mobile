import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../storage/token_storage.dart';
import 'push_notification_api.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final PushNotificationApi _api = const PushNotificationApi();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _deviceKeyKey = 'planora_push_device_key';
  static const String _deviceTokenIdKey = 'planora_push_device_token_id';
  static const String _lastFcmTokenKey = 'planora_push_last_fcm_token';

  StreamSubscription<String>? _tokenRefreshSubscription;

  Future<void> initialize() async {
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) async {
      final hasSession = await TokenStorage.hasAccessToken();
      if (!hasSession) return;

      await _registerToken(token);
    });
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

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground push received: ${message.messageId}');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
    debugPrint('Data: ${message.data}');
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Push opened: ${message.messageId}');
    debugPrint('Push data: ${message.data}');

    // Later we can route based on message.data:
    // project_id -> Project Details
    // task_id -> Task Details
    // type=invitation -> Invitations
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
  }
}
