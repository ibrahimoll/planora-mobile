import '../../../core/network/api_client.dart';

class NotificationsApi {
  const NotificationsApi();

  Future<List<NotificationModel>> getNotifications({
    bool unreadOnly = false,
  }) async {
    final response = await ApiClient.get(
      '/notifications',
      queryParameters: {'unread_only': unreadOnly},
    );

    if (response is! List) {
      return [];
    }

    return response
        .map((item) => NotificationModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<int> getUnreadCount() async {
    final response = await ApiClient.get('/notifications/unread-count');

    if (response is Map<String, dynamic>) {
      return response['unread_count'] as int? ?? 0;
    }

    return 0;
  }

  Future<NotificationModel> markAsRead(int notificationId) async {
    final response = await ApiClient.patchJson(
      '/notifications/$notificationId/read',
    );

    return NotificationModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> markAllAsRead() async {
    await ApiClient.patchJson('/notifications/read-all');
  }

  Future<void> deleteNotification(int notificationId) async {
    await ApiClient.delete('/notifications/$notificationId');
  }
}

class NotificationModel {
  final int notificationId;
  final int userId;
  final String title;
  final String message;
  final bool isRead;
  final String type;
  final DateTime createdAt;

  const NotificationModel({
    required this.notificationId,
    required this.userId,
    required this.title,
    required this.message,
    required this.isRead,
    required this.type,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      notificationId: json['notification_id'] as int,
      userId: json['user_id'] as int,
      title: json['title'] as String,
      message: json['message'] as String,
      isRead: json['is_read'] as bool,
      type: json['type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  String get typeLabel {
    switch (type) {
      case 'task':
        return 'Task';
      case 'project':
        return 'Project';
      case 'team':
        return 'Team';
      case 'comment':
        return 'Comment';
      case 'mention':
        return 'Mention';
      case 'invite':
        return 'Invite';
      case 'deadline':
        return 'Deadline';
      case 'ai':
        return 'AI';
      case 'risk':
        return 'Risk';
      case 'system':
        return 'System';
      default:
        return type;
    }
  }

  String get createdLabel {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays == 1) return 'Yesterday';

    return '${createdAt.month}/${createdAt.day}/${createdAt.year}';
  }
}
