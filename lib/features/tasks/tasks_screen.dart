import 'package:flutter/material.dart';

import '../../core/theme/planora_theme.dart';
import '../../core/ui/planora_ui.dart';
import '../auth/data/project_api.dart';
import 'data/tasks_api.dart';
import 'models/task_models.dart';
import 'task_detail_screen.dart';
import '../ai/data/ai_plan_api.dart';
import '../auth/models/project_models.dart';

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
  final AiPlanApi aiPlanApi;

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
    this.aiPlanApi = const AiPlanApi(),
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  late final TasksApi _tasksApi;
  late final AiPlanApi _aiPlanApi;

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  static const List<TaskStatus?> filters = [
    null,
    TaskStatus.todo,
    TaskStatus.inProgress,
    TaskStatus.completed,
  ];

  int selectedFilterIndex = 0;
  int? selectedProjectId;
  int? selectedCreateProjectId;
  int? completingTaskId;

  bool isLoading = true;
  bool isSearchVisible = false;
  bool openCreateAfterLoad = false;
  bool isCreateSheetOpen = false;
  bool isShowingCachedData = false;

  String? errorMessage;
  String searchQuery = '';
  DateTime? selectedDueDate;

  TaskPriority selectedPriority = TaskPriority.medium;

  List<TaskProjectSummary> projects = [];
  List<TaskListItem> tasks = [];

  @override
  void initState() {
    super.initState();
    _tasksApi = widget.tasksApi;
    _aiPlanApi = widget.aiPlanApi;
    openCreateAfterLoad = widget.openCreateOnStart;
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

  TaskStatus? get selectedStatus => filters[selectedFilterIndex];

  List<TaskListItem> get projectScopedTasks {
    final id = selectedProjectId;
    if (id == null) return tasks;
    return tasks.where((item) => item.project.projectId == id).toList();
  }

  List<TaskListItem> get filteredTasks {
    final query = searchQuery.trim().toLowerCase();
    var result = projectScopedTasks;

    if (query.isNotEmpty) {
      result = result.where((item) {
        final task = item.task;
        final text = [
          task.title,
          task.description ?? '',
          task.status.label,
          task.priority.label,
          item.project.title,
        ].join(' ').toLowerCase();
        return text.contains(query);
      }).toList();
    }

    final status = selectedStatus;
    if (status != null) {
      result = result.where((item) => item.task.status == status).toList();
    }

    return [...result]..sort(compareTaskItemsByDueDate);
  }

  int get overdueCount =>
      projectScopedTasks.where((item) => item.task.isOverdue).length;

  Future<void> loadTasks() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await _tasksApi.getTasks();
      if (!mounted) return;
      setState(() {
        projects = data.projects;
        tasks = data.tasks;
        isShowingCachedData = data.isFromCache;
        if (selectedProjectId != null &&
            !data.projects.any(
              (project) => project.projectId == selectedProjectId,
            )) {
          selectedProjectId = null;
        }
        selectedCreateProjectId =
            selectedProjectId ??
            (data.projects.isEmpty ? null : data.projects.first.projectId);
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Task board load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      final cached = await _tasksApi.getCachedTasks();
      if (cached != null) {
        setState(() {
          projects = cached.projects;
          tasks = cached.tasks;
          isShowingCachedData = true;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Could not load tasks. Try again.';
          isLoading = false;
        });
      }
    }

    if (!mounted) return;
    if (openCreateAfterLoad && errorMessage == null) {
      openCreateAfterLoad = false;
      scheduleCreateTaskSheet(consumeRequest: true);
    }
  }

  void requestCreateTaskSheet() {
    if (isLoading) {
      openCreateAfterLoad = true;
      return;
    }
    scheduleCreateTaskSheet(consumeRequest: true);
  }

  void scheduleCreateTaskSheet({bool consumeRequest = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (consumeRequest) widget.onCreateRequestConsumed?.call();
      showCreateTaskSheet();
    });
  }

  Color mutedColor(BuildContext context) {
    return PlanoraTheme.isDark(context)
        ? PlanoraTheme.darkTextMuted
        : PlanoraTheme.textSecondary;
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

  String filterLabel(TaskStatus? status) {
    if (status == null) return 'All';
    if (status == TaskStatus.todo) return 'To Do';
    if (status == TaskStatus.inProgress) return 'Doing';
    return 'Done';
  }

  String selectedProjectTitle() {
    final id = selectedProjectId;
    if (id == null) return 'All plans';
    return projects
        .firstWhere(
          (project) => project.projectId == id,
          orElse: () => projects.first,
        )
        .title;
  }

  @override
  Widget build(BuildContext context) {
    return PlanoraPage(
      title: 'Tasks',
      subtitle: selectedProjectTitle(),
      onBack: widget.onBack,
      onRefresh: loadTasks,
      actions: [
        PlanoraIconButton(
          icon: isSearchVisible ? Icons.close_rounded : Icons.search_rounded,
          tooltip: isSearchVisible ? 'Close search' : 'Search tasks',
          onTap: () {
            setState(() {
              isSearchVisible = !isSearchVisible;
              if (!isSearchVisible) {
                searchController.clear();
                searchQuery = '';
              }
            });
          },
        ),
        const SizedBox(width: 10),
        PlanoraIconButton(
          icon: Icons.add_rounded,
          tooltip: 'New task',
          backgroundColor: Theme.of(context).colorScheme.primary,
          iconColor: Colors.white,
          onTap: requestCreateTaskSheet,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isSearchVisible) ...[
            PlanoraAnimatedIn(index: 0, child: buildTaskSearchField(context)),
            const SizedBox(height: PlanoraSpacing.md),
          ],
          PlanoraAnimatedIn(index: 1, child: buildProjectSelector(context)),
          const SizedBox(height: PlanoraSpacing.md),
          PlanoraAnimatedIn(index: 2, child: buildTaskFilterTabs(context)),
          const SizedBox(height: PlanoraSpacing.lg),
          PlanoraAnimatedIn(index: 3, child: buildTaskContent(context)),
        ],
      ),
    );
  }

  Widget buildTaskSearchField(BuildContext context) {
    return TextField(
      controller: searchController,
      autofocus: true,
      onChanged: (value) => setState(() => searchQuery = value),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search tasks...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: searchQuery.trim().isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  searchController.clear();
                  setState(() => searchQuery = '');
                },
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );
  }

  Widget buildProjectSelector(BuildContext context) {
    if (isLoading) return buildProjectSelectorSkeleton(context);
    if (projects.isEmpty) return const SizedBox.shrink();

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
              '${projectScopedTasks.length} tasks • $overdueCount overdue',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: PlanoraSpacing.sm),
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
                onTap: () => setState(() => selectedProjectId = null),
              ),
              const SizedBox(width: PlanoraSpacing.sm),
              for (final project in projects) ...[
                buildProjectChip(
                  context,
                  label: project.title,
                  count: tasks
                      .where(
                        (item) => item.project.projectId == project.projectId,
                      )
                      .length,
                  icon: project.isTeamProject
                      ? Icons.groups_2_outlined
                      : Icons.folder_outlined,
                  isSelected: selectedProjectId == project.projectId,
                  onTap: () {
                    setState(() {
                      selectedProjectId = project.projectId;
                      selectedCreateProjectId = project.projectId;
                    });
                  },
                ),
                if (project != projects.last)
                  const SizedBox(width: PlanoraSpacing.sm),
              ],
            ],
          ),
        ),
      ],
    );
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        constraints: const BoxConstraints(minWidth: 136, maxWidth: 220),
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          gradient: isSelected
              ? PlanoraTheme.primaryGradientFor(context)
              : null,
          color: isSelected
              ? null
              : (isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : isDark
                ? PlanoraTheme.darkBorder
                : PlanoraTheme.border,
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
                    ? Colors.white.withValues(alpha: .18)
                    : primary.withValues(alpha: .10),
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
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isSelected ? Colors.white70 : mutedColor(context),
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: List.generate(3, (index) {
          return Padding(
            padding: EdgeInsets.only(right: index == 2 ? 0 : PlanoraSpacing.sm),
            child: Container(
              width: 142,
              height: 58,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget buildTaskFilterTabs(BuildContext context) {
    return PlanoraSegmentedTabs(
      tabs: filters.map(filterLabel).toList(),
      selectedIndex: selectedFilterIndex,
      onChanged: (index) => setState(() => selectedFilterIndex = index),
    );
  }

  Widget buildTaskContent(BuildContext context) {
    if (isLoading) {
      return const PlanoraLoadingState(
        message: 'Loading tasks...',
        topPadding: 22,
      );
    }

    if (errorMessage != null) {
      return PlanoraMessageState(
        icon: Icons.wifi_off_rounded,
        title: 'Could not load tasks',
        message: errorMessage!,
        actionText: 'Try Again',
        onAction: loadTasks,
        topMargin: 10,
      );
    }

    if (projects.isEmpty) {
      return PlanoraMessageState(
        icon: Icons.folder_off_rounded,
        title: 'No plans yet',
        message: 'Create a plan first, then add tasks to it.',
        actionText: widget.onCreateAiPlan == null ? null : 'Plan with AI',
        onAction: widget.onCreateAiPlan,
        topMargin: 10,
      );
    }

    if (filteredTasks.isEmpty) {
      return PlanoraMessageState(
        icon: Icons.check_circle_outline_rounded,
        title: 'No tasks here',
        message: searchQuery.trim().isNotEmpty
            ? 'No task matches your search.'
            : 'Add a task or switch to another status.',
        actionText: 'New Task',
        onAction: showCreateTaskSheet,
        topMargin: 10,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                selectedFilterIndex == 0
                    ? 'Current Tasks'
                    : filterLabel(selectedStatus),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            if (isShowingCachedData)
              buildPill(
                context,
                label: 'Offline',
                icon: Icons.cloud_off_rounded,
                color: PlanoraTheme.warning,
              ),
          ],
        ),
        const SizedBox(height: PlanoraSpacing.md),
        for (var index = 0; index < filteredTasks.length; index++) ...[
          PlanoraAnimatedIn(
            index: index + 4,
            baseDurationMs: 260,
            delayMs: 22,
            child: buildTaskCard(context, filteredTasks[index]),
          ),
          if (index != filteredTasks.length - 1)
            const SizedBox(height: PlanoraSpacing.md),
        ],
      ],
    );
  }

  Widget buildTaskCard(BuildContext context, TaskListItem item) {
    final task = item.task;
    final color = statusColor(task.status);
    final progress = task.isCompleted
        ? 1.0
        : task.progressPercentage.clamp(0, 100) / 100;
    final isBusy = completingTaskId == task.taskId;

    return PlanoraCard(
      onTap: () => openTaskDetail(item),
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: isBusy
                    ? Padding(
                        padding: const EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: color,
                        ),
                      )
                    : Icon(taskIcon(task.status), color: color, size: 24),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      task.description?.trim().isNotEmpty == true
                          ? task.description!.trim()
                          : item.project.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: mutedColor(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              buildPill(
                context,
                label: task.status == TaskStatus.completed
                    ? 'Done'
                    : task.status.label,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.toDouble(),
              minHeight: 6,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .10),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              buildMetaChip(
                context,
                icon: Icons.calendar_today_outlined,
                label: task.dueDateLabel,
                color: task.isOverdue
                    ? PlanoraTheme.error
                    : mutedColor(context),
              ),
              buildMetaChip(
                context,
                icon: Icons.flag_rounded,
                label: task.priority.label,
                color: priorityColor(task.priority),
              ),
              buildMetaChip(
                context,
                icon: item.project.isTeamProject
                    ? Icons.groups_2_outlined
                    : Icons.person_outline_rounded,
                label: item.project.isTeamProject ? 'Team' : 'Personal',
                color: Theme.of(context).colorScheme.primary,
              ),
              if (!task.isCompleted)
                ActionChip(
                  avatar: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Done'),
                  onPressed: isBusy ? null : () => markTaskCompleted(item),
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData taskIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return Icons.radio_button_unchecked_rounded;
      case TaskStatus.inProgress:
        return Icons.pending_actions_rounded;
      case TaskStatus.completed:
        return Icons.check_circle_rounded;
      case TaskStatus.blocked:
        return Icons.block_rounded;
    }
  }

  Widget buildPill(
    BuildContext context, {
    required String label,
    IconData? icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMetaChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isDark = PlanoraTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: .04)
            : const Color(0xFFF8F5FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> showCreateTaskSheet() async {
    if (isCreateSheetOpen) {
      return;
    }

    if (projects.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Create a plan first.')));
      return;
    }

    isCreateSheetOpen = true;

    titleController.clear();
    descriptionController.clear();

    selectedPriority = TaskPriority.medium;
    selectedDueDate = null;
    selectedCreateProjectId = selectedProjectId ?? projects.first.projectId;

    var useAi = false;
    var isWorking = false;
    var aiPrompt = '';
    var aiTaskCount = 6;

    final resultMessage = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setSheetState) {
            final isDark = PlanoraTheme.isDark(modalContext);
            final primary = Theme.of(modalContext).colorScheme.primary;
            final bottomInset = MediaQuery.of(modalContext).viewInsets.bottom;

            TaskProjectSummary selectedSummary() {
              return projects.firstWhere(
                (project) => project.projectId == selectedCreateProjectId,
                orElse: () => projects.first,
              );
            }

            Future<void> createManualTask() async {
              if (isWorking) {
                return;
              }

              final title = titleController.text.trim();
              final description = descriptionController.text.trim();

              if (title.length < 2) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text('Task title must be at least 2 letters.'),
                  ),
                );
                return;
              }

              FocusManager.instance.primaryFocus?.unfocus();

              setSheetState(() {
                isWorking = true;
              });

              try {
                final project = selectedSummary();

                await _tasksApi.createTask(
                  project: project,
                  request: TaskCreateRequest(
                    projectId: project.projectId,
                    title: title,
                    description: description.isEmpty ? null : description,
                    priority: selectedPriority,
                    dueDate: selectedDueDate,
                  ),
                );

                if (!sheetContext.mounted) {
                  return;
                }

                Navigator.of(
                  sheetContext,
                ).pop('Task created in ${project.title}.');
              } catch (error, stackTrace) {
                debugPrint('Task creation failed: $error');
                debugPrintStack(stackTrace: stackTrace);

                if (!sheetContext.mounted) {
                  return;
                }

                setSheetState(() {
                  isWorking = false;
                });

                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(content: Text('Could not create task.')),
                );
              }
            }

            Future<void> generateAiTasks() async {
              if (isWorking) {
                return;
              }

              final projectSummary = selectedSummary();

              final prompt = aiPrompt.trim().isEmpty
                  ? 'Create a practical and detailed task list for '
                        '"${projectSummary.title}". Consider the project '
                        'goal, deadline, logical order, and important '
                        'deliverables.'
                  : aiPrompt.trim();

              FocusManager.instance.primaryFocus?.unfocus();

              setSheetState(() {
                isWorking = true;
              });

              try {
                final availableProjects = await widget.projectsApi
                    .getProjects();

                ProjectModel? selectedProject;

                for (final project in availableProjects) {
                  final sameProject =
                      project.projectId == projectSummary.projectId;

                  final sameTeam = project.teamId == projectSummary.teamId;

                  if (sameProject && sameTeam) {
                    selectedProject = project;
                    break;
                  }
                }

                if (selectedProject == null) {
                  throw StateError('The selected project could not be loaded.');
                }

                final response = await _aiPlanApi.generatePlan(
                  project: selectedProject,
                  prompt: prompt,
                  generateTasks: true,

                  // Existing tasks will not be deleted.
                  overwriteExistingTasks: false,

                  preferredTaskCount: aiTaskCount,
                  includeMilestones: false,
                );

                if (!sheetContext.mounted) {
                  return;
                }

                final created = response.tasksCreated;

                final message = created > 0
                    ? '$created AI-generated '
                          '${created == 1 ? 'task' : 'tasks'} added '
                          'to ${selectedProject.title}.'
                    : response.message.trim().isNotEmpty
                    ? response.message
                    : 'No new tasks were added.';

                Navigator.of(sheetContext).pop(message);
              } catch (error, stackTrace) {
                debugPrint('AI task generation failed: $error');
                debugPrintStack(stackTrace: stackTrace);

                if (!sheetContext.mounted) {
                  return;
                }

                setSheetState(() {
                  isWorking = false;
                });

                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Planora could not generate tasks right now.',
                    ),
                  ),
                );
              }
            }

            Widget modeButton({
              required bool aiMode,
              required IconData icon,
              required String label,
            }) {
              final selected = useAi == aiMode;

              return Expanded(
                child: InkWell(
                  onTap: isWorking
                      ? null
                      : () {
                          FocusManager.instance.primaryFocus?.unfocus();

                          setSheetState(() {
                            useAi = aiMode;
                          });
                        },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: selected
                          ? PlanoraTheme.primaryGradientFor(modalContext)
                          : null,
                      color: selected ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: selected
                          ? PlanoraTheme.floatingShadowFor(modalContext)
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          size: 18,
                          color: selected
                              ? Colors.white
                              : mutedColor(modalContext),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          label,
                          style: Theme.of(modalContext).textTheme.labelLarge
                              ?.copyWith(
                                color: selected
                                    ? Colors.white
                                    : mutedColor(modalContext),
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            Widget planDropdown() {
              return DropdownButtonFormField<int>(
                value: selectedCreateProjectId,
                isExpanded: true,
                menuMaxHeight: 360,
                decoration: InputDecoration(
                  labelText: 'Choose plan',
                  prefixIcon: const Icon(Icons.folder_outlined),
                  filled: true,
                  fillColor: isDark
                      ? PlanoraTheme.darkSurfaceVariant
                      : PlanoraTheme.surfaceVariant,
                ),
                selectedItemBuilder: (context) {
                  return projects.map((project) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        project.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    );
                  }).toList();
                },
                items: projects.map((project) {
                  return DropdownMenuItem<int>(
                    value: project.projectId,
                    child: Row(
                      children: [
                        Icon(
                          project.isTeamProject
                              ? Icons.groups_2_outlined
                              : Icons.folder_outlined,
                          size: 18,
                          color: primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            project.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: isWorking
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }

                        setSheetState(() {
                          selectedCreateProjectId = value;
                        });
                      },
              );
            }

            Widget priorityOption(TaskPriority priority) {
              final selected = selectedPriority == priority;
              final color = priorityColor(priority);

              return Expanded(
                child: InkWell(
                  onTap: isWorking
                      ? null
                      : () {
                          setSheetState(() {
                            selectedPriority = priority;
                          });
                        },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withValues(alpha: 0.14)
                          : isDark
                          ? PlanoraTheme.darkSurfaceVariant
                          : PlanoraTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? color
                            : isDark
                            ? PlanoraTheme.darkBorder
                            : PlanoraTheme.border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 19,
                          height: 19,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected ? color : Colors.transparent,
                            border: Border.all(
                              color: selected
                                  ? color
                                  : mutedColor(modalContext),
                            ),
                          ),
                          child: selected
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 13,
                                )
                              : null,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            priority.label,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(modalContext).textTheme.labelMedium
                                ?.copyWith(
                                  color: selected
                                      ? color
                                      : mutedColor(modalContext),
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return AnimatedPadding(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(modalContext).height * 0.92,
                ),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: isDark
                      ? PlanoraTheme.darkSurface
                      : PlanoraTheme.surface,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isDark
                        ? PlanoraTheme.darkBorder
                        : PlanoraTheme.border,
                  ),
                  boxShadow: PlanoraTheme.softCardShadowFor(modalContext),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 12, 14, 18),
                      decoration: BoxDecoration(
                        gradient: PlanoraTheme.primaryGradientFor(modalContext),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.48),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(17),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.18),
                                  ),
                                ),
                                child: Icon(
                                  useAi
                                      ? Icons.auto_awesome_rounded
                                      : Icons.add_task_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      useAi
                                          ? 'Generate with AI'
                                          : 'Create a task',
                                      style: Theme.of(modalContext)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      useAi
                                          ? 'Let Planora build a useful task list.'
                                          : 'Add a clear next step to your plan.',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(modalContext)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.76,
                                            ),
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: isWorking
                                    ? null
                                    : () {
                                        Navigator.of(sheetContext).pop();
                                      },
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.14,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? PlanoraTheme.darkSurfaceVariant
                                    : PlanoraTheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  modeButton(
                                    aiMode: false,
                                    icon: Icons.edit_note_rounded,
                                    label: 'Manual',
                                  ),
                                  const SizedBox(width: 4),
                                  modeButton(
                                    aiMode: true,
                                    icon: Icons.auto_awesome_rounded,
                                    label: 'AI Generate',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            planDropdown(),
                            const SizedBox(height: 16),

                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              child: useAi
                                  ? Column(
                                      key: const ValueKey('ai-task-mode'),
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                primary.withValues(
                                                  alpha: isDark ? 0.24 : 0.12,
                                                ),
                                                PlanoraTheme.secondaryPurple
                                                    .withValues(
                                                      alpha: isDark
                                                          ? 0.18
                                                          : 0.08,
                                                    ),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              22,
                                            ),
                                            border: Border.all(
                                              color: primary.withValues(
                                                alpha: 0.20,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 46,
                                                height: 46,
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      PlanoraTheme.primaryGradientFor(
                                                        modalContext,
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: const Icon(
                                                  Icons.psychology_alt_rounded,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(width: 13),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'AI task builder',
                                                      style:
                                                          Theme.of(modalContext)
                                                              .textTheme
                                                              .titleSmall
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                              ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      'Existing tasks stay safe. AI only adds useful new tasks.',
                                                      style:
                                                          Theme.of(modalContext)
                                                              .textTheme
                                                              .bodySmall
                                                              ?.copyWith(
                                                                color: mutedColor(
                                                                  modalContext,
                                                                ),
                                                                height: 1.35,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        TextFormField(
                                          initialValue: aiPrompt,
                                          enabled: !isWorking,
                                          minLines: 3,
                                          maxLines: 6,
                                          onChanged: (value) {
                                            aiPrompt = value;
                                          },
                                          decoration: const InputDecoration(
                                            labelText:
                                                'What should AI focus on?',
                                            hintText:
                                                'Example: Focus on setup, testing, deployment, and documentation.',
                                            alignLabelWithHint: true,
                                            prefixIcon: Padding(
                                              padding: EdgeInsets.only(
                                                bottom: 66,
                                              ),
                                              child: Icon(
                                                Icons.auto_awesome_rounded,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 17),
                                        Text(
                                          'Number of tasks',
                                          style: Theme.of(modalContext)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 9,
                                          runSpacing: 9,
                                          children: [4, 6, 8, 10].map((count) {
                                            final selected =
                                                aiTaskCount == count;

                                            return ChoiceChip(
                                              selected: selected,
                                              label: Text('$count tasks'),
                                              avatar: selected
                                                  ? const Icon(
                                                      Icons.check_rounded,
                                                      size: 16,
                                                    )
                                                  : null,
                                              onSelected: isWorking
                                                  ? null
                                                  : (_) {
                                                      setSheetState(() {
                                                        aiTaskCount = count;
                                                      });
                                                    },
                                            );
                                          }).toList(),
                                        ),
                                        const SizedBox(height: 22),
                                        PlanoraGradientButton(
                                          label: isWorking
                                              ? 'Planora is thinking...'
                                              : 'Generate $aiTaskCount tasks',
                                          icon: Icons.auto_awesome_rounded,
                                          isLoading: isWorking,
                                          onTap: isWorking
                                              ? null
                                              : generateAiTasks,
                                        ),
                                      ],
                                    )
                                  : Column(
                                      key: const ValueKey('manual-task-mode'),
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        TextField(
                                          controller: titleController,
                                          enabled: !isWorking,
                                          textInputAction: TextInputAction.next,
                                          decoration: const InputDecoration(
                                            labelText: 'Task title',
                                            hintText: 'What needs to be done?',
                                            prefixIcon: Icon(
                                              Icons.task_alt_rounded,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        TextField(
                                          controller: descriptionController,
                                          enabled: !isWorking,
                                          minLines: 3,
                                          maxLines: 5,
                                          decoration: const InputDecoration(
                                            labelText: 'Description',
                                            hintText:
                                                'Add useful details or instructions',
                                            alignLabelWithHint: true,
                                            prefixIcon: Padding(
                                              padding: EdgeInsets.only(
                                                bottom: 58,
                                              ),
                                              child: Icon(Icons.notes_rounded),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 17),
                                        Text(
                                          'Priority',
                                          style: Theme.of(modalContext)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            priorityOption(TaskPriority.low),
                                            const SizedBox(width: 8),
                                            priorityOption(TaskPriority.medium),
                                            const SizedBox(width: 8),
                                            priorityOption(TaskPriority.high),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        PlanoraSecondaryButton(
                                          icon: Icons.calendar_month_rounded,
                                          label: selectedDueDate == null
                                              ? 'Choose due date'
                                              : formatInputDate(
                                                  selectedDueDate!,
                                                ),
                                          onPressed: isWorking
                                              ? null
                                              : () async {
                                                  final picked =
                                                      await pickDueDate();

                                                  if (picked == null) {
                                                    return;
                                                  }

                                                  setSheetState(() {
                                                    selectedDueDate = picked;
                                                  });
                                                },
                                        ),
                                        const SizedBox(height: 22),
                                        PlanoraGradientButton(
                                          label: isWorking
                                              ? 'Creating task...'
                                              : 'Create Task',
                                          icon: Icons.add_rounded,
                                          isLoading: isWorking,
                                          onTap: isWorking
                                              ? null
                                              : createManualTask,
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
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

    isCreateSheetOpen = false;

    if (!mounted) {
      return;
    }

    if (resultMessage != null) {
      await Future<void>.delayed(const Duration(milliseconds: 320));

      if (!mounted) {
        return;
      }

      await loadTasks();
      widget.onTasksChanged?.call();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(resultMessage)));
    }
  }

  Future<DateTime?> pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDueDate ?? now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return null;
    return DateTime(picked.year, picked.month, picked.day, 12);
  }

  Future<void> openTaskDetail(TaskListItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaskDetailScreen(
          initialTask: item,
          onTaskChanged: () {
            loadTasks();
            widget.onTasksChanged?.call();
          },
        ),
      ),
    );
    if (!mounted) return;
    loadTasks();
  }

  Future<void> markTaskCompleted(TaskListItem item) async {
    if (item.task.isCompleted || completingTaskId != null) return;
    setState(() => completingTaskId = item.task.taskId);

    try {
      final updated = await _tasksApi.markTaskCompleted(
        project: item.project,
        taskId: item.task.taskId,
      );
      if (!mounted) return;
      setState(() {
        tasks = tasks
            .map(
              (taskItem) => taskItem.task.taskId == updated.task.taskId
                  ? updated
                  : taskItem,
            )
            .toList();
      });
      widget.onTasksChanged?.call();
    } catch (error, stackTrace) {
      debugPrint('Task completion failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not complete task.')));
    } finally {
      if (mounted) setState(() => completingTaskId = null);
    }
  }
}
