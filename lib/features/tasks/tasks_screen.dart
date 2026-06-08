import 'package:flutter/material.dart';

import '../../core/theme/planora_theme.dart';
import '../auth/data/project_api.dart';
import '../auth/models/project_models.dart';
import 'data/tasks_api.dart';
import 'models/task_models.dart';
import 'task_detail_screen.dart';

class TasksScreen extends StatefulWidget {
  final VoidCallback onBack;
  final int createRequestId;
  final bool openCreateOnStart;
  final String? profilePic;
  final String userInitials;
  final VoidCallback? onCreateRequestConsumed;
  final VoidCallback? onTasksChanged;
  final VoidCallback? onCreateAiPlan;
  final TasksApi tasksApi;
  final ProjectsApi projectsApi;

  const TasksScreen({
    super.key,
    required this.onBack,
    this.createRequestId = 0,
    this.openCreateOnStart = false,
    this.profilePic,
    this.userInitials = 'P',
    this.onCreateRequestConsumed,
    this.onTasksChanged,
    this.onCreateAiPlan,
    this.tasksApi = const TasksApi(),
    this.projectsApi = const ProjectsApi(),
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  late final TasksApi _tasksApi;
  late final ProjectsApi _projectsApi;
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  static const List<TaskStatus?> _filters = [
    null,
    TaskStatus.todo,
    TaskStatus.inProgress,
    TaskStatus.completed,
  ];

  int selectedFilterIndex = 0;
  int? selectedProjectId;
  int? selectedCreateProjectId;
  int? selectedAssignedUserId;
  int? completingTaskId;
  int? completionFeedbackTaskId;
  TaskSortOrder selectedSortOrder = TaskSortOrder.overdueFirst;

  bool isLoading = true;
  bool isCreatingTask = false;
  bool isLoadingAssignees = false;
  bool _openCreateAfterLoad = false;
  bool _isCreateSheetOpen = false;
  bool _hasInitializedProjectFilter = false;
  bool addAnotherTask = false;

  String? errorMessage;
  String searchQuery = '';
  DateTime? selectedDueDate;
  TaskPriority selectedPriority = TaskPriority.medium;

  List<TaskProjectSummary> projects = [];
  List<TaskListItem> tasks = [];
  List<ProjectMemberModel> createTaskMembers = [];

  TaskProjectSummary? get selectedCreateProject {
    final projectId = selectedCreateProjectId;

    if (projectId == null || projects.isEmpty) {
      return null;
    }

    return projects.firstWhere(
      (item) => item.projectId == projectId,
      orElse: () => projects.first,
    );
  }

  TaskProjectSummary? get selectedProject {
    final projectId = selectedProjectId;

    if (projectId == null || projects.isEmpty) {
      return null;
    }

    return projects.firstWhere(
      (item) => item.projectId == projectId,
      orElse: () => projects.first,
    );
  }

  @override
  void initState() {
    super.initState();
    _tasksApi = widget.tasksApi;
    _projectsApi = widget.projectsApi;

    if (widget.openCreateOnStart) {
      _openCreateAfterLoad = true;
    }

    loadTasks();
  }

  @override
  void didUpdateWidget(covariant TasksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.createRequestId != oldWidget.createRequestId &&
        widget.createRequestId > 0) {
      requestCreateTaskSheet();
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    searchController.dispose();
    super.dispose();
  }

  TaskStatus? get selectedStatus {
    return _filters[selectedFilterIndex];
  }

  List<TaskListItem> get filteredTasks {
    final status = selectedStatus;
    final scopedTasks = searchedTaskItems;

    if (status == null) {
      return sortedTaskItems(scopedTasks);
    }

    return sortedTaskItems(
      scopedTasks.where((item) => item.task.status == status).toList(),
    );
  }

  List<TaskListItem> get projectScopedTasks {
    final projectId = selectedProjectId;

    if (projectId == null) {
      return tasks;
    }

    return tasks.where((item) => item.project.projectId == projectId).toList();
  }

  List<TaskListItem> get searchedTaskItems {
    final query = searchQuery.trim().toLowerCase();
    final scopedTasks = projectScopedTasks;

    if (query.isEmpty) {
      return scopedTasks;
    }

    return scopedTasks.where((item) {
      final task = item.task;
      final searchableText = [
        task.title,
        task.description ?? '',
        item.project.title,
      ].join(' ').toLowerCase();

      return searchableText.contains(query);
    }).toList();
  }

  int get todoCount {
    return countByStatus(TaskStatus.todo);
  }

  int get inProgressCount {
    return countByStatus(TaskStatus.inProgress);
  }

  int get completedCount {
    return countByStatus(TaskStatus.completed);
  }

  int get overdueCount {
    return projectScopedTasks.where((item) => item.task.isOverdue).length;
  }

  int countByStatus(TaskStatus status) {
    return projectScopedTasks
        .where((item) => item.task.status == status)
        .length;
  }

  List<TaskListItem> sortedTaskItems(List<TaskListItem> items) {
    final sorted = [...items];

    sorted.sort((first, second) {
      final comparison = compareTaskItemsByDueDate(first, second);

      if (selectedSortOrder == TaskSortOrder.upcomingFirst) {
        return -comparison;
      }

      return comparison;
    });

    return sorted;
  }

  Future<void> loadTasks() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await _tasksApi.getTasks();

      if (!mounted) {
        return;
      }

      setState(() {
        projects = data.projects;
        tasks = data.tasks;
        selectedProjectId = _resolveSelectedProjectId(data.projects);
        selectedCreateProjectId = _resolveSelectedCreateProjectId(
          data.projects,
        );
        _hasInitializedProjectFilter = true;
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Task board load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        errorMessage = 'Could not load tasks. Please try again.';
        isLoading = false;
      });
    }

    if (!mounted) {
      return;
    }

    if (_openCreateAfterLoad && errorMessage == null) {
      _openCreateAfterLoad = false;
      scheduleCreateTaskSheet(consumeRequest: true);
    }
  }

  int? _resolveSelectedProjectId(List<TaskProjectSummary> loadedProjects) {
    if (loadedProjects.isEmpty) {
      return null;
    }

    if (!_hasInitializedProjectFilter) {
      return loadedProjects.first.projectId;
    }

    final currentProjectId = selectedProjectId;

    if (currentProjectId == null) {
      return null;
    }

    if (loadedProjects.any(
      (project) => project.projectId == currentProjectId,
    )) {
      return currentProjectId;
    }

    return loadedProjects.first.projectId;
  }

