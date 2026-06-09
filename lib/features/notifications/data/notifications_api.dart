import '../../../core/network/api_client.dart';

enum NotificationRouteKind { project, task, team, ai, risk, none }

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

  factory NotificationNavigationTarget.none() {
    return const NotificationNavigationTarget(kind: NotificationRouteKind.none);
  }
}

class NotificationModel {
  final int notificationId;
  final String title;
  final String message;
  final bool isRead;
  final String type;
  final DateTime? createdAt;
  final NotificationNavigationTarget navigationTarget;

  const NotificationModel({
    required this.notificationId,
    required this.title,
    required this.message,
    required this.isRead,
    required this.type,
    required this.createdAt,
    required this.navigationTarget,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? 'system').toString();

    return NotificationModel(
      notificationId: _asInt(
        json['notification_id'] ?? json['id'] ?? json['notificationId'] ?? 0,
      ),
      title: (json['title'] ?? 'Notification').toString(),
      message: (json['message'] ?? '').toString(),
      isRead: _asBool(json['is_read'] ?? json['isRead'] ?? false),
      type: type,
      createdAt: _asDateTime(json['created_at'] ?? json['createdAt']),
      navigationTarget: _navigationTargetFromJson(json, type),
    );
  }

  NotificationModel copyWith({
    int? notificationId,
    String? title,
    String? message,
    bool? isRead,
    String? type,
    DateTime? createdAt,
    NotificationNavigationTarget? navigationTarget,
  }) {
    return NotificationModel(
      notificationId: notificationId ?? this.notificationId,
      title: title ?? this.title,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      navigationTarget: navigationTarget ?? this.navigationTarget,
    );
  }

  static NotificationNavigationTarget _navigationTargetFromJson(
    Map<String, dynamic> json,
    String type,
  ) {
    final projectId = _nullableInt(json['project_id'] ?? json['projectId']);
    final taskId = _nullableInt(json['task_id'] ?? json['taskId']);
    final teamId = _nullableInt(json['team_id'] ?? json['teamId']);

    switch (type) {
      case 'project':
        return NotificationNavigationTarget(
          kind: NotificationRouteKind.project,
          projectId: projectId,
        );
      case 'task':
        return NotificationNavigationTarget(
          kind: NotificationRouteKind.task,
          projectId: projectId,
          taskId: taskId,
        );
      case 'team':
        return NotificationNavigationTarget(
          kind: NotificationRouteKind.team,
          teamId: teamId,
        );
      case 'ai':
        return NotificationNavigationTarget(
          kind: NotificationRouteKind.ai,
          projectId: projectId,
        );
      case 'risk':
        return NotificationNavigationTarget(
          kind: NotificationRouteKind.risk,
          projectId: projectId,
        );
      default:
        return NotificationNavigationTarget.none();
    }
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
    final text = value?.toString().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
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

  Future<void> markAsRead(int notificationId) async {
    await ApiClient.patch('/notifications/$notificationId/read');
  }

  Future<void> markAllAsRead() async {
    await ApiClient.patch('/notifications/read-all');
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
    if (response is List) return response;

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
