import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../auth/data/project_api.dart';
import '../auth/models/project_models.dart';
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

  final TextEditingController searchController = TextEditingController();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  int selectedFilterIndex = 0;
  int handledCreateRequestId = 0;
  DateTime? selectedDeadline;

  bool isLoading = true;
  bool isSearchVisible = false;
  bool isCreatingProject = false;
  String? errorMessage;
  String? taskSummaryWarning;

  List<ProjectModel> projects = [];
  List<TaskListItem> projectTasks = [];
  final Set<String> deletingProjectKeys = <String>{};

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
    searchController.dispose();
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void scheduleCreateProjectSheet() {
    if (!widget.openCreateOnStart || widget.createRequestId == 0) return;
    if (handledCreateRequestId == widget.createRequestId) return;

    handledCreateRequestId = widget.createRequestId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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

  Future<void> loadProjects() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      taskSummaryWarning = null;
    });

    try {
      var loadedProjects = await _projectsApi.getProjects();
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
      loadedProjects = await synchronizeCompletedProjectStatuses(
        loadedProjects: loadedProjects,
        loadedTasks: loadedTasks,
      );

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
        projectTasks = [];
        isLoading = false;
      });
    }
  }

  Future<List<ProjectModel>> synchronizeCompletedProjectStatuses({
    required List<ProjectModel> loadedProjects,
    required List<TaskListItem> loadedTasks,
  }) async {
    final updatedProjects = List<ProjectModel>.from(loadedProjects);

    for (var index = 0; index < updatedProjects.length; index++) {
      final project = updatedProjects[index];
      final tasks = loadedTasks.where((item) {
        return item.project.projectId == project.projectId &&
            item.project.teamId == project.teamId;
      }).toList();

      if (tasks.isEmpty || project.isCompleted) continue;
      if (!tasks.every((item) => item.task.isCompleted)) continue;

      try {
        updatedProjects[index] = await _projectsApi.updateProjectStatus(
          project: project,
          status: 'completed',
        );
      } catch (error, stackTrace) {
        debugPrint(
          'Auto-complete project failed for project ${project.projectId}: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    return updatedProjects;
  }

  bool get hasActiveSearch => searchController.text.trim().isNotEmpty;

  List<ProjectModel> get filteredProjects {
    final query = searchController.text.trim().toLowerCase();

    return projects.where((project) {
      final matchesFilter = switch (selectedFilterIndex) {
        1 => project.isActive,
        2 => project.isCompleted,
        _ => true,
      };

      if (!matchesFilter) return false;
      if (query.isEmpty) return true;

      final nextTask = nextTaskForProject(project);
      final searchable = [
        project.title,
        project.description ?? '',
        project.statusLabel,
        project.projectTypeLabel,
        project.deadlineLabel,
        nextTask?.task.title ?? '',
      ].join(' ').toLowerCase();

      return searchable.contains(query);
    }).toList();
  }

  int get totalProjectsCount => projects.length;
  int get activeProjectsCount => projects.where((project) => project.isActive).length;
  int get completedProjectsCount =>
      projects.where((project) => project.isCompleted).length;

  String projectKey(ProjectModel project) {
    return '${project.projectType}-${project.teamId ?? 0}-${project.projectId}';
  }

  List<TaskListItem> tasksForProject(ProjectModel project) {
    return projectTasks.where((item) {
      return item.project.projectId == project.projectId &&
          item.project.teamId == project.teamId;
    }).toList();
  }

  int completedTasksForProject(ProjectModel project) {
    return tasksForProject(project).where((item) => item.task.isCompleted).length;
  }

  double getProjectProgress(ProjectModel project) {
    final tasks = tasksForProject(project);

    if (tasks.isNotEmpty) {
      return completedTasksForProject(project) / tasks.length;
    }

    if (project.isCompleted) return 1;
    if (project.status == 'in_progress') return 0.55;
    if (project.status == 'on_hold') return 0.35;
    if (project.status == 'cancelled') return 0;
    return 0.12;
  }

  String getProjectTaskLabel(ProjectModel project) {
    final tasks = tasksForProject(project);
    if (tasks.isEmpty) return 'No tasks yet';
    return '${completedTasksForProject(project)}/${tasks.length} tasks done';
  }

  TaskListItem? nextTaskForProject(ProjectModel project) {
    final tasks = tasksForProject(project)
        .where((item) => !item.task.isCompleted)
        .toList()
      ..sort(compareUpcomingTaskItems);

    if (tasks.isEmpty) return null;
    return tasks.first;
  }

  String projectHealthLabel(ProjectModel project) {
    final tasks = tasksForProject(project);

    if (!project.isCompleted && project.daysLeft < 0) return 'At risk';
    if (tasks.any((item) => item.task.isBlocked)) return 'Blocked';
    if (tasks.any((item) => item.task.isOverdue)) return 'Needs attention';
    if (project.daysLeft <= 3 && !project.isCompleted) return 'Due soon';
    return 'Healthy';
  }

  Color getStatusColor(ProjectModel project) {
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

  void setProjectFilter(int index) {
    setState(() {
      selectedFilterIndex = index;
    });
  }

  void toggleSearch() {
    setState(() {
      isSearchVisible = !isSearchVisible;
      if (!isSearchVisible) searchController.clear();
    });
  }

  void clearSearch() {
    setState(() {
      searchController.clear();
      isSearchVisible = false;
      selectedFilterIndex = 0;
    });
  }

  Future<bool> confirmDeleteProject(ProjectModel project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete plan?'),
          content: Text(
            'This will permanently delete "${project.title}" and its tasks. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  Future<void> deleteProjectFromList(ProjectModel project) async {
    final key = projectKey(project);
    if (deletingProjectKeys.contains(key)) return;

    final removedProject = project;
    final removedTasks = tasksForProject(project);

    setState(() {
      deletingProjectKeys.add(key);
      projects.removeWhere((item) => projectKey(item) == key);
      projectTasks.removeWhere((item) {
        return item.project.projectId == project.projectId &&
            item.project.teamId == project.teamId;
      });
    });

    try {
      await _projectsApi.deleteProject(project);

      if (!mounted) return;
      setState(() => deletingProjectKeys.remove(key));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Plan deleted.')));
    } on ApiException catch (error) {
      restoreDeletedProject(key, removedProject, removedTasks);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.statusCode == 403 || error.statusCode == 404
                ? 'You do not have permission to delete this plan.'
                : error.message,
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Project delete failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      restoreDeletedProject(key, removedProject, removedTasks);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete plan. Please try again.')),
      );
    }
  }

  void restoreDeletedProject(
    String key,
    ProjectModel removedProject,
    List<TaskListItem> removedTasks,
  ) {
    if (!mounted) return;
    setState(() {
      if (!projects.any((item) => projectKey(item) == key)) {
        projects.add(removedProject);
        projects.sort((first, second) {
          return second.createdAt.compareTo(first.createdAt);
        });
      }
      projectTasks.addAll(removedTasks);
      deletingProjectKeys.remove(key);
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
                  'Filter plans',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                for (var index = 0; index < tabs.length; index++) ...[
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

  Future<void> showCreateProjectSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Start a Plan',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                buildCreateModeTile(
                  sheetContext,
                  icon: Icons.edit_note_rounded,
                  title: 'Create Manually',
                  subtitle: 'Create a simple project shell yourself.',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    showManualCreateProjectSheet();
                  },
                ),
                const SizedBox(height: 10),
                buildCreateModeTile(
                  sheetContext,
                  icon: Icons.auto_awesome_rounded,
                  title: 'Generate with AI',
                  subtitle: 'Describe an idea and Planora creates the plan.',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    openAiProjectWizard();
                  },
                  primary: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildCreateModeTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    final color = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: primary
              ? color.withValues(alpha: 0.10)
              : isDark
              ? const Color(0xFF111827)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: primary ? color.withValues(alpha: 0.35) : borderColor(context),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: mutedColor(context))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
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

    if (!mounted) return;
    loadProjects();
  }

  Future<void> showManualCreateProjectSheet() async {
    titleController.clear();
    descriptionController.clear();
    selectedDeadline = null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create Plan',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        prefixIcon: Icon(Icons.folder_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Description optional',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await pickDeadlineDate();
                        if (picked == null) return;
                        setSheetState(() => selectedDeadline = picked);
                      },
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: Text(
                        selectedDeadline == null
                            ? 'Choose deadline'
                            : formatInputDate(selectedDeadline!),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isCreatingProject
                            ? null
                            : () => createProjectFromSheet(sheetContext),
                        child: isCreatingProject
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Create Plan'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<DateTime?> pickDeadlineDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDeadline ?? now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );

    if (pickedDate == null) return null;
    return DateTime(pickedDate.year, pickedDate.month, pickedDate.day, 12);
  }

  Future<void> createProjectFromSheet(BuildContext sheetContext) async {
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();

    if (title.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project title must be at least 2 letters.')),
      );
      return;
    }

    if (selectedDeadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project deadline is required.')),
      );
      return;
    }

    setState(() => isCreatingProject = true);

    try {
      await _projectsApi.createProject(
        ProjectCreateRequest(
          title: title,
          description: description.isEmpty ? null : description,
          deadline: selectedDeadline!,
        ),
      );

      if (!mounted) return;
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();

      setState(() => isCreatingProject = false);
      await loadProjects();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Plan created.')));
    } catch (error, stackTrace) {
      debugPrint('Project creation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => isCreatingProject = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException ? error.message : 'Could not create plan.',
          ),
        ),
      );
    }
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
            if (isSearchVisible) ...[
              const SizedBox(height: 12),
              buildProjectSearchField(context),
            ],
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
          icon: isSearchVisible ? Icons.close_rounded : Icons.search_rounded,
          onTap: toggleSearch,
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
          border: Border.all(color: borderColor(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: mutedColor(context)),
      ),
    );
  }

  Widget buildProjectSearchField(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: searchController,
      autofocus: true,
      onChanged: (_) => setState(() {}),
      textInputAction: TextInputAction.search,
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF111827),
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: 'Search plans...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: hasActiveSearch
            ? IconButton(
                onPressed: () => setState(searchController.clear),
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        filled: true,
        fillColor: isDark ? const Color(0xFF111827) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
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
        border: Border.all(color: borderColor(context)),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final selected = selectedFilterIndex == index;

          return Expanded(
            child: InkWell(
              onTap: () => setProjectFilter(index),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tabs[index],
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : mutedColor(context),
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
            colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 24),
            SizedBox(width: 6),
            Text(
              'New Plan',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
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
            value: '$totalProjectsCount',
            label: 'Total Plans',
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: buildProjectStatCard(
            context,
            icon: Icons.bar_chart_rounded,
            value: '$activeProjectsCount',
            label: 'Active',
            color: const Color(0xFF22C55E),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: buildProjectStatCard(
            context,
            icon: Icons.check_circle_rounded,
            value: '$completedProjectsCount',
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
      decoration: cardDecoration(context, 18),
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: mutedColor(context),
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
      if (projects.isNotEmpty && (hasActiveSearch || selectedFilterIndex != 0)) {
        return buildMessageState(
          context,
          icon: Icons.search_off_rounded,
          title: 'No matching plans',
          message: 'Try another search term or clear the current filter.',
          buttonText: 'Clear Search',
          onPressed: clearSearch,
        );
      }

      return buildMessageState(
        context,
        icon: Icons.folder_open_rounded,
        title: 'No plans yet',
        message: 'Describe an idea or create a manual plan to start organizing it.',
        buttonText: 'Start Plan',
        onPressed: showCreateProjectSheet,
      );
    }

    return Column(
      children: [
        if (taskSummaryWarning != null) ...[
          buildWarning(context, taskSummaryWarning!),
          const SizedBox(height: 14),
        ],
        for (final project in visibleProjects) ...[
          buildSwipeableProjectCard(context, project),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget buildSwipeableProjectCard(BuildContext context, ProjectModel project) {
    return Dismissible(
      key: ValueKey('plan-${projectKey(project)}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirmDeleteProject(project),
      onDismissed: (_) => deleteProjectFromList(project),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Delete',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
      child: buildProjectCard(context, project),
    );
  }

  Widget buildProjectCard(BuildContext context, ProjectModel project) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = getStatusColor(project);
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

        if (!mounted) return;
        loadProjects();
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration(context, 24),
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
                          color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        nextTask == null
                            ? getProjectTaskLabel(project)
                            : 'Next: ${nextTask.task.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: mutedColor(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                buildChip(context, project.statusLabel, statusColor),
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
                      backgroundColor:
                          isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
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
                  '${(progress * 100).round()}%',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: mutedColor(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: mutedColor(context)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    project.deadlineLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: mutedColor(context),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                buildHealthChip(context, project),
                const SizedBox(width: 8),
                buildTypeChip(context, project),
              ],
            ),
          ],
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

    return buildChip(context, label, color);
  }

  Widget buildTypeChip(BuildContext context, ProjectModel project) {
    return buildChip(
      context,
      project.isTeamProject ? 'Team' : 'Personal',
      project.isTeamProject ? const Color(0xFF8B5CF6) : const Color(0xFF64748B),
      icon: project.isTeamProject ? Icons.groups_2_rounded : Icons.person_rounded,
    );
  }

  Widget buildChip(BuildContext context, String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 10,
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
      decoration: cardDecoration(context, 24),
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
              color: mutedColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(onPressed: onPressed, child: Text(buttonText)),
        ],
      ),
    );
  }

  Widget buildWarning(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF92400E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration cardDecoration(BuildContext context, double radius) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BoxDecoration(
      color: isDark ? const Color(0xFF111827) : Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor(context)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.05),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Color borderColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB);
  }

  Color mutedColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white60 : const Color(0xFF64748B);
  }
}
