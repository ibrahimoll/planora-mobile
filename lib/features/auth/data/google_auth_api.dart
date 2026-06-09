import '../../../core/network/api_client.dart';
import '../models/auth_models.dart';

class GoogleAuthApi {
  const GoogleAuthApi();

  Future<TokenResponse> loginWithGoogle({
    required String idToken,
    String? username,
    String? fullName,
  }) async {
    final payload = <String, dynamic>{'id_token': idToken};

    if (username != null && username.trim().isNotEmpty) {
      payload['username'] = username.trim();
    }

    if