import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../auth/models/auth_models.dart';

class ProfileApi {
  const ProfileApi();

  Future<UserResponse> getProfile() async {
    final response = await ApiClient.get('/profile');

    return UserResponse.fromJson(response as Map<String, dynamic>);
  }

  Future<UserResponse> updateProfile({
    required String username,
    required String fullName,
  }) async {
    final response = await ApiClient.patchJson(
      '/profile',
      data: {'username': username, 'full_name': fullName},
    );

    final data = response as Map<String, dynamic>;

    return UserResponse.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<UserResponse> uploadProfilePicture({required XFile file}) async {
    final bytes = await file.readAsBytes();
    final response = await ApiClient.postMultipart(
      '/profile/picture',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: file.name),
      }),
    );

    final data = response as Map<String, dynamic>;

    return UserResponse.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await ApiClient.patchJson(
      '/profile/password',
      data: {'old_password': oldPassword, 'new_password': newPassword},
    );
  }
}
