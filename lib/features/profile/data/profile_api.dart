import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';

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
    final fileName = _safeProfilePictureFileName(file);
    final mediaType = _profilePictureMediaType(fileName, file.mimeType);

    final response = await ApiClient.postMultipart(
      '/profile/picture',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: mediaType,
        ),
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

  String _safeProfilePictureFileName(XFile file) {
    final name = file.name.trim();
    final lowerName = name.toLowerCase();

    if (lowerName.endsWith('.png') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.webp')) {
      return name;
    }

    final mimeType = file.mimeType?.trim().toLowerCase();

    if (mimeType == 'image/png') {
      return 'profile_picture.png';
    }

    if (mimeType == 'image/webp') {
      return 'profile_picture.webp';
    }

    return 'profile_picture.jpg';
  }

  MediaType _profilePictureMediaType(String fileName, String? mimeType) {
    final normalizedMimeType = mimeType?.trim().toLowerCase();

    if (normalizedMimeType == 'image/png') {
      return MediaType('image', 'png');
    }

    if (normalizedMimeType == 'image/jpeg' || normalizedMimeType == 'image/jpg') {
      return MediaType('image', 'jpeg');
    }

    if (normalizedMimeType == 'image/webp') {
      return MediaType('image', 'webp');
    }

    final lowerName = fileName.toLowerCase();

    if (lowerName.endsWith('.png')) {
      return MediaType('image', 'png');
    }

    if (lowerName.endsWith('.webp')) {
      return MediaType('image', 'webp');
    }

    return MediaType('image', 'jpeg');
  }
}
