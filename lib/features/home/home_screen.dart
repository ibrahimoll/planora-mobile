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
import '../auth/data/project_api.dart';
import '../auth/models/auth_models.dart';
import '../auth/models/project_models.dart';
import 'widgets/home_bottom_nav.dart';

enum DashboardRange {
  week('This Week'),
  month('This Month'),
  all('All Time');

  const DashboardRange(this.label);

  final String label;
}

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
  DashboardRange dashboardRange = DashboardRange.month;

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
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }

    return source[0].toUpperCase();
  }

  String? get profilePicUrl {
    final value = widget.user.profilePic?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  DateTime? get dashboardRangeStart {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (dashboardRange) {
      case DashboardRange.week:
        return today.subtract(Duration(days: today.weekday - 1));
      case DashboardRange.month:
        return DateTime(today.year, today.month);
      case DashboardRange.all:
        return null;
    }
  }

  List<ProjectModel> get filteredDashboardProjects {
    return dashboardProjects.where(projectMatchesDashboardRange).toList();
  }

  List<TaskListItem> get filteredDashboardTasks {
    return dashboardTasks.where(taskMatchesDashboardRange).toList();
  }

  int get activeProjectCount {
    return filteredDashboardProjects
        .where((project) => project.isActive)
        .length;
  }

  int get completedProjectCount {
    return filteredDashboardProjects
        .where((project) => project.isCompleted)
        .length;
  }

  int get overdueProjectCount {
    return filteredDashboardProjects
        .where((project) => !project.isCompleted && project.daysLeft < 0)
        .length;
  }

  int get completedTaskCount {
    return filteredDashboardTasks.where((item) => item.task.isCompleted).length;
  }

  int get overdueTaskCount {
    return filteredDashboardTasks.where((item) => item.task.isOverdue).length;
  }

  int get blockedTaskCount {
    return filteredDashboardTasks.where((item) => item.task.isBlocked).length;
  }

  int get atRiskCount {
    return overdueProjectCount + overdueTaskCount + blockedTaskCount;
  }

  double get dashboardProgress {
    final filteredTasks = filteredDashboardTasks;
    final filteredProjects = filteredDashboardProjects;

    if (filteredTasks.isNotEmpty) {
      return completedTaskCount / filteredTasks.length;
    }

    if (filteredProjects.isNotEmpty) {
      return completedProjectCount / filteredProjects.length;
    }

    return 0;
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

  bool isDateInDashboardRange(DateTime? date) {
    if (dashboardRange == DashboardRange.all) return true;
    if (date == null) return false;

    final start = dashboardRangeStart;
    if (start == null) return true;

    final nextStart = switch (dashboardRange) {
      DashboardRange.week => start.add(const Duration(days: 7)),
      DashboardRange.month => DateTime(start.year, start.month + 1),
      DashboardRange.all => null,
    };

    return !date.isBefore(start) &&
        (nextStart == null || date.isBefore(nextStart));
  }

  bool projectMatchesDashboardRange(ProjectModel project) {
    if (dashboardRange == DashboardRange.all) return true;
    return isDateInDashboardRange(project.createdAt) ||
        isDateInDashboardRange(project.deadline);
  }

  bool taskMatchesDashboardRange(TaskListItem item) {
    if (dashboardRange == DashboardRange.all) return true;
    return isDateInDashboardRange(item.task.createdAt) ||
        isDateInDashboardRange(item.task.dueDate) ||
        isDateInDashboardRange(item.task.completedAt);
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

  void openManualProjectFlow() {
    openNewProjectFlow(mode: ProjectCreateStartMode.manual);
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

  void openAiPlannerTab() {
    setState(() => selectedIndex = 2);
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
      projectCreateRequestId = 0;
      shouldOpenProjectCreateOnStart = false;
      projectCreateStartMode = ProjectCreateStartMode.modeChoice;
    });
  }

  void openTeamsTab() {
    setState(() => selectedIndex = 4);
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

  Future<void> openTeams() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TeamsScreen(
          showBackButton: true,
          currentUserId: widget.user.userId,
          onTeamsChanged: () {
            loadDashboardData();
            loadPendingTeamInvitationCount();
          },
        ),
      ),
    );

    if (!mounted) return;
    loadDashboardData();
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
                  leading: const Icon(Icons.groups_2_outlined),
                  title: const Text('Teams'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    openTeams();
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

  void showDashboardRangeSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = PlanoraTheme.isDark(sheetContext);

        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
              ),
              boxShadow: PlanoraTheme.cardShadowFor(sheetContext),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final range in DashboardRange.values)
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: Icon(
                      dashboardRange == range
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: dashboardRange == range
                          ? Theme.of(sheetContext).colorScheme.primary
                          : mutedColor(sheetContext),
                    ),
                    title: Text(
                      range.label,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      setState(() => dashboardRange = range);
                    },
                  ),
              ],
            ),
          ),
        );
      },
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
      onRefresh: refreshDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  buildAnimatedEntrance(0, buildHeader(context)),
                  const SizedBox(height: 18),
                  buildAnimatedEntrance(1, buildMainAiPlanningCard(context)),
                  const SizedBox(height: 18),
                  buildAnimatedEntrance(2, buildTodayFocus(context)),
                  const SizedBox(height: 18),
                  buildProjectOverview(context),
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

  Widget buildAnimatedEntrance(int index, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 340 + (index * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: Transform.scale(
              scale: 0.96 + (value * 0.04),
              child: animatedChild,
            ),
          ),
        );
      },
      child: child,
    );
  }

  Widget buildAvatarFallback(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
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

  Widget buildHomeAvatar(BuildContext context) {
    final imageUrl = profilePicUrl;

    return GestureDetector(
      onTap: openProfile,
      child: Container(
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
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Home avatar load failed: $error');
                    return buildAvatarFallback(context);
                  },
                ),
        ),
      ),
    );
  }

  Widget buildHeader(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Row(
      children: [
        buildHomeAvatar(context),
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
                  fontWeight: FontWeight.w900,
                  color: isDark
                      ? PlanoraTheme.darkTextPrimary
                      : PlanoraTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'What should Planora help you?',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: mutedColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: openSearch,
          child: buildHeaderButton(context, Icons.search_rounded),
        ),
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

  Widget buildMainAiPlanningCard(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: openAiPlanningFlow,
        borderRadius: BorderRadius.circular(30),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: PlanoraTheme.primaryGradientFor(context),
            borderRadius: BorderRadius.circular(30),
            boxShadow: PlanoraTheme.floatingShadowFor(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.24),
                      ),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'AI-first',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'What do you want to plan today?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Describe an idea and Planora will shape the plan, tasks, timeline, and risks.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: isDark ? 0.84 : 0.90),
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        'Plan with AI',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(15),
                    child: InkWell(
                      onTap: openAiPlannerTab,
                      borderRadius: BorderRadius.circular(15),
                      child: Ink(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTodayFocus(BuildContext context) {
    if (isLoadingDashboard) {
      return buildFocusSection(
        context,
        icon: Icons.sync_rounded,
        title: 'Loading today focus...',
        message: 'Checking tasks, deadlines, and project health.',
        showSpinner: true,
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

  Widget buildFocusSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    String? actionText,
    VoidCallback? onAction,
    Color? accent,
    bool showSpinner = false,
  }) {
    final color = accent ?? Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildSectionTitle(context, "Today's Focus"),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDecoration(context, radius: 22),
          child: Row(
            children: [
              if (showSpinner)
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2.6),
                )
              else
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
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

  Widget buildProjectOverview(BuildContext context) {
    if (isLoadingDashboard) {
      return buildAnimatedEntrance(
        3,
        buildUpcomingStateCard(
          context,
          icon: Icons.sync_rounded,
          title: 'Loading dashboard from backend...',
          showSpinner: true,
        ),
      );
    }

    if (dashboardError != null) {
      return buildAnimatedEntrance(
        3,
        buildUpcomingStateCard(
          context,
          icon: Icons.wifi_off_rounded,
          title: dashboardError!,
          actionText: 'Try Again',
          onAction: loadDashboardData,
        ),
      );
    }

    final progress = dashboardProgress;
    final isDark = PlanoraTheme.isDark(context);
    final primary = Theme.of(context).colorScheme.primary;

    return buildAnimatedEntrance(
      3,
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [PlanoraTheme.darkSurface, PlanoraTheme.darkSurfaceVariant]
                : [Colors.white, const Color(0xFFF7F0FF)],
          ),
          border: Border.all(
            color: primary.withValues(alpha: isDark ? 0.20 : 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: isDark ? 0.18 : 0.12),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedProgress, _) {
                    return SizedBox(
                      width: 118,
                      height: 118,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 112,
                            height: 112,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primary.withValues(alpha: 0.06),
                            ),
                          ),
                          SizedBox(
                            width: 94,
                            height: 94,
                            child: CircularProgressIndicator(
                              value: animatedProgress,
                              strokeWidth: 10,
                              strokeCap: StrokeCap.round,
                              color: primary,
                              backgroundColor: primary.withValues(alpha: 0.12),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(animatedProgress * 100).round()}%',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: isDark
                                          ? PlanoraTheme.darkTextPrimary
                                          : PlanoraTheme.textPrimary,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildHealthMetricPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.20 : 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: mutedColor(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: isDark
                  ? PlanoraTheme.darkTextPrimary
                  : PlanoraTheme.textPrimary,
            ),
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

  Widget buildProjects(BuildContext context) {
    if (isLoadingDashboard) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildSectionTitle(context, 'Continue Planning'),
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
          buildSectionTitle(context, 'Continue Planning'),
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
          'Continue Planning',
          action: 'All Plans',
          onAction: openProjectsTab,
        ),
        const SizedBox(height: 10),
        if (visibleProjects.isEmpty)
          buildUpcomingStateCard(
            context,
            icon: Icons.folder_open_rounded,
            title: 'No plans yet',
            actionText: 'Plan with AI',
            onAction: openAiPlanningFlow,
          )
        else
          for (final project in visibleProjects) ...[
            buildAnimatedEntrance(7, buildProjectTile(context, project)),
            if (project != visibleProjects.last) const SizedBox(height: 10),
          ],
      ],
    );
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
    final isDark = PlanoraTheme.isDark(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: () => openProjectDetail(project),
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: cardDecoration(context, radius: 22),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withValues(alpha: 0.68)],
                  ),
                  borderRadius: BorderRadius.circular(16),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            project.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? PlanoraTheme.darkTextPrimary
                                      : PlanoraTheme.textPrimary,
                                ),
                          ),
                        ),
                        Text(
                          '${(progress * 100).round()}%',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
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
                                      project.daysLeft < 0 &&
                                          !project.isCompleted
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
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: mutedColor(context),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0, 1),
                        minHeight: 5,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.chevron_right_rounded, color: mutedColor(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildUpcomingStateCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? actionText,
    VoidCallback? onAction,
    bool showSpinner = false,
  }) {
    final color = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(context, radius: 22),
      child: Row(
        children: [
          if (showSpinner)
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            )
          else
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color),
            ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900),
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
}