  int? _resolveSelectedCreateProjectId(
    List<TaskProjectSummary> loadedProjects,
  ) {
    if (loadedProjects.isEmpty) {
      return null;
    }

    final currentCreateProjectId = selectedCreateProjectId;

    if (currentCreateProjectId != null &&
        loadedProjects.any(
          (project) => project.projectId == currentCreateProjectId,
        )) {
      return currentCreateProjectId;
    }

    final currentFilterProjectId = selectedProjectId;

    if (currentFilterProjectId != null &&
        loadedProjects.any(
          (project) => project.projectId == currentFilterProjectId,
        )) {
      return currentFilterProjectId;
    }

    return loadedProjects.first.projectId;
  }

  Future<void> loadCreateTaskMembers({
    required StateSetter setSheetState,
    required BuildContext sheetContext,
    TaskProjectSummary? project,
  }) async {
    final selectedProject = project ?? selectedCreateProject;

    if (selectedProject == null || !selectedProject.isTeamProject) {
      setSheetState(() {
        createTaskMembers = [];
        selectedAssignedUserId = null;
        isLoadingAssignees = false;
      });
      setState(() {
        createTaskMembers = [];
        selectedAssignedUserId = null;
        isLoadingAssignees = false;
      });
      return;
    }

    final teamId = selectedProject.teamId;

    if (teamId == null) {
      return;
    }

    setSheetState(() {
      isLoadingAssignees = true;
      createTaskMembers = [];
      selectedAssignedUserId = null;
    });
    setState(() {
      isLoadingAssignees = true;
      createTaskMembers = [];
      selectedAssignedUserId = null;
    });

    try {
      final members = await _projectsApi.getProjectMembersByIds(
        teamId: teamId,
        projectId: selectedProject.projectId,
      );

      if (!mounted || !sheetContext.mounted) {
        return;
      }

      setSheetState(() {
        createTaskMembers = members;
        selectedAssignedUserId = members.isEmpty ? null : members.first.userId;
        isLoadingAssignees = false;
      });
      setState(() {
        createTaskMembers = members;
        selectedAssignedUserId = members.isEmpty ? null : members.first.userId;
        isLoadingAssignees = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Task assignee load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted || !sheetContext.mounted) {
        return;
      }

      setSheetState(() {
        createTaskMembers = [];
        selectedAssignedUserId = null;
        isLoadingAssignees = false;
      });
      setState(() {
        createTaskMembers = [];
        selectedAssignedUserId = null;
        isLoadingAssignees = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load project members.')),
      );
    }
  }

  Future<void> prepareCreateTaskMembersForSelectedProject() async {
    final selectedProject = selectedCreateProject;

    if (selectedProject == null || !selectedProject.isTeamProject) {
      setState(() {
        createTaskMembers = [];
        selectedAssignedUserId = null;
        isLoadingAssignees = false;
      });
      return;
    }

    final teamId = selectedProject.teamId;

    if (teamId == null) {
      return;
    }

    setState(() {
      isLoadingAssignees = true;
      createTaskMembers = [];
      selectedAssignedUserId = null;
    });

    try {
      final members = await _projectsApi.getProjectMembersByIds(
        teamId: teamId,
        projectId: selectedProject.projectId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        createTaskMembers = members;
        selectedAssignedUserId = members.isEmpty ? null : members.first.userId;
        isLoadingAssignees = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Initial task assignee load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        createTaskMembers = [];
        selectedAssignedUserId = null;
        isLoadingAssignees = false;
      });
    }
  }

  void requestCreateTaskSheet() {
    if (isLoading) {
      _openCreateAfterLoad = true;
      return;
    }

    scheduleCreateTaskSheet(consumeRequest: true);
  }

  void scheduleCreateTaskSheet({bool consumeRequest = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (consumeRequest) {
        widget.onCreateRequestConsumed?.call();
      }

      showCreateTaskSheet();
    });
  }

  Color mutedColor(BuildContext context) {
    return PlanoraTheme.isDark(context)
        ? PlanoraTheme.darkTextMuted
        : PlanoraTheme.textSecondary;
  }

