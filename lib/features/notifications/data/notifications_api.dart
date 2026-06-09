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

      if (response is! List) {
        return [];
      }

      if (!unreadOnly) {
        await LocalCacheStore.writeJson(_notificationsCacheKey, response);
      }

      return response
          .map(
            (item) => NotificationModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      if (!unreadOnly) {
        final cached = await getCachedNotifications();

        if (cached.isNotEmpty) {
          return cached;
        }
      }

      rethrow;
    }
  }

  Future<List<NotificationModel>> getCachedNotifications() async {
    final cached = await LocalCacheStore.readJson(_notificationsCacheKey);

    if (cached?.data is! List) {
      return [];
    }

    return (cached!.data as List)
        .whereType<Map<String, dynamic>>()
        .map(NotificationModel.fromJson)
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
  final int? projectId;
  final int? taskId;
  final int? teamId;

  const NotificationModel({
    required this.notificationId,
    required this.userId,
    required this.title,
    required this.message,
    required this.isRead,
    required this.type,
    required this.createdAt,
    this.projectId,
    this.taskId,
    this.teamId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final Map<String, dynamic> dataMap = data is Map<String, dynamic>
        ? data
        : const <String, dynamic>{};

    return NotificationModel(
      notificationId: _parseInt(json['notification_id']),
      userId: _parseInt(json['user_id']),
      title: json['title'] as String? ?? 'Notification',
      message: json['message'] as String? ?? '',
      isRead: json['is_read'] == true,
      type: json['type'] as String? ?? 'system',
      createdAt: _parseDateTime(json['created_at']),
      projectId: _parseOptionalInt(json['project_id'] ?? dataMap['project_id']),
      taskId: _parseOptionalInt(json['task_id'] ?? dataMap['task_id']),
      teamId: _parseOptionalInt(json['team_id'] ?? dataMap['team_id']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notification_id': notificationId,
      'user_id': userId,
      'title': title,
      'message': message,
      'is_read': isRead,
      'type': type,
      'created_at': createdAt.toIso8601String(),
      'project_id': projectId,
      'task_id': taskId,
      'team_id': teamId,
    };
  }

  NotificationNavigationTarget get navigationTarget {
    switch (type) {
      case 'task':
      case 'deadline':
        if (taskId != null && projectId != null) {
          return NotificationNavigationTarget.task(
            projectId: projectId!,
            taskId: taskId!,
          );
        }

        if (projectId != null) {
          return NotificationNavigationTarget.project(projectId!);
        }

        return const NotificationNavigationTarget.missingIds();
      case 'project':
      case 'risk':
      case 'ai':
        if (projectId != null) {
          return NotificationNavigationTarget.project(projectId!);
        }

        return const NotificationNavigationTarget.missingIds();
      case 'team':
      case 'invite':
        return NotificationNavigationTarget.team(teamId: teamId);
      case 'comment':
      case 'mention':
        if (taskId != null && projectId != null) {
          return NotificationNavigationTarget.task(
            projectId: projectId!,
            taskId: taskId!,
          );
        }

        if (projectId != null) {
          return NotificationNavigationTarget.project(projectId!);
        }

        return const NotificationNavigationTarget.missingIds();
      default:
        return const NotificationNavigationTarget.detail();
    }
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

enum NotificationRouteKind { task, project, team, detail, missingIds }

class NotificationNavigationTarget {
  final NotificationRouteKind kind;
  final int? projectId;
  final int? taskId;
  final int? teamId;

  const NotificationNavigationTarget._({
    required this.kind,
    this.projectId,
    this.taskId,
    this.teamId,
  });

  const NotificationNavigationTarget.task({
    required int projectId,
    required int taskId,
  }) : this._(
         kind: NotificationRouteKind.task,
         projectId: projectId,
         taskId: taskId,
       );

  const NotificationNavigationTarget.project(int projectId)
    : this._(kind: NotificationRouteKind.project, projectId: projectId);

  const NotificationNavigationTarget.team({int? teamId})
    : this._(kind: NotificationRouteKind.team, teamId: teamId);

  const NotificationNavigationTarget.detail()
    : this._(kind: NotificationRouteKind.detail);

  const NotificationNavigationTarget.missingIds()
    : this._(kind: NotificationRouteKind.missingIds);
}

int _parseInt(dynamic value) {
  if (value is int) {
    return value;
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _parseOptionalInt(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  return int.tryParse(value.toString());
}

DateTime _parseDateTime(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
  }

  return DateTime.now();
}
