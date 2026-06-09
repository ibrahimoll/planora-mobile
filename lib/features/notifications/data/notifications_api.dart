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

  factory