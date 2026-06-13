import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/app_config.dart';

class GoogleAuthService {
  GoogleAuthService._();

  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;

    await GoogleSignIn.instance.initialize(
      serverClientId: AppConfig.googleWebClientId,
    );

    _initialized = true;
  }

  static Future<String?> signInAndGetIdToken() async {
    await _ensureInitialized();

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      debugPrint('Google sign-in authenticate() is not supported here.');
      return null;
    }

    final account = await GoogleSignIn.instance.authenticate(
      scopeHint: const <String>['email', 'profile'],
    );

    final idToken = account.authentication.idToken;

    if (idToken == null || idToken.isEmpty) {
      debugPrint('Google sign-in returned no ID token.');
      return null;
    }

    return idToken;
  }

  static Future<void> signOut() async {
    await _ensureInitialized();
    await GoogleSignIn.instance.signOut();
  }
}
