import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthException implements Exception {
  final String code;
  final String message;

  const GoogleAuthException(this.code, this.message);

  @override
  String toString() {
    return 'GoogleAuthException($code): $message';
  }
}

class GoogleAuthService {
  GoogleAuthService._();

  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;

    await GoogleSignIn.instance.initialize();

    _initialized = true;
  }

  static Future<String?> signInAndGetIdToken() async {
    await _ensureInitialized();

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      debugPrint('GOOGLE_AUTH_UNSUPPORTED: authenticate() is not available.');
      throw const GoogleAuthException(
        'unsupported',
        'Google sign-in is not available on this device.',
      );
    }

    GoogleSignInAccount account;

    try {
      account = await GoogleSignIn.instance.authenticate(
        scopeHint: const <String>['email', 'profile'],
      );
    } on GoogleSignInException catch (error, stackTrace) {
      debugPrint(
        'GOOGLE_AUTH_PLUGIN_ERROR: code=${error.code} '
        'description=${error.description}',
      );
      debugPrintStack(
        label: 'GOOGLE_AUTH_PLUGIN_STACK',
        stackTrace: stackTrace,
      );

      if (error.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }

      final message = switch (error.code) {
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          'Google sign-in is not configured for this app build. Please contact support.',
        GoogleSignInExceptionCode.uiUnavailable =>
          'Google sign-in could not open on this device. Please try again.',
        _ => 'Google sign-in failed. Please try again.',
      };

      throw GoogleAuthException(error.code.name, message);
    }

    final idToken = account.authentication.idToken;

    if (idToken == null || idToken.isEmpty) {
      debugPrint(
        'GOOGLE_AUTH_NO_ID_TOKEN: account_id_present=${account.id.isNotEmpty}',
      );
      throw const GoogleAuthException(
        'no_id_token',
        'Google did not return a sign-in token for this app build. Make sure this release APK is registered in Firebase with its SHA-1 and SHA-256 fingerprints.',
      );
    }

    return idToken;
  }

  static Future<void> signOut() async {
    await _ensureInitialized();
    await GoogleSignIn.instance.signOut();
  }
}
