import '../../../core/network/api_client.dart';
import '../../../core/storage/local_cache_store.dart';

class NotificationsApi {
  static const String _notificationsCacheKey = 'notifications';

  const NotificationsApi();

  Future<List<NotificationModel>> getNotifications({
    bool unreadOnly = false,
  }) async {
    try {
      final response = await ApiClient.get(
        '/notifications',
        queryParameters: {'unread_only': unreadOnly},
      );

      final notifications = _parseNotificationList(response);
      await LocalCacheStore.writeJson(_notificationsCacheKey, response);
      return notifications;
    } catch (_) {
      final cached = await LocalCacheStore.readJson(_notificationsCacheKey);
      final cachedData = cached?.data;
