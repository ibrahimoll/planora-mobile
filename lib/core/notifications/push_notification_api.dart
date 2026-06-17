import '../network/api_client.dart';

class PushNotificationApi {
  const PushNotificationApi();

  Future<Map<String, dynamic>> registerDeviceToken({
    required String token,
    required String platform,
    required String deviceKey,
  }) async {
    final data = await ApiClient.postJson(
      '/push-notifications/device-tokens',
      data: {'token': token, 'platform': platform, 'device_key': deviceKey},
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> deactivateCurrentDeviceToken({
    String? token,
    String? deviceKey,
    int? deviceTokenId,
  }) async {
    final payload = <String, dynamic>{};

    if (token != null) {
      payload['token'] = token;
    }

    if (deviceKey != null) {
      payload['device_key'] = deviceKey;
    }

    if (deviceTokenId != null) {
      payload['device_token_id'] = deviceTokenId;
    }

    await ApiClient.patchJson(
      '/push-notifications/device-tokens/current/deactivate',
      data: payload,
    );
  }

  Future<void> heartbeatCurrentDeviceToken({
    required String deviceKey,
    int? deviceTokenId,
  }) async {
    final payload = <String, dynamic>{'device_key': deviceKey};

    if (deviceTokenId != null) {
      payload['device_token_id'] = deviceTokenId;
    }

    await ApiClient.patchJson(
      '/push-notifications/device-tokens/current/heartbeat',
      data: payload,
    );
  }
}
