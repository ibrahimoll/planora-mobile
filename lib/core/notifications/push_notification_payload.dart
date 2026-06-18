import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

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
