import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../auth/data/project_api.dart';
import '../auth/models/project_models.dart';
import '../teams/teams_screen.dart';
import '../tasks/data/tasks_api.dart';
import '../tasks/models/task_models.dart';
import 'ai_project_wizard_screen.dart';
import 'project_detail_screen.dart';

enum ProjectCreateStartMode { modeChoice, manual, ai }

class ProjectsScreen extends StatefulWidget {
  final VoidCallback onBack;
  final int createRequestId;
  final bool openCreateOnStart;
  final ProjectCreateStartMode createStartMode;
  final VoidCallback? onCreateRequestConsumed;

  const ProjectsScreen({
    super.key,
    required this.onBack,
    this.createRequestId = 0,
    this.openCreateOnStart = false,
    this.createStartMode = ProjectCreateStartMode.modeChoice,
    this.onCreateRequestConsumed,
  });

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final ProjectsApi _projectsApi = const ProjectsApi();
  final TasksApi _tasksApi = const TasksApi();

  int selectedFilterIndex = 0;
  int? selectedTeamId;

  bool isLoading = true;
  bool isCreatingProject = false;
  bool isLoadingTeams = false;

  String? errorMessage;
  String? taskSummaryWarning;
  DateTime? selectedDeadline;

  List<ProjectModel> projects = [];
  List<TaskListItem> projectTasks = [];
  List<TeamModel> teams = [];
  String selectedProjectType = 'personal';
  int handledCreateRequestId = 0;

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadProjects();
    scheduleCreateProjectSheet();
  }

  @override
  void didUpdateWidget(covariant ProjectsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    scheduleCreateProjectSheet();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> loadProjects() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      taskSummaryWarning = null;
    });

    try {
      final loadedProjects = await _projectsApi.getProjects();
      var hadTaskLoadError = false;
      final taskGroups = await Future.wait(
        loadedProjects.map((project) async {
          try {
            return await _tasksApi.getProjectTasks(
              project: TaskProjectSummary.fromProject(project),
            );
          } catch (error, stackTrace) {
            debugPrint(
              'Project task summary load failed for project ${project.projectId}: $error',
            );
            debugPrintStack(stackTrace: stackTrace);
            hadTaskLoadError = true;
            return <TaskListItem>[];
          }
        }),
      );
      final loadedTasks = taskGroups.expand((group) => group).toList();

      if (!mounted) return;

      setState(() {
        projects = loadedProjects;
        projectTasks = loadedTasks;
        taskSummaryWarning = hadTaskLoadError
            ? 'Some project task summaries could not be loaded.'
            : null;
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Project list load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        errorMessage = error is ApiException
            ? 'Could not load plans: ${error.message}'
            : 'Could not load plans. Please try again.';
        taskSummaryWarning = null;
        projectTasks = [];
        isLoading = false;
      });
    }
  }

  Future<void> loadTeamsForCreateSheet() async {
    setState(() {
      isLoadingTeams = true;
    });

    try {
      final loadedTeams = await _projectsApi.getTeams();

      if (!mounted) {
        return;
      }

      setState(() {
        teams = loadedTeams;
        selectedTeamId = loadedTeams.isEmpty
            ? null
            : selectedTeamId == null
            ? loadedTeams.first.teamId
            : loadedTeams.any((team) => team.teamId == selectedTeamId)
            ? selectedTeamId
            : loadedTeams.first.teamId;
        isLoadingTeams = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Team load for project creation failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        teams = [];
        selectedTeamId = null;
        isLoadingTeams = false;
      });
    }
  }

  void scheduleCreateProjectSheet() {
    if (!widget.openCreateOnStart || widget.createRequestId == 0) {
      return;
    }

    if (handledCreateRequestId == widget.createRequestId) {
      return;
    }

    handledCreateRequestId = widget.createRequestId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      widget.onCreateRequestConsumed?.call();

      switch (widget.createStartMode) {
        case ProjectCreateStartMode.manual:
          showManualCreateProjectSheet();
        case ProjectCreateStartMode.ai:
          openAiProjectWizard();
        case ProjectCreateStartMode.modeChoice:
          showCreateProjectSheet();
      }
    });
  }

  List<ProjectModel> get filteredProjects {
    if (selectedFilterIndex == 1) {
      return projects.where((project) => project.isActive).toList();
    }

    if (selectedFilterIndex == 2) {
      return projects.where((project) => project.isCompleted).toList();
    }

    return projects;
  }

  int get totalProjectsCount {
    return projects.length;
  }

  int get activeProjectsCount {
    return projects.where((project) => project.isActive).length;
  }

  int get completedProjectsCount {
    return projects.where((project) => project.isCompleted).length;
  }

  List<TaskListItem> tasksForProject(ProjectModel project) {
    return projectTasks.where((item) {
      final sameProject = item.project.projectId == project.projectId;
      final sameTeam = item.project.teamId == project.teamId;
      return sameProject && sameTeam;
    }).toList();
  }

  int completedTasksForProject(ProjectModel project) {
    return tasksForProject(
      project,
    ).where((item) => item.task.isCompleted).length;
  }

  Color getStatusColor(BuildContext context, ProjectModel project) {
    switch (project.status) {
      case 'completed':
        return const Color(0xFF7C3AED);
      case 'in_progress':
        return const Color(0xFF22C55E);
      case 'on_hold':
        return const Color(0xFFF59E0B);
      case 'cancelled':
        return const Color(0xFFEF4444);
      case 'not_started':
        return const Color(0xFF3B82F6);
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  Color getProjectIconColor(ProjectModel project) {
    switch (project.status) {
      case 'completed':
        return const Color(0xFF7C3AED);
      case 'in_progress':
        return const Color(0xFF8B5CF6);
      case 'on_hold':
        return const Color(0xFFF59E0B);
      case 'cancelled':
        return const Color(0xFFEF4444);
      case 'not_started':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  double getProjectProgress(ProjectModel project) {
    final tasks = tasksForProject(project);

    if (tasks.isNotEmpty) {
      final completed = tasks.where((item) => item.task.isCompleted).length;
      return completed / tasks.length;
    }

    if (project.isCompleted) {
      return 1;
    }

    if (project.status == 'in_progress') {
      return 0.55;
    }

    if (project.status == 'on_hold') {
      return 0.35;
    }

    if (project.status == 'cancelled') {
      return 0;
    }

    return 0.12;
  }

  String getProjectProgressLabel(ProjectModel project) {
    final progress = getProjectProgress(project);
    return '${(progress * 100).round()}%';
  }

  String getProjectTaskLabel(ProjectModel project) {
    final tasks = tasksForProject(project);

    if (tasks.isEmpty) {
      return 'No tasks yet';
    }

    final completed = completedTasksForProject(project);
    return '$completed/${tasks.length} tasks done';
  }

  TaskListItem? nextTaskForProject(ProjectModel project) {
    final tasks =
        tasksForProject(
            project,
          ).where((item) => !item.task.isCompleted).toList()
          ..sort(compareUpcomingTaskItems);

    if (tasks.isEmpty) {
      return null;
    }

    return tasks.first;
  }

  String projectHealthLabel(ProjectModel project) {
    final tasks = tasksForProject(project);
    final hasBlockedTask = tasks.any((item) => item.task.isBlocked);
    final hasOverdueTask = tasks.any((item) => item.task.isOverdue);

    if (!project.isCompleted && project.daysLeft < 0) {
      return 'At risk';
    }

    if (hasBlockedTask) {
      return 'Blocked';
    }

    if (hasOverdueTask) {
      return 'Needs attention';
    }

    if (project.daysLeft <= 3 && !project.isCompleted) {
      return 'Due soon';
    }

    return 'Healthy';
  }

  void setProjectFilter(int index) {
    setState(() {
      selectedFilterIndex = index;
    });
  }

  Future<void> showProjectFilterSheet() async {
    final tabs = ['All', 'Active', 'Completed'];

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Filter projects',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                for (int index = 0; index < tabs.length; index++) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      selectedFilterIndex == index
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selectedFilterIndex == index
                          ? Theme.of(context).colorScheme.primary
                          : isDark
                          ? Colors.white70
                          : const Color(0xFF64748B),
                    ),
                    title: Text(
                      tabs[index],
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      setProjectFilter(index);
                    },
                  ),
                  if (index != tabs.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildProjectsHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        InkWell(
          onTap: widget.onBack,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              Icons.arrow_back_rounded,
              size: 28,
              color: isDark ? Colors.white : const Color(0xFF1E1B4B),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Plans',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF1E1B4B),
          ),
        ),
        const Spacer(),
        buildCircleIconButton(
          context,
          icon: Icons.search_rounded,
          onTap: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Search is next.')));
          },
        ),
        const SizedBox(width: 10),
        buildCircleIconButton(
          context,
          icon: Icons.tune_rounded,
          onTap: showProjectFilterSheet,
        ),
      ],
    );
  }

  Widget buildCircleIconButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF111827) : Colors.white,
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDark ? Colors.white70 : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget buildProjectTabsAndAction(BuildContext context) {
    return Row(
      children: [
        Expanded(child: buildProjectTabs(context)),
        const SizedBox(width: 12),
        buildNewProjectButton(context),
      ],
    );
  }

  Widget buildProjectTabs(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabs = ['All', 'Active', 'Completed'];

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = selectedFilterIndex == index;

          return Expanded(
            child: InkWell(
              onTap: () {
                setProjectFilter(index);
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withValues(
                          alpha: isDark ? 0.22 : 0.12,
                        )
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tabs[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : isDark
                        ? Colors.white70
                        : const Color(0xFF4B5563),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget buildNewProjectButton(BuildContext context) {
    return InkWell(
      onTap: showCreateProjectSheet,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 48,
        width: 142,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6D28D9).withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 6),
            Text(
              'New Plan',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildProjectStats(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: buildProjectStatCard(
            context,
            icon: Icons.folder_rounded,
            value: totalProjectsCount.toString(),
            label: 'Total Plans',
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: buildProjectStatCard(
            context,
            icon: Icons.bar_chart_rounded,
            value: activeProjectsCount.toString(),
            label: 'Active',
            color: const Color(0xFF22C55E),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: buildProjectStatCard(
            context,
            icon: Icons.check_circle_rounded,
            value: completedProjectsCount.toString(),
            label: 'Completed',
            color: const Color(0xFF7C3AED),
          ),
        ),
      ],
    );
  }

  Widget buildProjectStatCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildProjectContent(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return buildMessageState(
        context,
        icon: Icons.wifi_off_rounded,
        title: 'Could not load plans',
        message: errorMessage!,
        buttonText: 'Try Again',
        onPressed: loadProjects,
      );
    }

    final visibleProjects = filteredProjects;

    if (visibleProjects.isEmpty) {
      return buildMessageState(
        context,
        icon: Icons.folder_open_rounded,
        title: 'No plans yet',
        message:
            'Describe an idea or create a manual plan to start organizing it.',
        buttonText: 'Start Plan',
        onPressed: showCreateProjectSheet,
      );
    }

    return Column(
      children: [
        if (taskSummaryWarning != null) ...[
          buildTaskSummaryWarning(context),
          const SizedBox(height: 14),
        ],
        for (final project in visibleProjects) ...[
          buildProjectCard(context, project),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget buildTaskSummaryWarning(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFF59E0B),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              taskSummaryWarning!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white70 : const Color(0xFF92400E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMessageState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E1B4B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.white70 : const Color(0xFF4B5563),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(onPressed: onPressed, child: Text(buttonText)),
        ],
      ),
    );
  }

  Widget buildProjectCard(BuildContext context, ProjectModel project) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = getStatusColor(context, project);
    final iconColor = getProjectIconColor(project);
    final progress = getProjectProgress(project);
    final nextTask = nextTaskForProject(project);

    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProjectDetailScreen(project: project),
          ),
        );

        if (!mounted) {
          return;
        }

        loadProjects();
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    project.isTeamProject
                        ? Icons.groups_2_rounded
                        : Icons.folder_rounded,
                    color: iconColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E1B4B),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        nextTask == null
                            ? getProjectTaskLabel(project)
                            : 'Next: ${nextTask.task.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: isDark
                                  ? Colors.white60
                                  : const Color(0xFF64748B),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                buildStatusBadge(context, project, statusColor),
                const SizedBox(width: 8),
                Icon(
                  Icons.more_vert_rounded,
                  color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE5E7EB),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        project.isCompleted
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFF8B5CF6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  getProjectProgressLabel(project),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    project.deadlineLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                buildHealthChip(context, project),
                const SizedBox(width: 8),
                buildProjectTypeChip(context, project),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildStatusBadge(
    BuildContext context,
    ProjectModel project,
    Color statusColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        project.statusLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: statusColor,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget buildHealthChip(BuildContext context, ProjectModel project) {
    final label = projectHealthLabel(project);
    final color = switch (label) {
      'At risk' => const Color(0xFFEF4444),
      'Blocked' => const Color(0xFFF59E0B),
      'Needs attention' => const Color(0xFFF59E0B),
      'Due soon' => const Color(0xFF3B82F6),
      _ => const Color(0xFF22C55E),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget buildProjectTypeChip(BuildContext context, ProjectModel project) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: project.isTeamProject
            ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
            : const Color(0xFF64748B).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            project.isTeamProject
                ? Icons.groups_2_rounded
                : Icons.person_rounded,
            size: 12,
            color: project.isTeamProject
                ? const Color(0xFF8B5CF6)
                : isDark
                ? Colors.white60
                : const Color(0xFF64748B),
          ),
          const SizedBox(width: 4),
          Text(
            project.isTeamProject ? 'Team' : 'Personal',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 10,
              color: project.isTeamProject
                  ? const Color(0xFF8B5CF6)
                  : isDark
                  ? Colors.white60
                  : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> showCreateProjectSheet() async {
    resetCreateProjectForm();
    await loadTeamsForCreateSheet();

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;

        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF050816) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF475569)
                          : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.add_task_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start a Plan',
                            style: Theme.of(sheetContext).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Choose how Planora should create this project.',
                            style: Theme.of(sheetContext).textTheme.bodySmall
                                ?.copyWith(
                                  color: isDark
                                      ? Colors.white60
                                      : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                buildCreationModeCard(
                  sheetContext,
                  icon: Icons.edit_note_rounded,
                  title: 'Create Manually',
                  message: 'Build the project yourself and add tasks manually.',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    showManualCreateProjectSheet();
                  },
                ),
                const SizedBox(height: 12),
                buildCreationModeCard(
                  sheetContext,
                  icon: Icons.auto_awesome_rounded,
                  title: 'Generate with AI',
                  message:
                      'Describe your idea and Planora will create the plan, tasks, timeline, and risks.',
                  isPrimary: true,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    openAiProjectWizard();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildCreationModeCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isPrimary
              ? primary.withValues(alpha: isDark ? 0.22 : 0.10)
              : isDark
              ? const Color(0xFF0F172A)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPrimary
                ? primary.withValues(alpha: 0.42)
                : isDark
                ? const Color(0xFF1E293B)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isPrimary
                    ? primary
                    : primary.withValues(alpha: isDark ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: isPrimary ? Colors.white : primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.chevron_right_rounded, color: primary),
          ],
        ),
      ),
    );
  }

  Future<void> openAiProjectWizard() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AiProjectWizardScreen(onPlanCreated: loadProjects),
      ),
    );

    if (!mounted) {
      return;
    }

    loadProjects();
  }

  void resetCreateProjectForm() {
    titleController.clear();
    descriptionController.clear();

    setState(() {
      selectedDeadline = null;
      selectedProjectType = 'personal';
      isCreatingProject = false;
    });
  }

  Future<void> showManualCreateProjectSheet() async {
    resetCreateProjectForm();

    await loadTeamsForCreateSheet();

    if (!mounted) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.92,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF050816) : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(34),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 32,
                      offset: const Offset(0, -12),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF475569)
                                : const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => Navigator.of(sheetContext).pop(),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark
                                    ? const Color(0xFF111827)
                                    : const Color(0xFFF8FAFC),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF111827),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Create Manually',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF111827),
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Create the project shell now, then add tasks yourself.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white60
                                            : const Color(0xFF64748B),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      buildCreateFieldLabel(context, 'Title'),
                      const SizedBox(height: 8),
                      buildCreateProjectTextField(
                        context,
                        controller: titleController,
                        hintText: 'e.g. FYP Mobile App',
                        icon: Icons.folder_outlined,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 20),
                      buildCreateFieldLabel(context, 'Description (Optional)'),
                      const SizedBox(height: 8),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: descriptionController,
                        builder: (context, value, child) {
                          return buildCreateProjectTextField(
                            context,
                            controller: descriptionController,
                            hintText: 'Describe what this plan is for...',
                            icon: Icons.notes_rounded,
                            maxLines: 4,
                            maxLength: 500,
                            counterText: '${value.text.length}/500',
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      buildCreateFieldLabel(context, 'Plan Type'),
                      const SizedBox(height: 8),
                      buildProjectTypeSelector(
                        context,
                        setSheetState: setSheetState,
                      ),
                      if (selectedProjectType == 'team') ...[
                        const SizedBox(height: 14),
                        buildCreateFieldLabel(context, 'Team'),
                        const SizedBox(height: 8),
                        buildTeamSelectorCard(
                          context,
                          setSheetState: setSheetState,
                        ),
                      ],
                      const SizedBox(height: 20),

                      buildCreateFieldLabel(context, 'Deadline'),
                      const SizedBox(height: 8),
                      buildDeadlinePickerCard(
                        context,
                        onTap: () async {
                          final pickedDate = await pickDeadlineDate();

                          if (pickedDate == null) {
                            return;
                          }

                          setSheetState(() {
                            selectedDeadline = pickedDate;
                          });

                          setState(() {
                            selectedDeadline = pickedDate;
                          });
                        },
                      ),

                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton(
                          onPressed: isCreatingProject
                              ? null
                              : () async {
                                  await createProjectFromSheet(
                                    sheetContext: sheetContext,
                                    setSheetState: setSheetState,
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: isCreatingProject
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Create Plan',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget buildCreateFieldLabel(BuildContext context, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w900,
        color: isDark ? Colors.white : const Color(0xFF111827),
      ),
    );
  }

  Widget buildCreateProjectTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required int maxLines,
    int? maxLength,
    String? counterText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      textInputAction: maxLines == 1
          ? TextInputAction.next
          : TextInputAction.newline,
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF111827),
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        counterText: counterText,
        hintText: hintText,
        hintStyle: TextStyle(
          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Padding(
          padding: EdgeInsets.only(bottom: maxLines > 1 ? 58 : 0),
          child: Icon(icon, color: const Color(0xFF7C3AED)),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE5E7EB),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.4),
        ),
      ),
    );
  }

  Widget buildDeadlinePickerCard(
    BuildContext context, {
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded, color: Color(0xFF7C3AED)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedDeadline == null
                    ? 'Choose project deadline'
                    : formatDeadlineDate(selectedDeadline!),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selectedDeadline == null
                      ? isDark
                            ? Colors.white38
                            : const Color(0xFF94A3B8)
                      : isDark
                      ? Colors.white
                      : const Color(0xFF111827),
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildProjectTypeSelector(
    BuildContext context, {
    required StateSetter setSheetState,
  }) {
    return Row(
      children: [
        Expanded(
          child: buildProjectTypeOption(
            context,
            label: 'Personal',
            icon: Icons.person_outline_rounded,
            value: 'personal',
            setSheetState: setSheetState,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: buildProjectTypeOption(
            context,
            label: 'Team',
            icon: Icons.groups_2_outlined,
            value: 'team',
            setSheetState: setSheetState,
          ),
        ),
      ],
    );
  }

  Widget buildProjectTypeOption(
    BuildContext context, {
    required String label,
    required IconData icon,
    required String value,
    required StateSetter setSheetState,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = selectedProjectType == value;

    return InkWell(
      onTap: () {
        setSheetState(() {
          selectedProjectType = value;
        });
        setState(() {
          selectedProjectType = value;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF7C3AED).withValues(alpha: 0.12)
              : isDark
              ? const Color(0xFF0F172A)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF7C3AED)
                : isDark
                ? const Color(0xFF1E293B)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 19,
              color: isSelected
                  ? const Color(0xFF7C3AED)
                  : isDark
                  ? Colors.white70
                  : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? const Color(0xFF7C3AED)
                      : isDark
                      ? Colors.white70
                      : const Color(0xFF334155),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTeamSelectorCard(
    BuildContext context, {
    required StateSetter setSheetState,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isLoadingTeams) {
      return Container(
        height: 58,
        alignment: Alignment.center,
        decoration: buildCreateCardDecoration(context),
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }

    if (teams.isEmpty) {
      return InkWell(
        onTap: openTeamsFromProjectSheet,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: buildCreateCardDecoration(context),
          child: Row(
            children: [
              const Icon(Icons.group_add_outlined, color: Color(0xFF7C3AED)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Create or join a team before making a team project.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: buildCreateCardDecoration(context),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedTeamId,
          isExpanded: true,
          borderRadius: BorderRadius.circular(16),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDark ? Colors.white54 : const Color(0xFF64748B),
          ),
          items: [
            for (final team in teams)
              DropdownMenuItem<int>(
                value: team.teamId,
                child: Text(
                  team.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (teamId) {
            setSheetState(() {
              selectedTeamId = teamId;
            });
            setState(() {
              selectedTeamId = teamId;
            });
          },
        ),
      ),
    );
  }

  BoxDecoration buildCreateCardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BoxDecoration(
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE5E7EB),
      ),
    );
  }

  Future<void> openTeamsFromProjectSheet() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TeamsScreen()));

    if (!mounted) {
      return;
    }

    await loadTeamsForCreateSheet();
  }

  Future<DateTime?> pickDeadlineDate() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDeadline ?? now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );

    if (pickedDate == null) {
      return null;
    }

    return normalizeProjectDeadline(pickedDate);
  }

  DateTime normalizeProjectDeadline(DateTime pickedDate) {
    final now = DateTime.now();
    final noon = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      12,
    );

    if (noon.isAfter(now)) {
      return noon;
    }

    final endOfDay = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      23,
      59,
      59,
    );

    if (endOfDay.isAfter(now)) {
      return endOfDay;
    }

    return DateTime(now.year, now.month, now.day + 1, 12);
  }

  String formatDeadlineDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  Future<void> createProjectFromSheet({
    required BuildContext sheetContext,
    required StateSetter setSheetState,
  }) async {
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();

    if (title.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Project title must be at least 2 letters.'),
        ),
      );
      return;
    }

    if (selectedDeadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project deadline is required.')),
      );
      return;
    }

    if (selectedProjectType == 'team' && selectedTeamId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select or create a team first.')),
      );
      return;
    }

    setSheetState(() {
      isCreatingProject = true;
    });

    setState(() {
      isCreatingProject = true;
    });

    try {
      final request = ProjectCreateRequest(
        title: title,
        description: description.isEmpty ? null : description,
        deadline: selectedDeadline!,
      );

      if (selectedProjectType == 'team') {
        await _projectsApi.createTeamProject(
          teamId: selectedTeamId!,
          request: request,
        );
      } else {
        await _projectsApi.createProject(request);
      }

      if (!mounted) {
        return;
      }

      if (sheetContext.mounted) {
        Navigator.of(sheetContext).pop();
      }

      titleController.clear();
      descriptionController.clear();

      setState(() {
        selectedDeadline = null;
        isCreatingProject = false;
      });

      await loadProjects();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Plan created.')));
    } catch (error, stackTrace) {
      debugPrint('Project creation failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      if (sheetContext.mounted) {
        setSheetState(() {
          isCreatingProject = false;
        });
      }

      setState(() {
        isCreatingProject = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(projectCreationErrorMessage(error))),
      );
    }
  }

  String projectCreationErrorMessage(Object error) {
    if (error is ApiException) {
      final backendMessage = error.message.trim();

      if (selectedProjectType == 'team' && error.statusCode == 403) {
        const permissionMessage =
            'You can only create team projects in teams where you are owner/admin.';

        if (backendMessage.isNotEmpty &&
            backendMessage != 'Something went wrong. Please try again.') {
          return '$permissionMessage $backendMessage';
        }

        return permissionMessage;
      }

      if (backendMessage.isNotEmpty) {
        return backendMessage;
      }
    }

    return 'Could not create project. Try again.';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: loadProjects,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            buildProjectsHeader(context),
            const SizedBox(height: 22),
            buildProjectTabsAndAction(context),
            const SizedBox(height: 18),
            buildProjectStats(context),
            const SizedBox(height: 20),
            buildProjectContent(context),
          ],
        ),
      ),
    );
  }
}
