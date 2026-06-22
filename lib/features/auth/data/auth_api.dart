import '../../../core/network/api_client.dart';
import '../models/auth_models.dart';

class AuthApi {
  AuthApi._();

  static Future<TokenResponse> login({
    required String identifier,
    required String password,
  }) async {
    final data = await ApiClient.postForm(
      '/auth/login',
      data: {'username': identifier, 'password': password},
      requiresAuth: false,
    );
    return TokenResponse.fromJson(data as Map<String, dynamic>);
  }

  static Future<MessageResponse> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
  }) async {
    final data = await ApiClient.postJson(
      '/auth/register',
      data: {
        'username': username,
        'email': email,
        'password': password,
        'full_name': fullName,
      },
      requiresAuth: false,
    );

    return MessageResponse.fromJson(data as Map<String, dynamic>);
  }

  static Future<MessageResponse> verifyEmail({
    required String email,
    required String code,
  }) async {
    final data = await ApiClient.postJson(
      '/auth/verify-email',
      data: {'email': email, 'code': code},
      requiresAuth: false,
    );

    return MessageResponse.fromJson(data as Map<String, dynamic>);
  }

  static Future<MessageResponse> resendVerificationCode({
    required String email,
  }) async {
    final data = await ApiClient.postJson(
      '/auth/resend-verification-code',
      data: {'email': email},
      requiresAuth: false,
    );

    return MessageResponse.fromJson(data as Map<String, dynamic>);
  }

  static Future<MessageResponse> forgotPassword({required String email}) async {
    final data = await ApiClient.postJson(
      '/auth/forgot-password',
      data: {'email': email},
      requiresAuth: false,
    );

    return MessageResponse.fromJson(data as Map<String, dynamic>);
  }

  static Future<MessageResponse> resetPassword({
    required String email,
    required String resetCode,
    required String newPassword,
  }) async {
    final data = await ApiClient.postJson(
      '/auth/reset-password',
      data: {'email': email, 'code': resetCode, 'new_password': newPassword},
      requiresAuth: false,
    );

    return MessageResponse.fromJson(data as Map<String, dynamic>);
  }

  static Future<UserResponse> getCurrentUser() async {
    final data = await ApiClient.get('/auth/me');

    return UserResponse.fromJson(data as Map<String, dynamic>);
  }

  static Future<TokenResponse> loginWithGoogle({
    required String idToken,
    String? username,
    String? fullName,
  }) async {
    final payload = <String, dynamic>{'id_token': idToken};

    if (username != null) {
      payload['username'] = username;
    }

    if (fullName != null) {
      payload['full_name'] = fullName;
    }

    final data = await ApiClient.postJson(
      '/auth/google',
      data: payload,
      requiresAuth: false,
    );

    return TokenResponse.fromJson(data as Map<String, dynamic>);
  }
}
