import 'package:flutter/material.dart';

import '../../core/theme/planora_theme.dart';
import '../auth/data/project_api.dart';
import '../auth/models/project_models.dart';
import '../deadline_reminders/deadline_reminders_screen.dart';
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
  final int? currentUserId;
  final NotificationModel? initialNotification;
  final ValueChanged<NotificationNavigationTarget>? onNavigateForTest;

  const NotificationsScreen({
    super.key,
    this.notificationsApi = const NotificationsApi(),
    this.projectsApi = const ProjectsApi(),
    this.tasksApi = const TasksApi(),
    this.currentUserId,
    this.initialNotification,
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
  bool _handledInitialNotification = false;
  int? deletingNotificationId;
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

      await openInitialNotificationIfNeeded(loadedNotifications);
    } catch (error, stackTrace) {
      debugPrint('Notifications load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        errorMessage = 'Could not load notifications.';
        isLoading = false;
      });

      await openInitialNotificationIfNeeded(const []);
    }
  }

  Future<void> openInitialNotificationIfNeeded(
    List<NotificationModel> loadedNotifications,
  ) async {
    final initialNotification = widget.initialNotification;
    if (_handledInitialNotification || initialNotification == null) {
      return;
    }

    _handledInitialNotification = true;
    final targetNotification = resolveInitialNotification(
      initialNotification,
      loadedNotifications,
    );

    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;

    await handleNotificationTap(targetNotification);
  }

  NotificationModel resolveInitialNotification(
    NotificationModel initialNotification,
    List<NotificationModel> loadedNotifications,
  ) {
    if (initialNotification.notificationId > 0) {
      for (final notification in loadedNotifications) {
        if (notification.notificationId == initialNotification.notificationId) {
          return notification;
        }
      }
    }

    for (final notification in loadedNotifications) {
      final sameTask =
          initialNotification.taskId != null &&
          notification.taskId == initialNotification.taskId;
      final sameProject =
          initialNotification.projectId != null &&
          notification.projectId == initialNotification.projectId;
      final sameTeam =
          initialNotification.teamId != null &&
          notification.teamId == initialNotification.teamId;
      final sameType = notification.type == initialNotification.type;

      if (sameType && (sameTask || sameProject || sameTeam)) {
        return notification;
      }
    }

    return initialNotification;
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
    if (notification.isRead || notification.notificationId <= 0) {
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

  Future<bool> deleteNotification(NotificationModel notification) async {
    if (notification.notificationId <= 0) {
      return false;
    }

    setState(() {
      deletingNotificationId = notification.notificationId;
    });

    try {
      await _notificationsApi.deleteNotification(notification.notificationId);

      if (!mounted) return false;

      setState(() {
        deletingNotificationId = null;
      });

      return true;
    } catch (error, stackTrace) {
      debugPrint('Notification delete failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return false;

      setState(() {
        deletingNotificationId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete notification.')),
      );

      return false;
    }
  }

  Future<void> openDeadlineRemindersScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DeadlineRemindersScreen()),
    );
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
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TeamsScreen(
              showBackButton: true,
              openInvitations:
                  notification.type == 'invite' ||
                  notification.type == 'invitation',
              currentUserId: widget.currentUserId ?? notification.userId,
            ),
          ),
        );
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
        final accent = notificationAccentColor(sheetContext, notification.type);

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: isDark ? PlanoraTheme.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
              bottom: Radius.circular(28),
            ),
            border: Border.all(
              color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
            ),
            boxShadow: PlanoraTheme.floatingShadowFor(sheetContext),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: mutedColor(sheetContext).withValues(alpha: 0.26),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      notificationIcon(notification.type),
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: Theme.of(sheetContext).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 5),
                        buildMetaPill(sheetContext, notification.typeLabel),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                notification.message,
                style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                  color: mutedColor(sheetContext),
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
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

  Color notificationAccentColor(BuildContext context, String type) {
    switch (type) {
      case 'deadline':
        return PlanoraTheme.warning;
      case 'risk':
        return PlanoraTheme.error;
      case 'comment':
      case 'mention':
        return PlanoraTheme.info;
      case 'team':
      case 'invite':
      case 'invitation':
        return PlanoraTheme.success;
      case 'ai':
        return PlanoraTheme.secondaryPurple;
      default:
        return Theme.of(context).colorScheme.primary;
    }
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
    final canMarkRead = unreadCount > 0 && !isMarkingAllRead;

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
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  unreadCount == 0 ? 'All caught up' : '$unreadCount unread',
                  key: ValueKey<int>(unreadCount),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mutedColor(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: canMarkRead ? markAllAsRead : null,
          icon: isMarkingAllRead
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.done_all_rounded, size: 18),
          label: Text(isMarkingAllRead ? 'Updating' : 'Read All'),
        ),
      ],
    );
  }

  Widget buildDeadlineRemindersEntry(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: openDeadlineRemindersScreen,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: PlanoraTheme.softPurpleGradientFor(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: isDark ? 0.32 : 0.22),
            ),
            boxShadow: PlanoraTheme.floatingShadowFor(context),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: PlanoraTheme.warning.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.event_rounded,
                  color: PlanoraTheme.warning,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deadline Reminders',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? PlanoraTheme.darkTextPrimary
                            : PlanoraTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Review overdue and upcoming task reminders.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: mutedColor(context),
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: mutedColor(context).withValues(alpha: 0.72),
              ),
            ],
          ),
        ),
      ),
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
        for (var index = 0; index < notifications.length; index++) ...[
          buildAnimatedNotificationCard(context, notifications[index], index),
          if (index != notifications.length - 1) const SizedBox(height: 12),
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

  Widget buildAnimatedNotificationCard(
    BuildContext context,
    NotificationModel notification,
    int index,
  ) {
    final delay = (index * 45).clamp(0, 240).toInt();

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 16),
            child: Transform.scale(scale: 0.98 + (value * 0.02), child: child),
          ),
        );
      },
      child: buildDismissibleNotificationCard(context, notification),
    );
  }

  Widget buildDismissibleNotificationCard(
    BuildContext context,
    NotificationModel notification,
  ) {
    final notificationId = notification.notificationId;
    final isDeleting = deletingNotificationId == notificationId;

    return Dismissible(
      key: ValueKey<String>(
        notificationId > 0
            ? 'notification-$notificationId'
            : 'notification-${notification.title}-${notification.createdAt?.toIso8601String()}',
      ),
      direction: isDeleting
          ? DismissDirection.none
          : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: PlanoraTheme.error.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
      confirmDismiss: (_) => deleteNotification(notification),
      onDismissed: (_) {
        setState(() {
          notifications = notifications
              .where((item) => item.notificationId != notificationId)
              .toList();
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Notification deleted.')));
      },
      child: buildNotificationCard(context, notification),
    );
  }

  Widget buildNotificationCard(
    BuildContext context,
    NotificationModel notification,
  ) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = PlanoraTheme.isDark(context);
    final isUnread = !notification.isRead;
    final accent = notificationAccentColor(context, notification.type);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => handleNotificationTap(notification),
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isUnread
                ? null
                : (isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface),
            gradient: isUnread
                ? PlanoraTheme.softPurpleGradientFor(context)
                : null,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isUnread
                  ? primary.withValues(alpha: isDark ? 0.32 : 0.22)
                  : (isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border),
            ),
            boxShadow: isUnread
                ? PlanoraTheme.floatingShadowFor(context)
                : PlanoraTheme.cardShadowFor(context),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 4,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [accent, accent.withValues(alpha: 0.45)],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isUnread ? 0.16 : 0.09),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: accent.withValues(alpha: isUnread ? 0.18 : 0.08),
                  ),
                ),
                child: Icon(notificationIcon(notification.type), color: accent),
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
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? PlanoraTheme.darkTextPrimary
                                      : PlanoraTheme.textPrimary,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isUnread)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'New',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: primary,
                                    fontWeight: FontWeight.w900,
                                  ),
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
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        Flexible(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              buildMetaPill(context, notification.typeLabel),
                              buildMetaPill(context, notification.createdLabel),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: mutedColor(context).withValues(alpha: 0.72),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
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
      case 'invite':
      case 'invitation':
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
                    buildDeadlineRemindersEntry(context),
                    const SizedBox(height: 14),
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
