import 'package:flutter/foundation.dart';

import '../network/api_client.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  Future<void> initialize() async {
    // TODO: Add firebase_core and firebase_messaging only after Android/iOS
    // Firebase app config files are intentionally added to the repo or build
    // environment. Then request permission, read the FCM token, listen for token
    // refreshes, and route opened messages through notification deep links.
    debugPrint(
      'Push notifications are not initialized because Firebase Messaging is not configured in this mobile repo.',
    );
  }

  Future<void> registerDeviceToken({
    required String token,
    required String platform,
    String? deviceKey,
  }) async {
    if (token.trim().isEmpty) {
      return;
    }

    await ApiClient.postJson(
      '/push-notifications/device-tokens',
      data: {
        'token': token,
        'platform': platform,
        if (deviceKey != null && deviceKey.trim().isNotEmpty)
          'device_key': deviceKey.trim(),
      },
    );
  }
}
