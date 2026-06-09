import 'package:flutter/foundation.dart';

import '../network/api_client.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  Future<void> initialize() async {
    // Firebase Core and Messaging should be added only after Android/iOS
    // app configuration files are available in the repo or build environment.
    // Then request permission, read the FCM token, listen for token refreshes,
    // and route opened messages through notification deep links.
   