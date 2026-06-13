import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage._();

  static const String _accessTokenKey = 'planora_access_token';
  static const String _rememberMeKey = 'planora_remember_me';
  static const String _rememberedIdentifierKey =
      'planora_remembered_identifier';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  static Future<String?> getAccessToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  static Future<void> clearAccessToken() async {
    await _storage.delete(key: _accessTokenKey);
  }

  static Future<bool> hasAccessToken() async {
    final token = await getAccessToken();
    return token != null && token.trim().isNotEmpty;
  }

  static Future<void> saveRememberedIdentifier(String identifier) async {
    await _storage.write(key: _rememberMeKey, value: 'true');
    await _storage.write(
      key: _rememberedIdentifierKey,
      value: identifier.trim(),
    );
  }

  static Future<String?> getRememberedIdentifier() async {
    final rememberMe = await getRememberMe();

    if (!rememberMe) {
      return null;
    }

    return _storage.read(key: _rememberedIdentifierKey);
  }

  static Future<bool> getRememberMe() async {
    final value = await _storage.read(key: _rememberMeKey);
    return value == 'true';
  }

  static Future<void> clearRememberedIdentifier() async {
    await _storage.delete(key: _rememberMeKey);
    await _storage.delete(key: _rememberedIdentifierKey);
  }
}
