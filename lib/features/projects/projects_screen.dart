import 'package:flutter/material.dart';

import '../ai/data/ai_plan_api.dart';
import '../auth/data/project_api.dart';
import '../auth/models/project_models.dart';
import '../tasks/data/tasks_api.dart';
import '../tasks/models/task_models.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends StatefulWidget {
  final VoidCallback onBack;

  const ProjectsScreen({super.key, required this.onBack});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final ProjectsApi _projectsApi = const ProjectsApi();
  final TasksApi _tasksApi = const TasksApi();
  final AiPlanApi _aiPlanApi = const AiPlanApi();

  int selectedFilterIndex = 0;
  int selectedProjectColorIndex = 0;

  bool isLoading = true;
  bool isCreatingProject = false;
  bool generateTasksWithAi = false;

  String? errorMessage;
  String? taskSummaryWarning;
  DateTime? selectedDeadline;

  List<ProjectModel> projects = [];
  List<TaskListItem> projectTasks = [];

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadProjects();
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
        errorMessage = 'Could not load projects. Please try again.';
        taskSummaryWarning = null;
        projectTasks = [];
        isLoading = false;
      });
    }
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
          'Projects',
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
          onTap: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Filters are next.')));
          },
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
                setState(() {
                  selectedFilterIndex = index;
                });
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
              'New Project',
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
            label: 'Total Projects',
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
        title: 'Could not load projects',
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
        title: 'No projects yet',
        message:
            'Create your first project and Planora will help you organize it.',
        buttonText: 'New Project',
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
                        getProjectTaskLabel(project),
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

  void showCreateProjectSheet() {
    titleController.clear();
    descriptionController.clear();

    setState(() {
      selectedDeadline = null;
      selectedProjectColorIndex = 0;
      generateTasksWithAi = false;
      isCreatingProject = false;
    });

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
                                  'New Project',
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
                                  'Create a new project to start organizing your work.',
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
                      buildCreateFieldLabel(context, 'Project Name'),
                      const SizedBox(height: 8),
                      buildCreateProjectTextField(
                        context,
                        controller: titleController,
                        hintText: 'e.g. Website Redesign',
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
                            hintText: 'Describe your project...',
                            icon: Icons.notes_rounded,
                            maxLines: 4,
                            maxLength: 200,
                            counterText: '${value.text.length}/200',
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      buildCreateFieldLabel(context, 'Team Members (Optional)'),
                      const SizedBox(height: 8),
                      buildTeamMembersInviteCard(context),

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

                      const SizedBox(height: 20),
                      buildCreateFieldLabel(context, 'Project Color'),
                      const SizedBox(height: 12),
                      buildProjectColorSelector(
                        context,
                        setSheetState: setSheetState,
                      ),
                      const SizedBox(height: 20),
                      buildCreateFieldLabel(context, 'AI Tasks'),
                      const SizedBox(height: 8),
                      buildAiTaskToggleCard(
                        context,
                        setSheetState: setSheetState,
                      ),
                      const SizedBox(height: 20),
                      buildCreateFieldLabel(context, 'Privacy'),
                      const SizedBox(height: 8),
                      buildPrivacyCard(context),
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
                                      'Create Project',
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

  Widget buildProjectColorSelector(
    BuildContext context, {
    required StateSetter setSheetState,
  }) {
    final colors = [
      const Color(0xFF6D28D9),
      const Color(0xFF60A5FA),
      const Color(0xFF5ECAC6),
      const Color(0xFF7ACB5A),
      const Color(0xFFF2AA3C),
      const Color(0xFFE75E5E),
      const Color(0xFFD957A7),
      const Color(0xFFA8ADBF),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(colors.length, (index) {
        final isSelected = selectedProjectColorIndex == index;
        final color = colors[index];

        return InkWell(
          onTap: () {
            setSheetState(() {
              selectedProjectColorIndex = index;
            });

            setState(() {
              selectedProjectColorIndex = index;
            });
          },
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
              ],
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                : null,
          ),
        );
      }),
    );
  }

  Widget buildAiTaskToggleCard(
    BuildContext context, {
    required StateSetter setSheetState,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: Color(0xFF7C3AED),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generate project tasks',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Adds an initial task plan after creation',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: generateTasksWithAi,
            activeThumbColor: const Color(0xFF7C3AED),
            onChanged: isCreatingProject
                ? null
                : (value) {
                    setSheetState(() {
                      generateTasksWithAi = value;
                    });
                    setState(() {
                      generateTasksWithAi = value;
                    });
                  },
          ),
        ],
      ),
    );
  }

  Widget buildPrivacyCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: 60,
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
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: Color(0xFF7C3AED),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Private',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Only you can access this project',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDark ? Colors.white54 : const Color(0xFF64748B),
          ),
        ],
      ),
    );
  }

  Future<DateTime?> pickDeadlineDate() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDeadline ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );

    return pickedDate;
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

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project title is required.')),
      );
      return;
    }

    if (selectedDeadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project deadline is required.')),
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
      final shouldGenerateTasks = generateTasksWithAi;
      final createdProject = await _projectsApi.createProject(
        ProjectCreateRequest(
          title: title,
          description: description.isEmpty ? null : description,
          deadline: selectedDeadline!,
        ),
      );
      var generatedTaskCount = 0;
      var aiGenerationFailed = false;

      if (shouldGenerateTasks) {
        try {
          final aiPlan = await _aiPlanApi.generatePlan(
            project: createdProject,
            prompt: description.isEmpty
                ? 'Create a practical task plan for $title.'
                : 'Create a practical task plan for $title. Context: $description',
            generateTasks: true,
            overwriteExistingTasks: false,
            preferredTaskCount: 8,
          );

          generatedTaskCount = aiPlan.tasksCreated;
        } catch (error, stackTrace) {
          debugPrint(
            'AI task generation after project creation failed: $error',
          );
          debugPrintStack(stackTrace: stackTrace);
          aiGenerationFailed = true;
        }
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
        generateTasksWithAi = false;
        isCreatingProject = false;
      });

      await loadProjects();

      if (!mounted) {
        return;
      }

      final snackBarMessage = aiGenerationFailed
          ? 'Project created, but AI tasks could not be generated.'
          : shouldGenerateTasks
          ? 'Project created with $generatedTaskCount AI tasks.'
          : 'Project created successfully.';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(snackBarMessage)));
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
        const SnackBar(content: Text('Could not create project. Try again.')),
      );
    }
  }

  Widget buildTeamMembersInviteCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invite members flow is next.')),
              );
            },
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7C3AED).withValues(alpha: 0.10),
                border: Border.all(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                ),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Color(0xFF7C3AED),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No members invited yet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invite members flow is next.')),
              );
            },
            child: const Text(
              'Invite Members',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF7C3AED),
              ),
            ),
          ),
        ],
      ),
    );
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
