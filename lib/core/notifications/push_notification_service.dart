import 'package:flutter/foundation.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  Future<void> initialize() async {
    // Add Firebase Core and Messaging after Android/iOS app config exists.
    debugPrint('Push notifications are not initialized yet.');
  }
}
