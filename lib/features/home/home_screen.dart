// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:mobile/features/ai/ai_chat_screen.dart';
import 'package:mobile/features/notifications/data/notifications_api.dart';
import 'package:mobile/features/notifications/notifications_screen.dart';
import 'package:mobile/features/profile/profile_screen.dart';
import 'package:mobile/features/projects/ai_project_wizard_screen.dart';
import 'package:mobile/features/projects/project_detail_screen.dart';
import 'package:mobile/features/projects/projects_screen.dart';
import 'package:mobile/features/search/search_screen.dart';
import 'package:mobile/features/tasks/data/tasks_api.dart';
import 'package:mobile/features/tasks/models/task_models.dart';
import 'package:mobile/features/tasks/task_detail_screen.dart';
import 'package:mobile/features/tasks/tasks_screen.dart';
import 'package:mobile/features/teams/data/teams_api.dart';
import 'package:mobile/features/teams/teams_screen.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/planora_theme.dart';
import '../../core/ui/planora_ui.dart';
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
  final TeamsApi _teamsApi = const TeamsApi();

  int selectedIndex = 0;
  int projectCreateRequestId = 0;
  int taskCreateRequestId = 0;
  ProjectCreateStartMode projectCreateStartMode =
      ProjectCreateStartMode.modeChoice;

  bool hasUnreadNotifications = false;
  int pendingTeamInvitationCount = 0;
  bool isLoadingDashboard = true;
  bool shouldOpenTaskCreateOnStart = false;
  bool shouldOpenProjectCreateOnStart = false;
  String? dashboardError;

  List<ProjectModel> dashboardProjects = [];
  List<TaskListItem> dashboardTasks = [];
  List<TaskListItem> upcomingTasks = [];

  @override
  void initState() {
    super.initState();
    loadDashboardData();
    loadUnreadNotificationCount();
    loadPendingTeamInvitationCount();
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
    return 'Welcome back';
  }

  String get initials {
    final source = displayName.trim();
    if (source.isEmpty) return 'P';
    final parts = source.split(RegExp(r'\s+'));
    if (parts.length >= 2)
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return source[0].toUpperCase();
  }

  String? get profilePicUrl {
    final value = widget.user.profilePic?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> loadDashboardData() async {
    if (mounted) {
      setState(() {
        isLoadingDashboard = true;
        dashboardError = null;
      });
    }

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

      if (!mounted) return;
      setState(() {
        dashboardProjects = loadedProjects;
        dashboardTasks = loadedTasks;
        upcomingTasks = nextTasks.take(3).toList();
        isLoadingDashboard = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Dashboard load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
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
      if (!mounted) return;
      setState(() => hasUnreadNotifications = unreadCount > 0);
    } catch (error, stackTrace) {
      debugPrint('Unread notification count load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => hasUnreadNotifications = false);
    }
  }

  Future<void> loadPendingTeamInvitationCount() async {
    try {
      final invitations = await _teamsApi.getMyInvitations();
      final pendingCount = invitations.where((item) => item.isPending).length;
      if (!mounted) return;
      setState(() => pendingTeamInvitationCount = pendingCount);
    } catch (error, stackTrace) {
      debugPrint('Team invitation count load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => pendingTeamInvitationCount = 0);
    }
  }

  Future<void> refreshDashboard() async {
    await Future.wait([
      loadDashboardData(),
      loadUnreadNotificationCount(),
      loadPendingTeamInvitationCount(),
    ]);
  }

  int compareTaskItemsByDueDate(TaskListItem left, TaskListItem right) {
    final leftDue = left.task.dueDate;
    final rightDue = right.task.dueDate;
    if (leftDue == null && rightDue == null) {
      return left.task.createdAt.compareTo(right.task.createdAt);
    }
    if (leftDue == null) return 1;
    if (rightDue == null) return -1;
    return leftDue.compareTo(rightDue);
  }

  int compareUpcomingTaskItems(TaskListItem left, TaskListItem right) {
    if (left.task.isOverdue != right.task.isOverdue) {
      return left.task.isOverdue ? -1 : 1;
    }
    return compareTaskItemsByDueDate(left, right);
  }

  Color mutedColor(BuildContext context) => PlanoraTheme.isDark(context)
      ? PlanoraTheme.darkTextMuted
      : PlanoraTheme.textSecondary;

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

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    return Scaffold(
      backgroundColor: isDark
          ? PlanoraTheme.darkBackground
          : PlanoraTheme.background,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: PlanoraTheme.onboardingBackgroundFor(context),
        ),
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(
              key: ValueKey<int>(selectedIndex),
              child: buildSelectedContent(context),
            ),
          ),
        ),
      ),
      bottomNavigationBar: HomeBottomNav(
        selectedIndex: selectedIndex,
        teamsBadgeCount: pendingTeamInvitationCount,
        onTap: (index) {
          setState(() {
            selectedIndex = index;
            if (index != 1) {
              shouldOpenProjectCreateOnStart = false;
              projectCreateRequestId = 0;
            }
            if (index != 3) {
              shouldOpenTaskCreateOnStart = false;
              taskCreateRequestId = 0;
            }
          });
        },
      ),
    );
  }

  Widget buildSelectedContent(BuildContext context) {
    switch (selectedIndex) {
      case 1:
        return ProjectsScreen(
          onBack: () => setState(() => selectedIndex = 0),
          createRequestId: projectCreateRequestId,
          openCreateOnStart: shouldOpenProjectCreateOnStart,
          createStartMode: projectCreateStartMode,
          onCreateRequestConsumed: () {
            if (!mounted) return;
            setState(() => shouldOpenProjectCreateOnStart = false);
          },
        );
      case 2:
        return AiChatScreen(onOpenProjects: openProjectsTab);
      case 3:
        return TasksScreen(
          onBack: () => setState(() => selectedIndex = 0),
          createRequestId: taskCreateRequestId,
          openCreateOnStart: shouldOpenTaskCreateOnStart,
          profilePic: profilePicUrl,
          userInitials: initials,
          onTasksChanged: loadDashboardData,
          onCreateAiPlan: openAiPlanningFlow,
          onCreateRequestConsumed: () {
            if (!mounted) return;
            setState(() => shouldOpenTaskCreateOnStart = false);
          },
        );
      case 4:
        return TeamsScreen(
          currentUserId: widget.user.userId,
          onTeamsChanged: () {
            loadDashboardData();
            loadPendingTeamInvitationCount();
          },
        );
      case 0:
      default:
        return buildHomeDashboard(context);
    }
  }

  Widget buildHomeDashboard(BuildContext context) {
    return RefreshIndicator(
      key: const Key('home_screen'),
      color: Theme.of(context).colorScheme.primary,
      backgroundColor: PlanoraTheme.isDark(context)
          ? PlanoraTheme.darkSurface
          : PlanoraTheme.surface,
      onRefresh: refreshDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PlanoraAnimatedIn(index: 0, child: buildHeader(context)),
                  const SizedBox(height: 18),
                  PlanoraAnimatedIn(
                    index: 1,
                    child: buildMainAiPlanningCard(context),
                  ),
                  const SizedBox(height: 18),
                  PlanoraAnimatedIn(index: 2, child: buildTodayFocus(context)),
                  const SizedBox(height: 18),
                  PlanoraAnimatedIn(
                    index: 3,
                    child: buildProductivitySnapshot(context),
                  ),
                  const SizedBox(height: 18),
                  buildProjects(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildHeader(BuildContext context) {
    return PlanoraHomeTopBar(
      greeting: '$greeting, $firstName',
      subtitle: 'What should Planora help you?',
      avatar: GestureDetector(
        key: const Key('home_profile_button'),
        onTap: openProfile,
        child: buildHomeAvatar(context),
      ),
      onSearch: openSearch,
      onNotifications: openNotifications,
      hasUnreadNotifications: hasUnreadNotifications,
    );
  }

  Widget buildHomeAvatar(BuildContext context) {
    final imageUrl = profilePicUrl;
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: PlanoraTheme.cardShadowFor(context),
      ),
      child: ClipOval(
        child: imageUrl == null
            ? buildAvatarFallback(context)
            : Image.network(
                imageUrl,
                width: 46,
                height: 46,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => buildAvatarFallback(context),
              ),
      ),
    );
  }

  Widget buildAvatarFallback(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: PlanoraTheme.primaryGradientFor(context),
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget buildMainAiPlanningCard(BuildContext context) {
    return PlanoraHeroPromptCard(
      title: 'What do you want to plan today?',
      description:
          'Describe an idea and Planora will shape the plan, tasks, timeline, and risks.',
      buttonText: 'Plan with AI',
      onButtonPressed: openAiPlanningFlow,
      trailingIcon: Icons.chat_bubble_outline_rounded,
      badgeText: 'AI-first',
    );
  }

  Widget buildTodayFocus(BuildContext context) {
    if (isLoadingDashboard) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildSectionTitle(context, "Today's Focus"),
          const SizedBox(height: 10),
          const PlanoraSkeletonFeed(itemCount: 1, topPadding: 0, dense: true),
        ],
      );
    }

    if (dashboardError != null) {
      return buildFocusSection(
        context,
        icon: Icons.wifi_off_rounded,
        title: 'Could not load today focus',
        message: 'Refresh when the backend is reachable.',
        actionText: 'Try Again',
        onAction: loadDashboardData,
      );
    }

    final overdueTasks =
        dashboardTasks.where((item) => item.task.isOverdue).toList()
          ..sort(compareUpcomingTaskItems);
    final focusTask = overdueTasks.isNotEmpty
        ? overdueTasks.first
        : upcomingTasks.isEmpty
        ? null
        : upcomingTasks.first;

    if (focusTask == null) {
      return buildFocusSection(
        context,
        icon: Icons.auto_awesome_rounded,
        title: 'Plan your next move',
        message: dashboardProjects.isEmpty
            ? 'Start with an idea and let Planora build the first plan.'
            : 'No urgent tasks. Ask Planora to refine a plan or create the next task.',
        actionText: dashboardProjects.isEmpty ? 'Plan with AI' : 'Ask Planora',
        onAction: dashboardProjects.isEmpty
            ? openAiPlanningFlow
            : openAiPlannerTab,
      );
    }

    final task = focusTask.task;
    return buildFocusSection(
      context,
      icon: task.isOverdue
          ? Icons.warning_amber_rounded
          : Icons.radio_button_unchecked_rounded,
      title: task.isOverdue ? 'Overdue: ${task.title}' : task.title,
      message: '${focusTask.project.title} - ${task.dueDateLabel}',
      actionText: 'Open Task',
      onAction: () => openUpcomingTaskDetail(focusTask),
      accent: task.isOverdue ? PlanoraTheme.error : null,
    );
  }

  Widget buildProductivitySnapshot(BuildContext context) {
    if (isLoadingDashboard) {
      return const PlanoraSkeletonFeed(
        itemCount: 1,
        topPadding: 0,
        dense: true,
      );
    }

    final totalTasks = dashboardTasks.length;
    final completedTasks = dashboardTasks
        .where((item) => item.task.isCompleted)
        .length;
    final overdueTasks = dashboardTasks
        .where((item) => item.task.isOverdue && !item.task.isCompleted)
        .length;
    final completionPercent = totalTasks == 0
        ? 0
        : ((completedTasks / totalTasks) * 100).round();
    final accent = overdueTasks > 0
        ? PlanoraTheme.error
        : completionPercent >= 70
        ? PlanoraTheme.success
        : Theme.of(context).colorScheme.primary;

    return PlanoraCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.insights_rounded, color: accent),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Productivity Snapshot',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      overdueTasks > 0
                          ? 'Clear overdue tasks first to reduce risk.'
                          : 'Focus on one active task to keep progress moving.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: mutedColor(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$completionPercent%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (completionPercent / 100).clamp(0.0, 1.0),
              minHeight: 7,
              color: accent,
              backgroundColor: accent.withValues(alpha: .12),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildFocusSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    String? actionText,
    VoidCallback? onAction,
    Color? accent,
  }) {
    final color = accent ?? Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildSectionTitle(context, "Today's Focus"),
        const SizedBox(height: 10),
        PlanoraCard(
          radius: 22,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: mutedColor(context),
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (actionText != null && onAction != null) ...[
                const SizedBox(width: 8),
                TextButton(onPressed: onAction, child: Text(actionText)),
              ],
            ],
          ),
        ),
      ],
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

  Widget buildProjects(BuildContext context) {
    if (isLoadingDashboard) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildSectionTitle(context, 'Continue Planning'),
          const SizedBox(height: 10),
          const PlanoraSkeletonFeed(itemCount: 3, topPadding: 0, dense: true),
        ],
      );
    }

    if (dashboardError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildSectionTitle(context, 'Continue Planning'),
          const SizedBox(height: 10),
          PlanoraMessageState(
            icon: Icons.wifi_off_rounded,
            title: 'Could not load projects',
            message: 'Refresh when the backend is reachable.',
            actionText: 'Try Again',
            onAction: loadDashboardData,
            topMargin: 0,
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
          'Continue Planning',
          action: 'All Plans',
          onAction: openProjectsTab,
        ),
        const SizedBox(height: 10),
        if (visibleProjects.isEmpty)
          PlanoraMessageState(
            icon: Icons.folder_open_rounded,
            title: 'No plans yet',
            message:
                'Start with an idea and let Planora build your first plan.',
            actionText: 'Plan with AI',
            onAction: openAiPlanningFlow,
            topMargin: 0,
          )
        else
          for (int index = 0; index < visibleProjects.length; index++) ...[
            PlanoraAnimatedIn(
              index: 4 + index,
              child: buildProjectTile(context, visibleProjects[index]),
            ),
            if (index != visibleProjects.length - 1) const SizedBox(height: 10),
          ],
      ],
    );
  }

  List<TaskListItem> tasksForProject(ProjectModel project) {
    return dashboardTasks
        .where(
          (item) =>
              item.project.projectId == project.projectId &&
              item.project.teamId == project.teamId,
        )
        .toList();
  }

  double projectProgress(ProjectModel project) {
    final projectTasks = tasksForProject(project);
    if (projectTasks.isNotEmpty) {
      return projectTasks.where((item) => item.task.isCompleted).length /
          projectTasks.length;
    }
    if (project.isCompleted) return 1;
    if (project.status == 'in_progress') return .55;
    if (project.status == 'on_hold') return .35;
    return 0;
  }

  Color projectAccentColor(ProjectModel project) {
    if (!project.isCompleted && project.daysLeft < 0) return PlanoraTheme.error;
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
    return PlanoraCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      onTap: () => openProjectDetail(project),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: .68)],
              ),
              borderRadius: BorderRadius.circular(16),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        project.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  projectTasks.isEmpty
                      ? project.deadlineLabel
                      : '${project.deadlineLabel} • ${projectTasks.length} tasks',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: mutedColor(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0, 1),
                    minHeight: 5,
                    color: color,
                    backgroundColor: color.withValues(alpha: .12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.chevron_right_rounded, color: mutedColor(context)),
        ],
      ),
    );
  }

  void openNewTaskFlow() {
    setState(() {
      selectedIndex = 3;
      taskCreateRequestId += 1;
      shouldOpenTaskCreateOnStart = true;
    });
  }

  void openNewProjectFlow({
    ProjectCreateStartMode mode = ProjectCreateStartMode.modeChoice,
  }) {
    setState(() {
      selectedIndex = 1;
      projectCreateRequestId += 1;
      shouldOpenProjectCreateOnStart = true;
      projectCreateStartMode = mode;
    });
  }

  Future<void> openAiPlanningFlow() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AiProjectWizardScreen(onPlanCreated: loadDashboardData),
      ),
    );
    if (!mounted) return;
    loadDashboardData();
  }

  void openAiPlannerTab() => setState(() => selectedIndex = 2);

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
      projectCreateRequestId = 0;
      shouldOpenProjectCreateOnStart = false;
      projectCreateStartMode = ProjectCreateStartMode.modeChoice;
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
    if (!mounted) return;
    loadDashboardData();
  }

  Future<void> openProjectDetail(ProjectModel project) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProjectDetailScreen(
          project: project,
          onProjectChanged: loadDashboardData,
        ),
      ),
    );
    if (!mounted) return;
    loadDashboardData();
  }

  Future<void> openSearch() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SearchScreen()));
    if (!mounted) return;
    loadDashboardData();
  }

  Future<void> openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            NotificationsScreen(currentUserId: widget.user.userId),
      ),
    );
    if (!mounted) return;
    loadUnreadNotificationCount();
    loadPendingTeamInvitationCount();
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

  void openProfileActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
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
                    Navigator.pop(sheetContext);
                    widget.onThemeToggle();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Logout'),
                  onTap: () {
                    Navigator.pop(sheetContext);
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
}
