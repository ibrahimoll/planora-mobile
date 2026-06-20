import 'package:flutter/material.dart';

import '../../core/theme/planora_theme.dart';
import '../../core/ui/planora_ui.dart';
import '../auth/data/project_api.dart';
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
  bool isCreatingTask = false;
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
    openCreateAfterLoad = widget.openCreateOnStart;
    loadTasks();
  }

  @override
  void didUpdateWidget(covariant TasksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.createRequestId != oldWidget.createRequestId && widget.createRequestId > 0) {
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

  int get overdueCount => projectScopedTasks.where((item) => item.task.isOverdue).length;

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
            !data.projects.any((project) => project.projectId == selectedProjectId)) {
          selectedProjectId = null;
        }
        selectedCreateProjectId = selectedProjectId ??
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
    return PlanoraTheme.isDark(context) ? PlanoraTheme.darkTextMuted : PlanoraTheme.textSecondary;
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
                  count: tasks.where((item) => item.project.projectId == project.projectId).length,
                  icon: project.isTeamProject ? Icons.groups_2_outlined : Icons.folder_outlined,
                  isSelected: selectedProjectId == project.projectId,
                  onTap: () {
                    setState(() {
                      selectedProjectId = project.projectId;
                      selectedCreateProjectId = project.projectId;
                    });
                  },
                ),
                if (project != projects.last) const SizedBox(width: PlanoraSpacing.sm),
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
          gradient: isSelected ? PlanoraTheme.primaryGradientFor(context) : null,
          color: isSelected ? null : (isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : isDark
                    ? PlanoraTheme.darkBorder
                    : PlanoraTheme.border,
          ),
          boxShadow: isSelected ? PlanoraTheme.floatingShadowFor(context) : PlanoraTheme.cardShadowFor(context),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.white.withValues(alpha: .18) : primary.withValues(alpha: .10),
              ),
              child: Icon(icon, color: isSelected ? Colors.white : primary, size: 16),
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
                color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
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
      return const PlanoraLoadingState(message: 'Loading tasks...', topPadding: 22);
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
        message: searchQuery.trim().isNotEmpty ? 'No task matches your search.' : 'Add a task or switch to another status.',
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
                selectedFilterIndex == 0 ? 'Current Tasks' : filterLabel(selectedStatus),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            if (isShowingCachedData)
              buildPill(context, label: 'Offline', icon: Icons.cloud_off_rounded, color: PlanoraTheme.warning),
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
          if (index != filteredTasks.length - 1) const SizedBox(height: PlanoraSpacing.md),
        ],
      ],
    );
  }

  Widget buildTaskCard(BuildContext context, TaskListItem item) {
    final task = item.task;
    final color = statusColor(task.status);
    final progress = task.isCompleted ? 1.0 : task.progressPercentage.clamp(0, 100) / 100;
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
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: color),
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
                      task.description?.trim().isNotEmpty == true ? task.description!.trim() : item.project.title,
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
              buildPill(context, label: task.status == TaskStatus.completed ? 'Done' : task.status.label, color: color),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.toDouble(),
              minHeight: 6,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: .10),
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
                color: task.isOverdue ? PlanoraTheme.error : mutedColor(context),
              ),
              buildMetaChip(context, icon: Icons.flag_rounded, label: task.priority.label, color: priorityColor(task.priority)),
              buildMetaChip(
                context,
                icon: item.project.isTeamProject ? Icons.groups_2_outlined : Icons.person_outline_rounded,
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

  Widget buildPill(BuildContext context, {required String label, IconData? icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
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

  Widget buildMetaChip(BuildContext context, {required IconData icon, required String label, required Color color}) {
    final isDark = PlanoraTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: .04) : const Color(0xFFF8F5FF),
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
    if (isCreateSheetOpen) return;
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create a plan first.')));
      return;
    }

    isCreateSheetOpen = true;
    titleController.clear();
    descriptionController.clear();
    selectedPriority = TaskPriority.medium;
    selectedDueDate = null;
    selectedCreateProjectId = selectedProjectId ?? projects.first.projectId;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SingleChildScrollView(
                padding: PlanoraSpacing.sheetPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create Task',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: PlanoraSpacing.md),
                    DropdownButtonFormField<int>(
                      value: selectedCreateProjectId,
                      decoration: const InputDecoration(labelText: 'Plan', prefixIcon: Icon(Icons.folder_outlined)),
                      items: projects
                          .map(
                            (project) => DropdownMenuItem<int>(
                              value: project.projectId,
                              child: Text(project.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: isCreatingTask
                          ? null
                          : (value) {
                              if (value == null) return;
                              setSheetState(() => selectedCreateProjectId = value);
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.task_alt_rounded)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(labelText: 'Description optional', prefixIcon: Icon(Icons.notes_rounded)),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: TaskPriority.values.map((priority) {
                        return ChoiceChip(
                          selected: selectedPriority == priority,
                          label: Text(priority.label),
                          onSelected: isCreatingTask
                              ? null
                              : (_) => setSheetState(() => selectedPriority = priority),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    PlanoraSecondaryButton(
                      icon: Icons.calendar_month_rounded,
                      label: selectedDueDate == null ? 'Choose due date' : formatInputDate(selectedDueDate!),
                      onPressed: isCreatingTask
                          ? null
                          : () async {
                              final picked = await pickDueDate();
                              if (picked == null) return;
                              setSheetState(() => selectedDueDate = picked);
                            },
                    ),
                    const SizedBox(height: 18),
                    PlanoraGradientButton(
                      label: 'Create Task',
                      icon: Icons.add_rounded,
                      isLoading: isCreatingTask,
                      onTap: () => createTaskFromSheet(sheetContext, setSheetState),
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
    if (mounted) setState(() => isCreatingTask = false);
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

  Future<void> createTaskFromSheet(BuildContext sheetContext, void Function(VoidCallback fn) setSheetState) async {
    final project = projects.firstWhere(
      (item) => item.projectId == selectedCreateProjectId,
      orElse: () => projects.first,
    );
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();

    if (title.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task title must be at least 2 letters.')));
      return;
    }

    setState(() => isCreatingTask = true);
    setSheetState(() {});

    try {
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
      if (!mounted) return;
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      setState(() => isCreatingTask = false);
      await loadTasks();
      widget.onTasksChanged?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task created.')));
    } catch (error, stackTrace) {
      debugPrint('Task creation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => isCreatingTask = false);
      setSheetState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not create task.')));
    }
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
        tasks = tasks.map((taskItem) => taskItem.task.taskId == updated.task.taskId ? updated : taskItem).toList();
      });
      widget.onTasksChanged?.call();
    } catch (error, stackTrace) {
      debugPrint('Task completion failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not complete task.')));
    } finally {
      if (mounted) setState(() => completingTaskId = null);
    }
  }
}
