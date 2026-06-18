import '../../../core/network/api_client.dart';
import '../../../core/notifications/push_notification_payload.dart';

enum NotificationRouteKind { task, project, team, detail, missingIds }

class NotificationNavigationTarget {
  final NotificationRouteKind kind;
  final int? projectId;
  final int? taskId;
  final int? teamId;

  const NotificationNavigationTarget({
    required this.kind,
    this.projectId,
    this.taskId,
    this.teamId,
  });
}

class NotificationModel {
  final int notificationId;
  final int? userId;
  final String title;
  final String message;
  final bool isRead;
  final String type;
  final DateTime? createdAt;
  final int? projectId;
  final int? taskId;
  final int? teamId;

  const NotificationModel({
    required this.notificationId,
    this.userId,
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
    return NotificationModel(
      notificationId: _asInt(
        json['notification_id'] ?? json['notificationId'] ?? json['id'] ?? 0,
      ),
      userId: _nullableInt(json['user_id'] ?? json['userId']),
      title: (json['title'] ?? 'Notification').toString(),
      message: (json['message'] ?? '').toString(),
      isRead: _asBool(json['is_read'] ?? json['isRead'] ?? false),
      type: (json['type'] ?? 'system').toString(),
      createdAt: _asDateTime(json['created_at'] ?? json['createdAt']),
      projectId: _nullableInt(json['project_id'] ?? json['projectId']),
      taskId: _nullableInt(json['task_id'] ?? json['taskId']),
      teamId: _nullableInt(json['team_id'] ?? json['teamId']),
    );
  }

  factory NotificationModel.fromPushPayload(PushNotificationPayload payload) {
    final data = payload.data;
    final title = _firstNonEmpty([
      payload.title,
      data['title'],
      data['notification_title'],
    ]);
    final message = _firstNonEmpty([
      payload.body,
      data['message'],
      data['body'],
      data['notification_body'],
    ]);
    final type = _firstNonEmpty([
      data['type'],
      data['notification_type'],
      data['event_type'],
      data['category'],
    ]);

    return NotificationModel(
      notificationId: _asInt(
        data['notification_id'] ?? data['notificationId'] ?? data['id'] ?? 0,
      ),
      userId: _nullableInt(data['user_id'] ?? data['userId']),
      title: title ?? 'Planora update',
      message: message ?? 'Tap to view your latest update.',
      isRead: false,
      type: type ?? 'system',
      createdAt: DateTime.now(),
      projectId: _nullableInt(data['project_id'] ?? data['projectId']),
      taskId: _nullableInt(data['task_id'] ?? data['taskId']),
      teamId: _nullableInt(data['team_id'] ?? data['teamId']),
    );
  }

  NotificationNavigationTarget get navigationTarget {
    switch (type) {
      case 'task':
        if (projectId == null || taskId == null) {
          return const NotificationNavigationTarget(
            kind: NotificationRouteKind.missingIds,
          );
        }

        return NotificationNavigationTarget(
          kind: NotificationRouteKind.task,
          projectId: projectId,
          taskId: taskId,
        );

      case 'comment':
      case 'mention':
      case 'deadline':
        if (projectId != null && taskId != null) {
          return NotificationNavigationTarget(
            kind: NotificationRouteKind.task,
            projectId: projectId,
            taskId: taskId,
          );
        }

        if (projectId != null) {
          return NotificationNavigationTarget(
            kind: NotificationRouteKind.project,
            projectId: projectId,
          );
        }

        return const NotificationNavigationTarget(
          kind: NotificationRouteKind.detail,
        );

      case 'project':
      case 'ai':
      case 'risk':
        if (projectId == null) {
          return const NotificationNavigationTarget(
            kind: NotificationRouteKind.missingIds,
          );
        }

        return NotificationNavigationTarget(
          kind: NotificationRouteKind.project,
          projectId: projectId,
        );

      case 'team':
      case 'invite':
      case 'invitation':
        return NotificationNavigationTarget(
          kind: NotificationRouteKind.team,
          teamId: teamId,
        );

      default:
        return const NotificationNavigationTarget(
          kind: NotificationRouteKind.detail,
        );
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
      case 'invite':
      case 'invitation':
        return 'Invite';
      case 'comment':
        return 'Comment';
      case 'mention':
        return 'Mention';
      case 'deadline':
        return 'Deadline';
      case 'ai':
        return 'AI';
      case 'risk':
        return 'Risk';
      case 'system':
        return 'System';
      default:
        if (type.trim().isEmpty) {
          return 'Notification';
        }

        final normalized = type.replaceAll('_', ' ');
        return normalized
            .split(' ')
            .where((part) => part.isNotEmpty)
            .map((part) {
              final lower = part.toLowerCase();
              return '${lower[0].toUpperCase()}${lower.substring(1)}';
            })
            .join(' ');
    }
  }

  String get createdLabel {
    final value = createdAt;

    if (value == null) {
      return 'Just now';
    }

    final now = DateTime.now();
    final difference = now.difference(value);

    if (difference.inMinutes < 1) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();

    return '$day/$month/$year';
  }

  NotificationModel copyWith({
    int? notificationId,
    int? userId,
    String? title,
    String? message,
    bool? isRead,
    String? type,
    DateTime? createdAt,
    int? projectId,
    int? taskId,
    int? teamId,
  }) {
    return NotificationModel(
      notificationId: notificationId ?? this.notificationId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      projectId: projectId ?? this.projectId,
      taskId: taskId ?? this.taskId,
      teamId: teamId ?? this.teamId,
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value?.toString().toLowerCase().trim();
    return text == 'true' || text == '1' || text == 'yes';
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static String? _firstNonEmpty(Iterable<dynamic> values) {
    for (final value in values) {
      final cleaned = value?.toString().trim();
      if (cleaned != null && cleaned.isNotEmpty) {
        return cleaned;
      }
    }

    return null;
  }
}

class NotificationsApi {
  const NotificationsApi();

  Future<List<NotificationModel>> getNotifications({
    bool unreadOnly = false,
  }) async {
    final response = await ApiClient.get(
      '/notifications',
      queryParameters: {'unread_only': unreadOnly},
    );

    return _parseNotificationList(response);
  }

  Future<int> getUnreadCount() async {
    final notifications = await getNotifications(unreadOnly: true);
    return notifications.where((notification) => !notification.isRead).length;
  }

  Future<NotificationModel> markAsRead(int notificationId) async {
    final response = await ApiClient.patchJson(
      '/notifications/$notificationId/read',
    );

    if (response is Map) {
      final map = Map<String, dynamic>.from(response);

      final notificationData = map['notification'];
      if (notificationData is Map) {
        return NotificationModel.fromJson(
          Map<String, dynamic>.from(notificationData),
        );
      }

      final data = map['data'];
      if (data is Map) {
        return NotificationModel.fromJson(Map<String, dynamic>.from(data));
      }

      return NotificationModel.fromJson(map);
    }

    return NotificationModel(
      notificationId: notificationId,
      title: 'Notification',
      message: '',
      isRead: true,
      type: 'system',
      createdAt: null,
    );
  }

  Future<void> markAllAsRead() async {
    await ApiClient.patchJson('/notifications/read-all');
  }

  List<NotificationModel> _parseNotificationList(dynamic response) {
    final rawList = _extractList(response);

    return rawList
        .whereType<Map>()
        .map(
          (item) => NotificationModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  List<dynamic> _extractList(dynamic response) {
    if (response is List) {
      return response;
    }

    if (response is Map) {
      final data = response['data'];
      if (data is List) return data;

      final notifications = response['notifications'];
      if (notifications is List) return notifications;

      final results = response['results'];
      if (results is List) return results;

      final items = response['items'];
      if (items is List) return items;
    }

    return const [];
  }
}
