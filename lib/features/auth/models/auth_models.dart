import '../../../core/config/app_config.dart';

class TokenResponse {
  final String accessToken;
  final String tokenType;

  const TokenResponse({required this.accessToken, required this.tokenType});

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
    );
  }
}

class UserResponse {
  final int userId;
  final String username;
  final String email;
  final String fullName;
  final String role;
  final bool isActive;
  final bool isEmailVerified;
  final String? profilePic;
  final DateTime createdAt;

  const UserResponse({
    required this.userId,
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isActive,
    required this.isEmailVerified,
    required this.profilePic,
    required this.createdAt,
  });

  factory UserResponse.fromJson(Map<String, dynamic> json) {
    return UserResponse(
      userId: json['user_id'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
      isActive: json['is_active'] as bool,
      isEmailVerified: json['is_email_verified'] as bool,
      profilePic: _normalizeProfilePic(json['profile_pic']),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static String? _normalizeProfilePic(dynamic value) {
    if (value is! String) {
      return null;
    }

    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return null;
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    if (trimmed.startsWith('/')) {
      return '${AppConfig.apiBaseUrl}$trimmed';
    }

    return '${AppConfig.apiBaseUrl}/$trimmed';
  }
}

class MessageResponse {
  final String message;

  const MessageResponse({required this.message});

  factory MessageResponse.fromJson(Map<String, dynamic> json) {
    return MessageResponse(message: json['message'] as String);
  }
}
