import 'package:flutter/material.dart';

import '../../core/theme/planora_theme.dart';
import '../auth/data/project_api.dart';
import '../auth/models/project_models.dart';
import '../projects/project_detail_screen.dart';
import '../tasks/data/tasks_api.dart';
import '../tasks/models/task_models.dart';
import '../tasks/task_detail_screen.dart';
import '../teams/teams_screen.dart';
import 'data/notifications_api.dart';

class NotificationsScreen extends StatefulWidget {
  final NotificationsApi notificationsApi;
  final ProjectsApi projectsApi;
  final TasksApi tasksApi;
  final ValueChanged<NotificationNavigationTarget>? onNavigateForTest;

  const NotificationsScreen({
    super.key,
    this.notificationsApi = const NotificationsApi(),
    this.projectsApi = const ProjectsApi(),
    this.tasksApi = const TasksApi(),
    this.onNavigateForTest,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationsApi _notificationsApi;
  late final ProjectsApi _projectsApi;
  late final TasksApi _tasksApi;

  bool isLoading = true;
  bool isMarkingAllRead = false;
  String? errorMessage;
  List<NotificationModel> notifications = [];

  @override
  void initState() {
    super.initState();
    _notificationsApi = widget.notificationsApi;
    _projectsApi = widget.projectsApi;
    _tasksApi = widget.tasksApi;
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final loadedNotifications = await _notificationsApi.getNotifications();

      if (!mounted) return;

      setState(() {
        notifications = loadedNotifications;
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Notifications load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        errorMessage = 'Could not load notifications.';
        isLoading = false;
      });
    }
  }

  Future<void> markAllAsRead() async {
    if (notifications.every((notification) => notification.isRead)) {
      return;
    }

    setState(() {
      isMarkingAllRead = true;
    });

    try {
      await _notificationsApi.markAllAsRead();
      await loadNotifications();
    } catch (error, stackTrace) {
      debugPrint('Mark all notifications read failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not mark notifications as read.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isMarkingAllRead = false;
        });
      }
    }
  }

  Future<void> markNotificationAsRead(NotificationModel notification) async {
    if (notification.isRead) {
      return;
    }

    try {
      final updated = await _notificationsApi.markAsRead(
        notification.notificationId,
      );

      if (!mounted) return;

      setState(() {
        notifications = notifications
            .map(
              (item) => item.notificationId == updated.notificationId
                  ? updated
                  : item,
            )
            .toList();
      });
    } catch (error, stackTrace) {
      debugPrint('Mark notification read failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update notification.')),
      );
    }
  }

  Future<void> handleNotificationTap(NotificationModel notification) async {
    await markNotificationAsRead(notification);

    final target = notification.navigationTarget;
    widget.onNavigateForTest?.call(target);

    if (widget.onNavigateForTest != null) {
      return;
    }

    if (!mounted) {
      return;
    }

    switch (target.kind) {
      case NotificationRouteKind.task:
        await openTaskTarget(target);
        break;
      case NotificationRouteKind.project:
        await openProjectTarget(target);
        break;
      case NotificationRouteKind.team:
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const TeamsScreen()));
        break;
      case NotificationRouteKind.detail:
        showNotificationDetail(notification);
        break;
      case NotificationRouteKind.missingIds:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This notification does not include enough detail.'),
          ),
        );
        break;
    }
  }

  Future<ProjectModel?> findProjectById(int projectId) async {
    try {
      final projects = await _projectsApi.getProjects();

      for (final project in projects) {
        if (project.projectId == projectId) {
          return project;
        }
      }

      return await _projectsApi.getProjectById(projectId);
    } catch (error, stackTrace) {
      debugPrint('Notification target project load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> openProjectTarget(NotificationNavigationTarget target) async {
    final projectId = target.projectId;

    if (projectId == null) {
      return;
    }

    final project = await findProjectById(projectId);

    if (!mounted) {
      return;
    }

    if (project == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this project.')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProjectDetailScreen(project: project),
      ),
    );
  }

  Future<void> openTaskTarget(NotificationNavigationTarget target) async {
    final projectId = target.projectId;
    final taskId = target.taskId;

    if (projectId == null || taskId == null) {
      return;
    }

    final project = await findProjectById(projectId);

    if (!mounted) {
      return;
    }

    if (project == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this task.')),
      );
      return;
    }

    try {
      final task = await _tasksApi.getTask(
        project: TaskProjectSummary.fromProject(project),
        taskId: taskId,
      );

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TaskDetailScreen(
            initialTask: task,
            onTaskChanged: loadNotifications,
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Notification target task load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this task.')),
      );
    }
  }

  void showNotificationDetail(NotificationModel notification) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = PlanoraTheme.isDark(sheetContext);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            color: isDark ? PlanoraTheme.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: PlanoraTheme.floatingShadowFor(sheetContext),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.title,
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Text(
                notification.message,
                style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                  color: mutedColor(sheetContext),
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              buildMetaPill(sheetContext, notification.typeLabel),
            ],
          ),
        );
      },
    );
  }

  Color mutedColor(BuildContext context) {
    return PlanoraTheme.isDark(context)
        ? PlanoraTheme.darkTextMuted
        : PlanoraTheme.textSecondary;
  }

  BoxDecoration cardDecoration(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return BoxDecoration(
      color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
      ),
      boxShadow: PlanoraTheme.cardShadowFor(context),
    );
  }

  Widget buildHeader(BuildContext context) {
    final unreadCount = notifications.where((item) => !item.isRead).length;

    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 44,
            height: 44,
            decoration: cardDecoration(context),
            child: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notifications',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                unreadCount == 0 ? 'All caught up' : '$unreadCount unread',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: mutedColor(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: isMarkingAllRead ? null : markAllAsRead,
          child: Text(isMarkingAllRead ? 'Updating...' : 'Read All'),
        ),
      ],
    );
  }

  Widget buildContent(BuildContext context) {
    if (isLoading) {
      return buildStateCard(
        context,
        icon: Icons.sync_rounded,
        title: 'Loading notifications...',
        showSpinner: true,
      );
    }

    if (errorMessage != null) {
      return buildStateCard(
        context,
        icon: Icons.wifi_off_rounded,
        title: errorMessage!,
        buttonText: 'Try Again',
        onPressed: loadNotifications,
      );
    }

    if (notifications.isEmpty) {
      return buildStateCard(
        context,
        icon: Icons.notifications_none_rounded,
        title: 'No notifications yet',
        message:
            'Updates about tasks, comments, teams, and deadlines will appear here.',
      );
    }

    return Column(
      children: [
        for (final notification in notifications) ...[
          buildNotificationCard(context, notification),
          if (notification != notifications.last) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget buildStateCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? message,
    String? buttonText,
    VoidCallback? onPressed,
    bool showSpinner = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: cardDecoration(context),
      child: Column(
        children: [
          if (showSpinner)
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            )
          else
            Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: mutedColor(context),
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (buttonText != null && onPressed != null) ...[
            const SizedBox(height: 14),
            ElevatedButton(onPressed: onPressed, child: Text(buttonText)),
          ],
        ],
      ),
    );
  }

  Widget buildNotificationCard(
    BuildContext context,
    NotificationModel notification,
  ) {
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: () => handleNotificationTap(notification),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: primary.withValues(
                  alpha: notification.isRead ? 0.08 : 0.14,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(notificationIcon(notification.type), color: primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: mutedColor(context),
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      buildMetaPill(context, notification.typeLabel),
                      buildMetaPill(context, notification.createdLabel),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMetaPill(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  IconData notificationIcon(String type) {
    switch (type) {
      case 'task':
        return Icons.check_box_rounded;
      case 'project':
        return Icons.folder_rounded;
      case 'team':
        return Icons.groups_2_rounded;
      case 'comment':
      case 'mention':
        return Icons.chat_bubble_outline_rounded;
      case 'deadline':
        return Icons.event_rounded;
      case 'ai':
        return Icons.auto_awesome_rounded;
      case 'risk':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: PlanoraTheme.onboardingBackgroundFor(context),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: RefreshIndicator(
                onRefresh: loadNotifications,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: [
                    buildHeader(context),
                    const SizedBox(height: 20),
                    buildContent(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
