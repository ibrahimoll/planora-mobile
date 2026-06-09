import '../../../core/network/api_client.dart';
import '../../../core/storage/local_cache_store.dart';

class NotificationsApi {
  static const String _notificationsCacheKey = 'notifications';

  const NotificationsApi();

  Future<List<NotificationModel>> getNotifications({
    bool unreadOnly = false,
  }) async {
    try {
      final response = await