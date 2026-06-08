import 'package:flutter/material.dart';
import 'package:mobile/features/ai/ai_chat_screen.dart';
import 'package:mobile/features/notifications/data/notifications_api.dart';
import 'package:mobile/features/notifications/notifications_screen.dart';
import 'package:mobile/features/profile/profile_screen.dart';
import 'package:mobile/features/projects/project_detail_screen.dart';
import 'package:mobile/features/projects/projects_screen.dart';
import 'package:mobile/features/tasks/data/tasks_api.dart';
import 'package:mobile/features/tasks/models/task_models.dart';
import 'package:mobile/features/tasks/task_detail_screen.dart';
import 'package:mobile/features/tasks/tasks_screen.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/planora_theme.dart';
import '../auth/data/project_api.dart';
import '../auth/models/auth_models.dart';
import '../auth/models/project_models.dart';
import 'widgets/home_bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  final UserResponse user;
  final VoidCallback onThemeToggle;
  final VoidCallback? onLoggedOut;
  final ValueChanged<UserResponse>? onUserUpdated;

  const HomeScreen({
    super.key,
    required this.user,
    required this.onThemeToggle,
    this.onLoggedOut,
    this.onUserUpdated,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ProjectsApi _projectsApi = const ProjectsApi();
  final TasksApi _tasksApi = const TasksApi();
  final NotificationsApi _notificationsApi = const NotificationsApi();

  int selectedIndex = 0;
  int taskCreateRequestId = 0;

  bool hasUnreadNotifications = false;
  bool isLoadingDashboard = true;
  bool shouldOpenTaskCreateOnStart = false;

  String? dashboardError;

  List<ProjectModel> dashboardProjects = [];
  List<TaskListItem> dashboardTasks = [];
  List<TaskListItem> upcomingTasks = [];

  @override
  void initState() {
    super.initState();
    loadDashboardData();
    loadUnreadNotificationCount();
  }

  String get displayName {
    final fullName = widget.user.fullName.trim();
    return fullName.isNotEmpty ? fullName : widget.user.username;
  }

  String get firstName {
    final parts = displayName.split(RegExp(r'\s+'));
    return parts.isEmpty ? widget.user.username : parts.first;
  }

  String get greeting {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 21) return 'Good evening';

    return 'Good night';
  }

  String get initials {
    final source = displayName.trim();
    if (source.isEmpty) return 'P';

    final parts = source.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }

    return source[0].toUpperCase();
  }

  Future<void> loadDashboardData() async {
    setState(() {
      isLoadingDashboard = true;
      dashboardError = null;
    });

    try {
      final loadedProjects = await _projectsApi.getProjects();
      final projectSummaries = loadedProjects
          .map(TaskProjectSummary.fromProject)
          .toList();
      final taskGroups = await Future.wait(
        projectSummaries.map((project) async {
          try {
            return await _tasksApi.getProjectTasks(project: project);
          } catch (error, stackTrace) {
            debugPrint(
              'Dashboard task load failed for project ${project.projectId}: $error',
            );
            debugPrintStack(stackTrace: stackTrace);
            return <TaskListItem>[];
          }
        }),
      );
      final loadedTasks = taskGroups.expand((group) => group).toList()
        ..sort(compareTaskItemsByDueDate);
      final nextTasks =
          loadedTasks.where((item) => !item.task.isCompleted).toList()
            ..sort(compareUpcomingTaskItems);

      if (!mounted) {
        return;
      }

      setState(() {
        dashboardProjects = loadedProjects;
        dashboardTasks = loadedTasks;
        upcomingTasks = nextTasks.take(3).toList();
        isLoadingDashboard = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Dashboard load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      final message = error is ApiException
          ? 'Could not load dashboard: ${error.message}'
          : 'Could not load dashboard data. Please try again.';

      setState(() {
        dashboardError = message;
        isLoadingDashboard = false;
      });
    }
  }

  Future<void> loadUnreadNotificationCount() async {
    try {
      final unreadCount = await _notificationsApi.getUnreadCount();

      if (!mounted) {
        return;
      }

      setState(() {
        hasUnreadNotifications = unreadCount > 0;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        hasUnreadNotifications = false;
      });
    }
  }

  void openNewTaskFlow() {
    setState(() {
      selectedIndex = 3;
      taskCreateRequestId += 1;
      shouldOpenTaskCreateOnStart = true;
    });
  }

  void openTasksTab() {
    setState(() {
      selectedIndex = 3;
      taskCreateRequestId = 0;
      shouldOpenTaskCreateOnStart = false;
    });
  }

  void openProjectsTab() {
    setState(() {
      selectedIndex = 1;
    });
  }

  Future<void> openUpcomingTaskDetail(TaskListItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => TaskDetailScreen(
          initialTask: item,
          onTaskChanged: loadDashboardData,
        ),
      ),
    );
  }

  Future<void> openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const NotificationsScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    loadUnreadNotificationCount();
  }

  Future<void> openProfile() async {
    final onLoggedOut = widget.onLoggedOut;

    if (onLoggedOut == null) {
      openProfileActions(context);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProfileScreen(
          user: widget.user,
          onThemeToggle: widget.onThemeToggle,
          onLoggedOut: onLoggedOut,
          onUserUpdated: widget.onUserUpdated,
        ),
      ),
    );
  }

  Color mutedColor(BuildContext context) {
    return PlanoraTheme.isDark(context)
        ? PlanoraTheme.darkTextMuted
        : PlanoraTheme.textSecondary;
  }

  BoxDecoration cardDecoration(BuildContext context, {double radius = 18}) {
    final isDark = PlanoraTheme.isDark(context);

    return BoxDecoration(
      color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
      ),
      boxShadow: PlanoraTheme.cardShadowFor(context),
    );
  }

  void openProfileActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Toggle theme'),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onThemeToggle();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Logout'),
                  onTap: () {
                    Navigator.pop(context);
                    if (widget.onLoggedOut != null) {
                      widget.onLoggedOut!();
                      return;
                    }
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildHeader(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final profilePic = widget.user.profilePic;
    final hasProfilePic = profilePic != null && profilePic.trim().isNotEmpty;

    return Row(
      children: [
        GestureDetector(
          onTap: openProfile,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: hasProfilePic
                  ? null
                  : PlanoraTheme.primaryGradientFor(context),
              boxShadow: PlanoraTheme.cardShadowFor(context),
            ),
            child: CircleAvatar(
              backgroundColor: Colors.transparent,
              backgroundImage: hasProfilePic ? NetworkImage(profilePic) : null,
              child: hasProfilePic
                  ? null
                  : Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $firstName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? PlanoraTheme.darkTextPrimary
                      : PlanoraTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Ready to plan something amazing?',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: mutedColor(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        buildHeaderButton(context, Icons.search_rounded),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: openNotifications,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              buildHeaderButton(context, Icons.notifications_none_rounded),
              if (hasUnreadNotifications)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildHeaderButton(BuildContext context, IconData icon) {
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      width: 44,
      height: 44,
      decoration: cardDecoration(context),
      child: Icon(
        icon,
        size: 21,
        color: isDark ? PlanoraTheme.darkTextPrimary : PlanoraTheme.textPrimary,
      ),
    );
  }

  int get activeProjectCount {
    return dashboardProjects.where((project) => project.isActive).length;
  }

  int get completedProjectCount {
    return dashboardProjects.where((project) => project.isCompleted).length;
  }

  int get overdueProjectCount {
    return dashboardProjects
        .where((project) => !project.isCompleted && project.daysLeft < 0)
        .length;
  }

  int get completedTaskCount {
    return dashboardTasks.where((item) => item.task.isCompleted).length;
  }

  int get overdueTaskCount {
    return dashboardTasks.where((item) => item.task.isOverdue).length;
  }

  int get blockedTaskCount {
    return dashboardTasks.where((item) => item.task.isBlocked).length;
  }

  int get atRiskCount {
    return overdueProjectCount + overdueTaskCount + blockedTaskCount;
  }

  double get dashboardProgress {
    if (dashboardTasks.isNotEmpty) {
      return completedTaskCount / dashboardTasks.length;
    }

    if (dashboardProjects.isNotEmpty) {
      return completedProjectCount / dashboardProjects.length;
    }

    return 0;
  }

  String get dashboardProgressLabel {
    if (dashboardTasks.isNotEmpty) {
      return 'Tasks Done';
    }

    if (dashboardProjects.isNotEmpty) {
      return 'Projects Done';
    }

    return 'No Data';
  }

  Widget buildProjectOverview(BuildContext context) {
    if (isLoadingDashboard) {
      return buildUpcomingStateCard(
        context,
        icon: Icons.sync_rounded,
        title: 'Loading dashboard from backend...',
        showSpinner: true,
      );
    }

    if (dashboardError != null) {
      return buildUpcomingStateCard(
        context,
        icon: Icons.wifi_off_rounded,
        title: dashboardError!,
        actionText: 'Try Again',
        onAction: loadDashboardData,
      );
    }

    final progress = dashboardProgress;
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(context, radius: 24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Project Overview',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? PlanoraTheme.darkTextPrimary
                        : PlanoraTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'This Month',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: mutedColor(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: mutedColor(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 112,
                height: 112,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 9,
                        strokeCap: StrokeCap.round,
                        color: Theme.of(context).colorScheme.primary,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.12),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(progress * 100).round()}%',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          dashboardProgressLabel,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  children: [
                    buildLegendRow(
                      context,
                      'Projects',
                      dashboardProjects.length.toString(),
                      Theme.of(context).colorScheme.primary,
                    ),
                    buildLegendRow(
                      context,
                      'Active',
                      activeProjectCount.toString(),
                      Colors.blueAccent,
                    ),
                    buildLegendRow(
                      context,
                      'At Risk',
                      atRiskCount.toString(),
                      atRiskCount > 0
                          ? PlanoraTheme.error
                          : PlanoraTheme.warning,
                    ),
                    buildLegendRow(
                      context,
                      'Completed Tasks',
                      completedTaskCount.toString(),
                      PlanoraTheme.success,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildLegendRow(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: mutedColor(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget buildSectionTitle(
    BuildContext context,
    String title, {
    String? action,
    VoidCallback? onAction,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              action,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }

  Widget buildQuickActions(BuildContext context) {
    final actions = [
      _HomeQuickAction(
        icon: Icons.add_rounded,
        label: 'New Project',
        isFilled: true,
        onTap: openProjectsTab,
      ),
      _HomeQuickAction(
        icon: Icons.check_box_outlined,
        label: 'New Task',
        isFilled: false,
        onTap: openNewTaskFlow,
      ),
      _HomeQuickAction(
        icon: Icons.groups_2_outlined,
        label: 'Invite Team',
        isFilled: false,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invite team flow is next.')),
          );
        },
      ),
      _HomeQuickAction(
        icon: Icons.description_outlined,
        label: 'View Reports',
        isFilled: false,
        onTap: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Reports are next.')));
        },
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildSectionTitle(context, 'Quick Actions'),
        const SizedBox(height: 10),
        Row(
          children: List.generate(actions.length, (index) {
            final action = actions[index];
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index == actions.length - 1 ? 0 : 10,
                ),
                child: buildQuickActionTile(
                  context,
                  icon: action.icon,
                  label: action.label,
                  isFilled: action.isFilled,
                  onTap: action.onTap,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget buildQuickActionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isFilled,
    required VoidCallback onTap,
  }) {
    final isDark = PlanoraTheme.isDark(context);
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 74,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isFilled)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: PlanoraTheme.primaryGradientFor(context),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: Colors.white),
              )
            else
              SizedBox(
                width: 28,
                height: 28,
                child: Icon(icon, size: 24, color: primary),
              ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? PlanoraTheme.darkTextPrimary
                    : PlanoraTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildProjects(BuildContext context) {
    if (isLoadingDashboard) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildSectionTitle(context, 'My Projects'),
          const SizedBox(height: 10),
          buildUpcomingStateCard(
            context,
            icon: Icons.sync_rounded,
            title: 'Loading projects...',
            showSpinner: true,
          ),
        ],
      );
    }

    if (dashboardError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildSectionTitle(context, 'My Projects'),
          const SizedBox(height: 10),
          buildUpcomingStateCard(
            context,
            icon: Icons.wifi_off_rounded,
            title: 'Could not load projects.',
            actionText: 'Try Again',
            onAction: loadDashboardData,
          ),
        ],
      );
    }

    final visibleProjects = dashboardProjects.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildSectionTitle(
          context,
          'My Projects',
          action: 'See All',
          onAction: openProjectsTab,
        ),
        const SizedBox(height: 10),
        if (visibleProjects.isEmpty)
          buildUpcomingStateCard(
            context,
            icon: Icons.folder_open_rounded,
            title: 'No projects yet',
            actionText: 'New Project',
            onAction: openProjectsTab,
          )
        else
          for (final project in visibleProjects) ...[
            buildProjectTile(context, project),
            if (project != visibleProjects.last) const SizedBox(height: 10),
          ],
      ],
    );
  }

  Future<void> openProjectDetail(ProjectModel project) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProjectDetailScreen(project: project),
      ),
    );

    if (!mounted) {
      return;
    }

    loadDashboardData();
  }

  List<TaskListItem> tasksForProject(ProjectModel project) {
    return dashboardTasks.where((item) {
      final sameProject = item.project.projectId == project.projectId;
      final sameTeam = item.project.teamId == project.teamId;
      return sameProject && sameTeam;
    }).toList();
  }

  double projectProgress(ProjectModel project) {
    final projectTasks = tasksForProject(project);

    if (projectTasks.isNotEmpty) {
      final completed = projectTasks
          .where((item) => item.task.isCompleted)
          .length;
      return completed / projectTasks.length;
    }

    if (project.isCompleted) return 1;
    if (project.status == 'in_progress') return 0.55;
    if (project.status == 'on_hold') return 0.35;
    if (project.status == 'cancelled') return 0;
    return 0.12;
  }

  Color projectAccentColor(ProjectModel project) {
    if (!project.isCompleted && project.daysLeft < 0) {
      return PlanoraTheme.error;
    }

    switch (project.status) {
      case 'completed':
        return PlanoraTheme.primaryPurple;
      case 'in_progress':
        return PlanoraTheme.success;
      case 'on_hold':
        return PlanoraTheme.warning;
      case 'cancelled':
        return PlanoraTheme.error;
      case 'not_started':
        return PlanoraTheme.info;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  Widget buildProjectTile(BuildContext context, ProjectModel project) {
    final color = projectAccentColor(project);
    final progress = projectProgress(project);
    final projectTasks = tasksForProject(project);

    return InkWell(
      onTap: () => openProjectDetail(project),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: cardDecoration(context),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withValues(alpha: 0.68)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.24),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                project.isTeamProject
                    ? Icons.groups_2_rounded
                    : Icons.folder_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 12,
                        color: project.daysLeft < 0 && !project.isCompleted
                            ? PlanoraTheme.error
                            : mutedColor(context),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          project.deadlineLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color:
                                    project.daysLeft < 0 && !project.isCompleted
                                    ? PlanoraTheme.error
                                    : mutedColor(context),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        projectTasks.isEmpty
                            ? project.statusLabel
                            : '${projectTasks.length} tasks',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: mutedColor(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${(progress * 100).round()}%',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: mutedColor(context)),
          ],
        ),
      ),
    );
  }

  Widget buildUpcomingTask(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildSectionTitle(
          context,
          'Upcoming Tasks',
          action: 'See All',
          onAction: openTasksTab,
        ),
        const SizedBox(height: 10),
        if (isLoadingDashboard)
          buildUpcomingStateCard(
            context,
            icon: Icons.sync_rounded,
            title: 'Loading upcoming tasks...',
            showSpinner: true,
          )
        else if (dashboardError != null)
          buildUpcomingStateCard(
            context,
            icon: Icons.wifi_off_rounded,
            title: 'Could not load upcoming tasks.',
            actionText: 'Try Again',
            onAction: loadDashboardData,
          )
        else if (upcomingTasks.isEmpty)
          buildUpcomingStateCard(
            context,
            icon: Icons.check_circle_outline_rounded,
            title: 'No upcoming tasks',
            actionText: 'New Task',
            onAction: openNewTaskFlow,
          )
        else
          for (final item in upcomingTasks) ...[
            buildUpcomingTaskTile(context, item),
            if (item != upcomingTasks.last) const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget buildUpcomingStateCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    bool showSpinner = false,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(context),
      child: Row(
        children: [
          if (showSpinner)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          else
            Icon(icon, color: mutedColor(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: mutedColor(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (actionText != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(onPressed: onAction, child: Text(actionText)),
          ],
        ],
      ),
    );
  }

  Widget buildUpcomingTaskTile(BuildContext context, TaskListItem item) {
    final task = item.task;
    final priorityColor = upcomingPriorityColor(task.priority);

    return InkWell(
      onTap: () => openUpcomingTaskDetail(item),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(context),
        child: Row(
          children: [
            Icon(
              task.isBlocked
                  ? Icons.pause_circle_outline_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: task.isBlocked
                  ? PlanoraTheme.warning
                  : mutedColor(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        Icons.folder_rounded,
                        size: 13,
                        color: mutedColor(context),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          item.project.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: mutedColor(context),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: task.isOverdue
                            ? PlanoraTheme.error
                            : mutedColor(context),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          task.dueDateLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: task.isOverdue
                                    ? PlanoraTheme.error
                                    : mutedColor(context),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              constraints: const BoxConstraints(maxWidth: 72),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: priorityColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                task.priority.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: priorityColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color upcomingPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return PlanoraTheme.success;
      case TaskPriority.medium:
        return PlanoraTheme.info;
      case TaskPriority.high:
        return Theme.of(context).colorScheme.primary;
    }
  }

  Widget buildHomeDashboard(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildProjectOverview(context),
          const SizedBox(height: 22),
          buildQuickActions(context),
          const SizedBox(height: 22),
          buildProjects(context),
          const SizedBox(height: 22),
          buildUpcomingTask(context),
        ],
      ),
    );
  }

  Widget buildComingSoonPage(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    final isDark = PlanoraTheme.isDark(context);

    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: cardDecoration(context, radius: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: PlanoraTheme.primaryGradientFor(context),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: isDark
                    ? PlanoraTheme.darkTextPrimary
                    : PlanoraTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: mutedColor(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCurrentPage(BuildContext context) {
    switch (selectedIndex) {
      case 0:
        return buildHomeDashboard(context);

      case 1:
        return ProjectsScreen(
          onBack: () {
            setState(() {
              selectedIndex = 0;
            });
            loadDashboardData();
          },
        );

      case 2:
        return AiChatScreen(onOpenProjects: openProjectsTab);

      case 3:
        return TasksScreen(
          profilePic: widget.user.profilePic,
          userInitials: initials,
          createRequestId: taskCreateRequestId,
          openCreateOnStart: shouldOpenTaskCreateOnStart,
          onCreateRequestConsumed: () {
            if (!mounted) {
              return;
            }

            setState(() {
              taskCreateRequestId = 0;
              shouldOpenTaskCreateOnStart = false;
            });
          },
          onTasksChanged: loadDashboardData,
          onBack: () {
            setState(() {
              selectedIndex = 0;
              taskCreateRequestId = 0;
              shouldOpenTaskCreateOnStart = false;
            });
            loadDashboardData();
          },
        );

      case 4:
        return buildComingSoonPage(
          context,
          icon: Icons.calendar_month_rounded,
          title: 'Calendar',
          message: 'Calendar planning will be connected later.',
        );

      default:
        return buildHomeDashboard(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: HomeBottomNav(
        selectedIndex: selectedIndex,
        onTap: (index) {
          setState(() {
            if (index == 3) {
              taskCreateRequestId = 0;
              shouldOpenTaskCreateOnStart = false;
            }

            selectedIndex = index;
          });

          if (index == 0) {
            loadDashboardData();
          }
        },
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: PlanoraTheme.onboardingBackgroundFor(context),
        ),
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  children: [
                    if (selectedIndex == 0) ...[
                      buildHeader(context),
                      const SizedBox(height: 24),
                    ],
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        layoutBuilder: (currentChild, previousChildren) {
                          return Stack(
                            fit: StackFit.expand,
                            alignment: Alignment.topCenter,
                            children: [
                              for (final child in previousChildren)
                                Positioned.fill(child: child),
                              if (currentChild != null)
                                Positioned.fill(child: currentChild),
                            ],
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey<int>(selectedIndex),
                          child: buildCurrentPage(context),
                        ),
                      ),
                    ),
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

class _HomeQuickAction {
  final IconData icon;
  final String label;
  final bool isFilled;
  final VoidCallback onTap;

  const _HomeQuickAction({
    required this.icon,
    required this.label,
    required this.isFilled,
    required this.onTap,
  });
}