  BoxDecoration cardDecoration(BuildContext context, {double radius = 20}) {
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

  Color statusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return PlanoraTheme.primaryPurple;
      case TaskStatus.inProgress:
        return PlanoraTheme.info;
      case TaskStatus.completed:
        return PlanoraTheme.success;
      case TaskStatus.blocked:
        return PlanoraTheme.textMuted;
    }
  }

  Color priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return PlanoraTheme.success;
      case TaskPriority.medium:
        return PlanoraTheme.info;
      case TaskPriority.high:
        return PlanoraTheme.secondaryPurple;
    }
  }

  Widget buildTasksHeader(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final profilePic = widget.profilePic;
    final hasProfilePic = profilePic != null && profilePic.trim().isNotEmpty;

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
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
                    widget.userInitials,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Tasks',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: isDark
                  ? PlanoraTheme.darkTextPrimary
                  : PlanoraTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        buildCircleIconButton(
          context,
          icon: Icons.tune_rounded,
          onTap: showTaskFilterSheet,
        ),
      ],
    );
  }

  Widget buildCircleIconButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = PlanoraTheme.isDark(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
          border: Border.all(
            color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
          ),
          boxShadow: PlanoraTheme.cardShadowFor(context),
        ),
        child: Icon(icon, size: 20, color: mutedColor(context)),
      ),
    );
  }

  Widget buildProjectSelector(BuildContext context) {
    if (isLoading) {
      return buildProjectSelectorSkeleton(context);
    }

    if (projects.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Choose Plan',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: mutedColor(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              selectedProjectId == null
                  ? '${tasks.length} total • $overdueCount overdue'
                  : '${projectScopedTasks.length} in plan • $overdueCount overdue',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              buildProjectChip(
                context,
                label: 'All Plans',
                count: tasks.length,
                icon: Icons.dashboard_customize_outlined,
                isSelected: selectedProjectId == null,
                onTap: () {
                  setState(() {
                    selectedProjectId = null;
                    _hasInitializedProjectFilter = true;
                  });
                },
              ),
              const SizedBox(width: 10),
              for (final project in projects) ...[
                buildProjectChip(
                  context,
                  label: project.title,
                  count: taskCountForProject(project.projectId),
                  icon: project.isTeamProject
                      ? Icons.groups_2_outlined
                      : Icons.folder_outlined,
                  isSelected: selectedProjectId == project.projectId,
                  onTap: () {
                    setState(() {
                      selectedProjectId = project.projectId;
                      selectedCreateProjectId = project.projectId;
                      _hasInitializedProjectFilter = true;
                    });
                  },
                ),
                if (project != projects.last) const SizedBox(width: 10),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget buildTaskSearchField(BuildContext context) {
    if (isLoading || projects.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = PlanoraTheme.isDark(context);

    return TextField(
      controller: searchController,
      onChanged: (value) {
        setState(() {
          searchQuery = value;
        });
      },
      textInputAction: TextInputAction.search,
      style: TextStyle(
        color: isDark ? PlanoraTheme.darkTextPrimary : PlanoraTheme.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: selectedProjectId == null
            ? 'Search tasks across all plans'
            : 'Search tasks in this plan',
        prefixIcon: Icon(
          Icons.search_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        suffixIcon: searchQuery.trim().isEmpty
            ? null
            : IconButton(
                onPressed: clearTaskSearch,
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: isDark ? const Color(0xFF121A2A) : PlanoraTheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.4,
          ),
        ),
      ),
    );
  }

  void clearTaskSearch() {
    searchController.clear();
    setState(() {
      searchQuery = '';
    });
  }

  int taskCountForProject(int projectId) {
    return tasks.where((item) => item.project.projectId == projectId).length;
  }

  Widget buildProjectChip(
    BuildContext context, {
    required String label,
    required int count,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = PlanoraTheme.isDark(context);
    final primary = Theme.of(context).colorScheme.primary;
    final foreground = isSelected
        ? Colors.white
        : isDark
        ? PlanoraTheme.darkTextPrimary
        : PlanoraTheme.textPrimary;
    final muted = isSelected ? Colors.white70 : mutedColor(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minWidth: 138, maxWidth: 220),
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          gradient: isSelected
              ? PlanoraTheme.primaryGradientFor(context)
              : null,
          color: isSelected
              ? null
              : isDark
              ? const Color(0xFF121A2A)
              : PlanoraTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : isDark
                ? PlanoraTheme.darkBorder.withValues(alpha: 0.72)
                : PlanoraTheme.border.withValues(alpha: 0.86),
          ),
          boxShadow: isSelected
              ? PlanoraTheme.floatingShadowFor(context)
              : PlanoraTheme.cardShadowFor(context),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.18)
                    : primary.withValues(alpha: isDark ? 0.18 : 0.09),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : primary,
                size: 16,
              ),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count ${count == 1 ? 'task' : 'tasks'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildProjectSelectorSkeleton(BuildContext context) {
    return _PlanoraShimmer(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          children: [
            for (var index = 0; index < 4; index++) ...[
              buildSkeletonBox(context, width: 142, height: 58, radius: 18),
              if (index != 3) const SizedBox(width: 10),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildTaskStatsFilterRow(BuildContext context) {
    if (isLoading) {
      return _PlanoraShimmer(
        child: Row(
          children: [
            for (var index = 0; index < 4; index++) ...[
              Expanded(
                child: buildSkeletonBox(context, height: 76, radius: 16),
              ),
              if (index != 3) const SizedBox(width: 9),
            ],
          ],
        ),
      );
    }

    if (projects.isEmpty) {
      return const SizedBox.shrink();
    }

    final stats = [
      _TaskStatData(
        value: projectScopedTasks.length.toString(),
        label: 'All Tasks',
        color: Theme.of(context).colorScheme.primary,
      ),
      _TaskStatData(
        value: todoCount.toString(),
        label: 'To Do',
        color: PlanoraTheme.primaryPurple,
      ),
      _TaskStatData(
        value: inProgressCount.toString(),
        label: 'In Progress',
        color: PlanoraTheme.info,
      ),
      _TaskStatData(
        value: completedCount.toString(),
        label: 'Done',
        color: PlanoraTheme.success,
      ),
    ];

    return Row(
      children: [
        for (var index = 0; index < stats.length; index++) ...[
          Expanded(
            child: buildTaskStatFilterCard(
              context,
              stat: stats[index],
              isSelected: selectedFilterIndex == index,
              onTap: () {
                setState(() {
                  selectedFilterIndex = index;
                });
              },
            ),
          ),
          if (index != stats.length - 1) const SizedBox(width: 9),
        ],
      ],
    );
  }

  Future<void> showTaskFilterSheet() async {
    final result = await showModalBottomSheet<_TaskFilterSheetResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (sheetContext) {
        final isDark = PlanoraTheme.isDark(sheetContext);

        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.78,
            ),
            child: Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF111827) : PlanoraTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
                ),
                boxShadow: PlanoraTheme.softCardShadowFor(sheetContext),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? PlanoraTheme.darkBorder
                            : PlanoraTheme.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Filter Tasks',
                            style: Theme.of(sheetContext).textTheme.titleMedium
                                ?.copyWith(
                                  color: isDark
                                      ? PlanoraTheme.darkTextPrimary
                                      : PlanoraTheme.textPrimary,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    buildFilterSheetSectionLabel(sheetContext, 'Status'),
                    const SizedBox(height: 8),
                    for (var index = 0; index < _filters.length; index++) ...[
                      buildTaskFilterOption(
                        sheetContext,
                        label: filterLabel(_filters[index]),
                        isSelected: selectedFilterIndex == index,
                        onTap: () => Navigator.of(
                          sheetContext,
                        ).pop(_TaskFilterSheetResult(filterIndex: index)),
                      ),
                      if (index != _filters.length - 1)
                        const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 18),
                    buildFilterSheetSectionLabel(sheetContext, 'Sort'),
                    const SizedBox(height: 8),
                    buildTaskFilterOption(
                      sheetContext,
                      label: 'Overdue first',
                      subtitle: 'Oldest due dates at the top',
                      isSelected:
                          selectedSortOrder == TaskSortOrder.overdueFirst,
                      onTap: () => Navigator.of(sheetContext).pop(
                        const _TaskFilterSheetResult(
                          sortOrder: TaskSortOrder.overdueFirst,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    buildTaskFilterOption(
                      sheetContext,
                      label: 'Upcoming first',
                      subtitle: 'Newest upcoming dates at the top',
                      isSelected:
                          selectedSortOrder == TaskSortOrder.upcomingFirst,
                      onTap: () => Navigator.of(sheetContext).pop(
                        const _TaskFilterSheetResult(
                          sortOrder: TaskSortOrder.upcomingFirst,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      final filterIndex = result.filterIndex;
      final sortOrder = result.sortOrder;

      if (filterIndex != null) {
        selectedFilterIndex = filterIndex;
      }

      if (sortOrder != null) {
        selectedSortOrder = sortOrder;
      }
    });
  }

  Widget buildFilterSheetSectionLabel(BuildContext context, String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: mutedColor(context),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget buildTaskFilterOption(
    BuildContext context, {
    required String label,
    String? subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = PlanoraTheme.isDark(context);
    final selectedColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withValues(alpha: isDark ? 0.18 : 0.10)
              : isDark
              ? PlanoraTheme.darkBackground
              : PlanoraTheme.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? selectedColor
                : isDark
                ? PlanoraTheme.darkBorder
                : PlanoraTheme.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? selectedColor
                          : isDark
                          ? PlanoraTheme.darkTextPrimary
                          : PlanoraTheme.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: mutedColor(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_rounded, color: selectedColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget buildCreateSheetSurface(
    BuildContext context, {
    required Widget child,
  }) {
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1120) : const Color(0xFFFBFAFF),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
        ),
        boxShadow: PlanoraTheme.softCardShadowFor(context),
      ),
      child: child,
    );
  }

  Widget buildTaskStatFilterCard(
    BuildContext context, {
    required _TaskStatData stat,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = PlanoraTheme.isDark(context);
    final labelColor = isSelected
        ? Colors.white
        : isDark
        ? PlanoraTheme.darkTextPrimary
        : PlanoraTheme.textPrimary;
    final countColor = isSelected ? Colors.white : stat.color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 76,
        padding: const EdgeInsets.fromLTRB(6, 12, 6, 9),
        decoration: BoxDecoration(
          gradient: isSelected
              ? PlanoraTheme.primaryGradientFor(context)
              : null,
          color: isSelected
              ? null
              : isDark
              ? PlanoraTheme.darkSurface
              : PlanoraTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : isDark
                ? PlanoraTheme.darkBorder.withValues(alpha: 0.52)
                : PlanoraTheme.border.withValues(alpha: 0.78),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.26 : 0.08),
              blurRadius: isDark ? 18 : 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    stat.value,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      color: countColor,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  stat.label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                    color: labelColor,
                    height: 1.12,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String filterLabel(TaskStatus? status) {
    if (status == null) {
      return 'All';
    }

    if (status == TaskStatus.completed) {
      return 'Done';
    }

    return status.label;
  }

  Widget buildTaskContent(BuildContext context) {
    if (isLoading) {
      return buildLoadingState(context);
    }

    if (errorMessage != null) {
      return buildMessageState(
        context,
        icon: Icons.wifi_off_rounded,
        title: 'Could not load tasks',
        message: errorMessage!,
        buttonText: 'Try Again',
        onPressed: loadTasks,
      );
    }

    if (projects.isEmpty) {
      final createAiPlan = widget.onCreateAiPlan;

      return buildMessageState(
        context,
        icon: Icons.auto_awesome_rounded,
        title: 'No projects yet',
        message:
            'Create your first AI plan so Planora can turn an idea into practical tasks.',
        buttonText: createAiPlan == null
            ? 'Try Again'
            : 'Create your first AI plan',
        onPressed: createAiPlan ?? loadTasks,
      );
    }

    final visibleTasks = filteredTasks;
    final hasSelectedProject = selectedProjectId != null;
    final hasSearchQuery = searchQuery.trim().isNotEmpty;

    if (visibleTasks.isEmpty) {
      return buildMessageState(
        context,
        icon: hasSearchQuery
            ? Icons.manage_search_rounded
            : Icons.check_box_outlined,
        title: hasSearchQuery
            ? 'No tasks matching search'
            : hasSelectedProject && selectedStatus == null
            ? 'No tasks for this project yet.'
            : selectedStatus == null
            ? 'No tasks yet'
            : 'No ${filterLabel(selectedStatus).toLowerCase()} tasks',
        message: hasSearchQuery
            ? 'Try a different title, detail, or plan name.'
            : hasSelectedProject
            ? 'Create a task here or switch plans to see other work.'
            : selectedStatus == null
            ? 'Choose a plan or create your first task across all plans.'
            : 'Try another status or create a task in one of your plans.',
        buttonText: hasSearchQuery ? 'Clear Search' : 'New Task',
        onPressed: hasSearchQuery ? clearTaskSearch : showCreateTaskSheet,
      );
    }

    return buildGroupedTasks(context, visibleTasks);
  }

  Widget buildLoadingState(BuildContext context) {
    return _PlanoraShimmer(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          children: [
            for (var index = 0; index < 5; index++) ...[
              buildTaskSkeletonCard(context),
              if (index != 4) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildTaskSkeletonCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: taskCardDecoration(context),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildSkeletonBox(context, width: 24, height: 24, radius: 999),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildSkeletonBox(context, height: 16, radius: 8),
                    const SizedBox(height: 10),
                    buildSkeletonBox(
                      context,
                      width: 180,
                      height: 10,
                      radius: 6,
                    ),
                    const SizedBox(height: 10),
                    buildSkeletonBox(
                      context,
                      width: 132,
                      height: 10,
                      radius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              buildSkeletonBox(context, width: 72, height: 26, radius: 10),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildSkeletonBox(
    BuildContext context, {
    double? width,
    required double height,
    required double radius,
  }) {
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : PlanoraTheme.border.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(radius),
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
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 34),
      padding: const EdgeInsets.all(22),
      decoration: cardDecoration(context, radius: 24),
      child: Column(
        children: [
          Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
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
          const SizedBox(height: 18),
          ElevatedButton(onPressed: onPressed, child: Text(buttonText)),
        ],
      ),
    );
  }

  Widget buildGroupedTasks(
    BuildContext context,
    List<TaskListItem> visibleTasks,
  ) {
    final sectionOrder = selectedSortOrder == TaskSortOrder.overdueFirst
        ? const [
            'Overdue',
            'Today',
            'Tomorrow',
            'Next Week',
            'Upcoming',
            'Later',
            'Completed',
          ]
        : const [
            'Today',
            'Tomorrow',
            'Next Week',
            'Upcoming',
            'Later',
            'Overdue',
            'Completed',
          ];
    final grouped = <String, List<TaskListItem>>{};

    for (final item in visibleTasks) {
      final key = sectionKeyForTask(item.task);
      grouped.putIfAbsent(key, () => []).add(item);
    }

    return Column(
      children: [
        for (final section in sectionOrder)
          if (grouped[section] != null) ...[
            buildTaskSection(context, section, grouped[section]!),
            const SizedBox(height: 18),
          ],
      ],
    );
  }

  String sectionKeyForTask(TaskModel task) {
    if (task.isCompleted) {
      return 'Completed';
    }

    if (task.isOverdue) {
      return 'Overdue';
    }

    final dueDate = task.dueDate;

    if (dueDate == null) {
      return 'Later';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final difference = dueDay.difference(today).inDays;

    if (difference == 0) {
      return 'Today';
    }

    if (difference == 1) {
      return 'Tomorrow';
    }

    if (difference > 1 && difference <= 7) {
      return 'Next Week';
    }

    return 'Upcoming';
  }

  Widget buildTaskSection(
    BuildContext context,
    String title,
    List<TaskListItem> sectionTasks,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              '${sectionTasks.length} ${sectionTasks.length == 1 ? 'task' : 'tasks'}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (var index = 0; index < sectionTasks.length; index++) ...[
          buildAnimatedTaskCard(context, sectionTasks[index], index),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget buildAnimatedTaskCard(
    BuildContext context,
    TaskListItem item,
    int index,
  ) {
    final cappedIndex = index.clamp(0, 5).toInt();
    final delay = Duration(milliseconds: 45 * cappedIndex);

    return TweenAnimationBuilder<double>(
      key: ValueKey(
        'task-card-${selectedProjectId ?? 'all'}-$selectedFilterIndex-${item.task.taskId}',
      ),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + delay.inMilliseconds),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final delayedValue = value <= 0 ? 0.0 : value;

        return Opacity(
          opacity: delayedValue,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - delayedValue)),
            child: child,
          ),
        );
      },
      child: buildTaskCard(context, item),
    );
  }

  Widget buildTaskCard(BuildContext context, TaskListItem item) {
    final isDark = PlanoraTheme.isDark(context);
    final task = item.task;
    final taskStatusColor = statusColor(task.status);
    final taskPriorityColor = priorityColor(task.priority);
    final isCompleting = completingTaskId == task.taskId;
    final showCompletionFeedback = completionFeedbackTaskId == task.taskId;

    return InkWell(
      onTap: () => openTaskDetail(item),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        decoration: taskCardDecoration(
          context,
          isCompletionFeedback: showCompletionFeedback,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: task.isCompleted || isCompleting
                  ? null
                  : () => markTaskCompleted(item),
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                width: 30,
                height: 30,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (showCompletionFeedback)
                      TweenAnimationBuilder<double>(
                        key: ValueKey('completion-pulse-${task.taskId}'),
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 720),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: 1 + (value * 0.75),
                            child: Opacity(opacity: 1 - value, child: child),
                          );
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: PlanoraTheme.success.withValues(alpha: 0.22),
                          ),
                        ),
                      ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: task.isCompleted
                            ? PlanoraTheme.success
                            : Colors.transparent,
                        border: Border.all(
                          color: task.isCompleted
                              ? PlanoraTheme.success
                              : mutedColor(context).withValues(alpha: 0.46),
                          width: 1.4,
                        ),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: isCompleting
                            ? const Padding(
                                key: ValueKey('completing'),
                                padding: EdgeInsets.all(5),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : task.isCompleted
                            ? const Icon(
                                Icons.check_rounded,
                                key: ValueKey('completed'),
                                size: 17,
                                color: Colors.white,
                              )
                            : const SizedBox.shrink(key: ValueKey('todo')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      color: task.isCompleted
                          ? mutedColor(context)
                          : isDark
                          ? PlanoraTheme.darkTextPrimary
                          : PlanoraTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      buildBadge(
                        context,
                        label: filterLabel(task.status),
                        color: taskStatusColor,
                        isSubtle: true,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.project.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: mutedColor(context),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: task.isOverdue
                            ? PlanoraTheme.error
                            : mutedColor(context),
                      ),
                      const SizedBox(width: 6),
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
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    buildBadge(
                      context,
                      label: task.priority.label,
                      color: taskPriorityColor,
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.more_horiz_rounded,
                      color: isDark ? Colors.white54 : PlanoraTheme.textMuted,
                      size: 21,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                buildTaskMembers(context, item),
              ],
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration taskCardDecoration(
    BuildContext context, {
    bool isCompletionFeedback = false,
  }) {
    final isDark = PlanoraTheme.isDark(context);

    return BoxDecoration(
      color: isDark ? const Color(0xFF121A2A) : PlanoraTheme.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: isCompletionFeedback
            ? PlanoraTheme.success.withValues(alpha: 0.62)
            : isDark
            ? Colors.white.withValues(alpha: 0.05)
            : PlanoraTheme.border.withValues(alpha: 0.72),
      ),
      boxShadow: [
        BoxShadow(
          color: isCompletionFeedback
              ? PlanoraTheme.success.withValues(alpha: isDark ? 0.24 : 0.16)
              : Colors.black.withValues(alpha: isDark ? 0.30 : 0.055),
          blurRadius: isCompletionFeedback ? 24 : 18,
          offset: const Offset(0, 9),
        ),
      ],
    );
  }

  Widget buildTaskMembers(BuildContext context, TaskListItem item) {
    final members = item.task.memberPreviews;

    if (members.isEmpty && !item.project.isTeamProject) {
      return const SizedBox.shrink();
    }

    if (members.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildMemberAvatar(context, null, placeholder: true),
          const SizedBox(width: 5),
          Text(
            'Unassigned',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: mutedColor(context),
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
    }

    final visibleMembers = members.take(3).toList();
    final extraCount = members.length - visibleMembers.length;
    final width = 22.0 + ((visibleMembers.length - 1) * 15.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: width,
          height: 24,
          child: Stack(
            children: [
              for (var index = 0; index < visibleMembers.length; index++)
                Positioned(
                  left: index * 15.0,
                  child: buildMemberAvatar(context, visibleMembers[index]),
                ),
            ],
          ),
        ),
        if (extraCount > 0) ...[
          const SizedBox(width: 5),
          Text(
            '+$extraCount',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: mutedColor(context),
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ],
    );
  }

  Widget buildMemberAvatar(
    BuildContext context,
    TaskMemberPreview? member, {
    bool placeholder = false,
  }) {
    final isDark = PlanoraTheme.isDark(context);
    final avatarUrl = member?.avatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.trim().isNotEmpty;
    final label = placeholder ? '?' : member?.initials ?? '?';

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? PlanoraTheme.darkSurfaceVariant
            : PlanoraTheme.lavenderSurface,
        border: Border.all(
          color: isDark ? PlanoraTheme.darkBackground : PlanoraTheme.surface,
          width: 1.6,
        ),
      ),
      child: CircleAvatar(
        backgroundColor: Colors.transparent,
        backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
        child: hasAvatar
            ? null
            : Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  color: isDark
                      ? PlanoraTheme.darkTextPrimary
                      : PlanoraTheme.primaryPurple,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }

  Widget buildBadge(
    BuildContext context, {
    required String label,
    required Color color,
    bool isSubtle = false,
  }) {
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      constraints: const BoxConstraints(maxWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark || isSubtle ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Future<void> openTaskDetail(TaskListItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => TaskDetailScreen(
          initialTask: item,
          onTaskChanged: () {
            loadTasks();
            widget.onTasksChanged?.call();
          },
        ),
      ),
    );
  }

  Future<void> markTaskCompleted(TaskListItem item) async {
    setState(() {
      completingTaskId = item.task.taskId;
    });

    try {
      final updatedTask = await _tasksApi.markTaskCompleted(
        project: item.project,
        taskId: item.task.taskId,
      );

      if (!mounted) {
        return;
      }

      replaceTask(updatedTask);
      setState(() {
        completionFeedbackTaskId = updatedTask.task.taskId;
      });
      widget.onTasksChanged?.call();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task marked completed.')));

      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (!mounted || completionFeedbackTaskId != updatedTask.task.taskId) {
          return;
        }

        setState(() {
          completionFeedbackTaskId = null;
        });
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not complete task. Try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          completingTaskId = null;
        });
      }
    }
  }

  void replaceTask(TaskListItem updatedTask) {
    setState(() {
      tasks =
          tasks
              .map(
                (item) => item.task.taskId == updatedTask.task.taskId
                    ? updatedTask
                    : item,
              )
              .toList()
            ..sort(compareTaskItemsByDueDate);
    });
  }

  Future<void> showCreateTaskSheet() async {
    if (_isCreateSheetOpen) {
      return;
    }

    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a project before adding tasks.')),
      );
      return;
    }

    selectedCreateProjectId = selectedProjectId ?? projects.first.projectId;
    await prepareCreateTaskMembersForSelectedProject();

    if (!mounted) {
      return;
    }

    _isCreateSheetOpen = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return FractionallySizedBox(
              heightFactor: 0.94,
              child: buildCreateSheetSurface(
                sheetContext,
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      18,
                      20,
                      MediaQuery.of(sheetContext).viewInsets.bottom + 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildCreateSheetHeader(sheetContext),
                        const SizedBox(height: 24),
                        buildCreateFieldLabel(sheetContext, 'Task Name'),
                        const SizedBox(height: 8),
                        buildTaskTextField(
                          sheetContext,
                          controller: titleController,
                          hintText: 'e.g. Design homepage wireframe',
                          icon: Icons.short_text_rounded,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 18),
                        buildCreateFieldLabel(sheetContext, 'Project'),
                        const SizedBox(height: 8),
                        buildProjectPicker(
                          sheetContext,
                          setSheetState: setSheetState,
                        ),
                        const SizedBox(height: 18),
                        buildCreateFieldLabel(sheetContext, 'Description'),
                        const SizedBox(height: 8),
                        buildTaskTextField(
                          sheetContext,
                          controller: descriptionController,
                          hintText: 'Add more details about this task...',
                          icon: Icons.format_align_left_rounded,
                          maxLines: 4,
                          maxLength: 500,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  buildCreateFieldLabel(
                                    sheetContext,
                                    'Priority',
                                  ),
                                  const SizedBox(height: 8),
                                  buildPrioritySelector(
                                    sheetContext,
                                    setSheetState: setSheetState,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  buildCreateFieldLabel(
                                    sheetContext,
                                    'Due Date',
                                  ),
                                  const SizedBox(height: 8),
                                  buildDueDatePicker(
                                    sheetContext,
                                    onTap: () async {
                                      final date = await pickTaskDate();

                                      if (date == null) {
                                        return;
                                      }

                                      setSheetState(() {
                                        selectedDueDate = date;
                                      });

                                      setState(() {
                                        selectedDueDate = date;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        buildCreateFieldLabel(
                          sheetContext,
                          'Assignee (Optional)',
                        ),
                        const SizedBox(height: 8),
                        buildAssigneeField(
                          sheetContext,
                          setSheetState: setSheetState,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            buildAddAnotherTaskToggle(
                              sheetContext,
                              setSheetState: setSheetState,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: buildCreateTaskButton(
                                sheetContext,
                                onPressed: isCreatingTask
                                    ? null
                                    : () => createTaskFromSheet(
                                        sheetContext: sheetContext,
                                        setSheetState: setSheetState,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    _isCreateSheetOpen = false;
  }

  Widget buildCreateSheetHeader(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: PlanoraTheme.primaryGradientFor(context),
            borderRadius: BorderRadius.circular(14),
            boxShadow: PlanoraTheme.floatingShadowFor(context),
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New Task',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: isDark
                      ? PlanoraTheme.darkTextPrimary
                      : PlanoraTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Create a new task and add it to your project.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: mutedColor(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : PlanoraTheme.surfaceVariant,
            ),
            child: Icon(Icons.close_rounded, color: mutedColor(context)),
          ),
        ),
      ],
    );
  }

  Widget buildCreateFieldLabel(BuildContext context, String label) {
    final isDark = PlanoraTheme.isDark(context);

    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: isDark ? PlanoraTheme.darkTextPrimary : PlanoraTheme.textPrimary,
      ),
    );
  }

  InputDecoration createInputDecoration(
    BuildContext context, {
    required String hintText,
    required IconData icon,
  }) {
    final isDark = PlanoraTheme.isDark(context);

    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
      filled: true,
      fillColor: createInputFillColor(context),
      hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: mutedColor(context),
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: createInputBorderColor(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: createInputBorderColor(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.4,
        ),
      ),
      counterStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: isDark ? PlanoraTheme.darkTextMuted : PlanoraTheme.textMuted,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Color createInputFillColor(BuildContext context) {
    return PlanoraTheme.isDark(context)
        ? const Color(0xFF111827)
        : PlanoraTheme.surface;
  }

  Color createInputBorderColor(BuildContext context) {
    return PlanoraTheme.isDark(context)
        ? PlanoraTheme.darkBorder
        : PlanoraTheme.lavenderBorder;
  }

  Widget buildProjectPicker(
    BuildContext context, {
    required StateSetter setSheetState,
  }) {
    final isDark = PlanoraTheme.isDark(context);

    return DropdownButtonFormField<int>(
      initialValue: selectedCreateProjectId,
      isExpanded: true,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: mutedColor(context)),
      dropdownColor: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
      decoration: createInputDecoration(
        context,
        hintText: 'Select a project',
        icon: Icons.folder_outlined,
      ),
      items: [
        for (final project in projects)
          DropdownMenuItem<int>(
            value: project.projectId,
            child: Text(
              project.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (value) {
        final nextProject = projects.firstWhere(
          (project) => project.projectId == value,
          orElse: () => projects.first,
        );

        setSheetState(() {
          selectedCreateProjectId = value;
        });

        setState(() {
          selectedCreateProjectId = value;
        });

        loadCreateTaskMembers(
          setSheetState: setSheetState,
          sheetContext: context,
          project: nextProject,
        );
      },
    );
  }

  Widget buildTaskTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required int maxLines,
    int? maxLength,
  }) {
    final isDark = PlanoraTheme.isDark(context);

    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      textInputAction: maxLines == 1
          ? TextInputAction.next
          : TextInputAction.newline,
      style: TextStyle(
        color: isDark ? PlanoraTheme.darkTextPrimary : PlanoraTheme.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      decoration: createInputDecoration(
        context,
        hintText: hintText,
        icon: icon,
      ),
    );
  }

  Widget buildPrioritySelector(
    BuildContext context, {
    required StateSetter setSheetState,
  }) {
    return PopupMenuButton<TaskPriority>(
      onSelected: (priority) {
        setSheetState(() {
          selectedPriority = priority;
        });

        setState(() {
          selectedPriority = priority;
        });
      },
      color: PlanoraTheme.isDark(context)
          ? PlanoraTheme.darkSurface
          : PlanoraTheme.surface,
      itemBuilder: (context) {
        return [
          for (final priority in TaskPriority.values)
            PopupMenuItem<TaskPriority>(
              value: priority,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: priorityColor(priority),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(priority.label),
                ],
              ),
            ),
        ];
      },
      child: buildCreateSelectButton(
        context,
        icon: Icons.circle,
        label: selectedPriority.label,
        dotColor: priorityColor(selectedPriority),
      ),
    );
  }

  Widget buildPriorityOption(
    BuildContext context, {
    required TaskPriority priority,
    required StateSetter setSheetState,
  }) {
    final isSelected = selectedPriority == priority;
    final color = priorityColor(priority);
    final isDark = PlanoraTheme.isDark(context);

    return InkWell(
      onTap: () {
        setSheetState(() {
          selectedPriority = priority;
        });

        setState(() {
          selectedPriority = priority;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.22 : 0.12)
              : isDark
              ? PlanoraTheme.darkBackground
              : PlanoraTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? color
                : isDark
                ? PlanoraTheme.darkBorder
                : PlanoraTheme.border,
          ),
        ),
        child: Text(
          priority.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: isSelected ? color : mutedColor(context),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget buildDueDatePicker(
    BuildContext context, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: buildCreateSelectButton(
        context,
        icon: Icons.calendar_today_outlined,
        label: selectedDueDate == null
            ? 'Select date'
            : formatInputDate(selectedDueDate!),
        isPlaceholder: selectedDueDate == null,
      ),
    );
  }

  Widget buildCreateSelectButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    Color? dotColor,
    bool isPlaceholder = false,
  }) {
    final isDark = PlanoraTheme.isDark(context);
    final textColor = isPlaceholder
        ? mutedColor(context)
        : isDark
        ? PlanoraTheme.darkTextPrimary
        : PlanoraTheme.textPrimary;

    return Container(
      width: double.infinity,
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: createInputFillColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: createInputBorderColor(context)),
      ),
      child: Row(
        children: [
          if (dotColor != null)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            )
          else
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Icon(Icons.keyboard_arrow_down_rounded, color: mutedColor(context)),
        ],
      ),
    );
  }

  Widget buildCreateStaticSelect(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return buildCreateSelectButton(
      context,
      icon: icon,
      label: label,
      isPlaceholder: true,
    );
  }

  Widget buildAssigneeField(
    BuildContext context, {
    required StateSetter setSheetState,
  }) {
    final selectedProject = selectedCreateProject;

    if (selectedProject?.isTeamProject != true) {
      return buildCreateInfoField(
        context,
        icon: Icons.person_outline_rounded,
        label: 'Assigned to me',
        helper: 'Personal tasks stay assigned to your account.',
      );
    }

    if (isLoadingAssignees) {
      return buildCreateInfoField(
        context,
        icon: Icons.sync_rounded,
        label: 'Loading members...',
        helper: 'Checking project members for assignment.',
      );
    }

    if (createTaskMembers.isEmpty) {
      return buildCreateInfoField(
        context,
        icon: Icons.group_off_outlined,
        label: 'No project members found.',
        helper: 'Invite members to this team project before assigning tasks.',
      );
    }

    return DropdownButtonFormField<int>(
      initialValue: selectedAssignedUserId,
      isExpanded: true,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: mutedColor(context)),
      decoration: createInputDecoration(
        context,
        hintText: 'Assign to a project member',
        icon: Icons.person_outline_rounded,
      ),
      items: [
        for (final member in createTaskMembers)
          DropdownMenuItem<int>(
            value: member.userId,
            child: Text(
              member.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (value) {
        setSheetState(() {
          selectedAssignedUserId = value;
        });
        setState(() {
          selectedAssignedUserId = value;
        });
      },
    );
  }

  Widget buildCreateInfoField(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String helper,
  }) {
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: mutedColor(context), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? PlanoraTheme.darkTextPrimary
                        : PlanoraTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  helper,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: mutedColor(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildAddAnotherTaskToggle(
    BuildContext context, {
    required StateSetter setSheetState,
  }) {
    final isDark = PlanoraTheme.isDark(context);

    return InkWell(
      onTap: () {
        final nextValue = !addAnotherTask;

        setSheetState(() {
          addAnotherTask = nextValue;
        });

        setState(() {
          addAnotherTask = nextValue;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: addAnotherTask
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: addAnotherTask
                    ? Theme.of(context).colorScheme.primary
                    : mutedColor(context).withValues(alpha: 0.45),
              ),
            ),
            child: addAnotherTask
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            'Add another task',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isDark
                  ? PlanoraTheme.darkTextPrimary
                  : PlanoraTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCreateTaskButton(
    BuildContext context, {
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(0, 50),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: PlanoraTheme.primaryGradientFor(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: isCreatingTask
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.3,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Create Task',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<DateTime?> pickTaskDate() async {
    final now = DateTime.now();

    return showDatePicker(
      context: context,
      initialDate: selectedDueDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
  }

  Future<void> createTaskFromSheet({
    required BuildContext sheetContext,
    required StateSetter setSheetState,
  }) async {
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    final projectId = selectedCreateProjectId;
    final scopeProjectIdBeforeCreate = selectedProjectId;

    if (title.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task name must be at least 2 letters.')),
      );
      return;
    }

    if (projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a project for this task.')),
      );
      return;
    }

    final project = projects.firstWhere(
      (item) => item.projectId == projectId,
      orElse: () => projects.first,
    );

    setSheetState(() {
      isCreatingTask = true;
    });

    setState(() {
      isCreatingTask = true;
    });

    try {
      await _tasksApi.createTask(
        request: TaskCreateRequest(
          projectId: project.projectId,
          title: title,
          description: description.isEmpty ? null : description,
          priority: selectedPriority,
          dueDate: selectedDueDate,
          assignedTo: project.isTeamProject ? selectedAssignedUserId : null,
        ),
        project: project,
      );

      if (!mounted || !sheetContext.mounted) {
        return;
      }

      setState(() {
        selectedProjectId = scopeProjectIdBeforeCreate;
        selectedCreateProjectId = project.projectId;
        _hasInitializedProjectFilter = true;
      });

      await loadTasks();
      widget.onTasksChanged?.call();

      if (!mounted || !sheetContext.mounted) {
        return;
      }

      setSheetState(() {
        isCreatingTask = false;
      });

      setState(() {
        isCreatingTask = false;
      });

      if (addAnotherTask) {
        resetCreateForm(keepProject: true);

        setSheetState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task created. Add another task.')),
        );
        return;
      }

      Navigator.of(sheetContext).pop();
      resetCreateForm();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task created successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setSheetState(() {
        isCreatingTask = false;
      });

      setState(() {
        isCreatingTask = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create task. Try again.')),
      );
    }
  }

  void resetCreateForm({bool keepProject = false}) {
    final projectId = selectedCreateProjectId;

    titleController.clear();
    descriptionController.clear();
    selectedDueDate = null;
    selectedPriority = TaskPriority.medium;
    selectedAssignedUserId = null;
    createTaskMembers = [];
    isLoadingAssignees = false;

    if (!keepProject) {
      selectedCreateProjectId =
          selectedProjectId ??
          (projects.isEmpty ? null : projects.first.projectId);
      addAnotherTask = false;
      return;
    }

    selectedCreateProjectId =
        projectId ?? (projects.isEmpty ? null : projects.first.projectId);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: loadTasks,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 112),
            child: Column(
              children: [
                buildTasksHeader(context),
                const SizedBox(height: 24),
                buildProjectSelector(context),
                const SizedBox(height: 14),
                buildTaskSearchField(context),
                const SizedBox(height: 18),
                buildTaskStatsFilterRow(context),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0, 0.025),
                      end: Offset.zero,
                    ).animate(animation);

                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(
                      'task-content-${isLoading ? 'loading' : 'ready'}-${selectedProjectId ?? 'all'}-$selectedFilterIndex-$selectedSortOrder-${tasks.length}',
                    ),
                    child: buildTaskContent(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 2,
          bottom: 26,
          child: FloatingActionButton(
            onPressed: showCreateTaskSheet,
            elevation: 0,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _TaskStatData {
  final String value;
  final String label;
  final Color color;

  const _TaskStatData({
    required this.value,
    required this.label,
    required this.color,
  });
}

enum TaskSortOrder { overdueFirst, upcomingFirst }

class _TaskFilterSheetResult {
  final int? filterIndex;
  final TaskSortOrder? sortOrder;

  const _TaskFilterSheetResult({this.filterIndex, this.sortOrder});
}

class _PlanoraShimmer extends StatefulWidget {
  final Widget child;

  const _PlanoraShimmer({required this.child});

  @override
  State<_PlanoraShimmer> createState() => _PlanoraShimmerState();
}

class _PlanoraShimmerState extends State<_PlanoraShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final base = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : PlanoraTheme.border.withValues(alpha: 0.72);
    final highlight = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.86);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final width = bounds.width;
            final shimmerWidth = width * 1.8;
            final dx = -shimmerWidth + (shimmerWidth * 2 * _controller.value);

            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, highlight, base],
              stops: const [0.32, 0.5, 0.68],
            ).createShader(Rect.fromLTWH(dx, 0, shimmerWidth, bounds.height));
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
