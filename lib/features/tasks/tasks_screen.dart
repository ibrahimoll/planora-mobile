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
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final searchController = TextEditingController();

  final filters = const <TaskStatus?>[
    null,
    TaskStatus.todo,
    TaskStatus.inProgress,
    TaskStatus.completed,
  ];

  List<TaskProjectSummary> projects = [];
  List<TaskListItem> tasks = [];
  int selectedFilterIndex = 0;
  int? selectedProjectId;
  int? selectedCreateProjectId;
  bool isLoading = true;
  bool isCreatingTask = false;
  bool isSearchVisible = false;
  String? errorMessage;
  String searchQuery = '';
  DateTime? selectedDueDate;
  TaskPriority selectedPriority = TaskPriority.medium;

  @override
  void initState() {
    super.initState();
    _tasksApi = widget.tasksApi;
    loadTasks().then((_) {
      if (widget.openCreateOnStart) scheduleCreateTaskSheet();
    });
  }

  @override
  void didUpdateWidget(covariant TasksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.createRequestId != oldWidget.createRequestId &&
        widget.createRequestId > 0) {
      scheduleCreateTaskSheet();
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

  List<TaskListItem> get visibleTasks {
    final query = searchQuery.trim().toLowerCase();
    final status = selectedStatus;
    final list = tasks.where((item) {
      if (selectedProjectId != null && item.project.projectId != selectedProjectId) {
        return false;
      }
      if (status != null && item.task.status != status) return false;
      if (query.isEmpty) return true;
      return [
        item.task.title,
        item.task.description ?? '',
        item.project.title,
        item.task.status.label,
        item.task.priority.label,
      ].join(' ').toLowerCase().contains(query);
    }).toList()
      ..sort(compareUpcomingTaskItems);
    return list;
  }

  int get todoCount => scopedTasks.where((item) => item.task.status == TaskStatus.todo).length;
  int get inProgressCount => scopedTasks.where((item) => item.task.status == TaskStatus.inProgress).length;
  int get doneCount => scopedTasks.where((item) => item.task.isCompleted).length;
  int get overdueCount => scopedTasks.where((item) => item.task.isOverdue).length;

  List<TaskListItem> get scopedTasks {
    if (selectedProjectId == null) return tasks;
    return tasks.where((item) => item.project.projectId == selectedProjectId).toList();
  }

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
        selectedProjectId = resolveProjectId(selectedProjectId);
        selectedCreateProjectId = resolveProjectId(selectedCreateProjectId ?? selectedProjectId);
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Task board load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        errorMessage = 'Could not load tasks. Try again.';
        isLoading = false;
      });
    }
  }

  int? resolveProjectId(int? currentId) {
    if (projects.isEmpty) return null;
    if (currentId != null && projects.any((item) => item.projectId == currentId)) {
      return currentId;
    }
    return projects.first.projectId;
  }

  void scheduleCreateTaskSheet() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onCreateRequestConsumed?.call();
      showCreateTaskSheet();
    });
  }

  void toggleSearch() {
    setState(() {
      isSearchVisible = !isSearchVisible;
      if (!isSearchVisible) {
        searchController.clear();
        searchQuery = '';
      }
    });
  }

  Future<void> showTaskFilterSheet() async {
    final labels = ['All tasks', 'To Do', 'In Progress', 'Completed'];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: PlanoraSpacing.sheetPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Filter tasks',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < labels.length; index++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    selectedFilterIndex == index
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selectedFilterIndex == index
                        ? Theme.of(context).colorScheme.primary
                        : mutedColor(context),
                  ),
                  title: Text(labels[index], style: const TextStyle(fontWeight: FontWeight.w900)),
                  onTap: () {
                    Navigator.of(context).pop();
                    setState(() => selectedFilterIndex = index);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> showCreateTaskSheet() async {
    titleController.clear();
    descriptionController.clear();
    selectedDueDate = null;
    selectedPriority = TaskPriority.medium;
    selectedCreateProjectId ??= selectedProjectId;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
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
                  const SizedBox(height: 16),
                  if (projects.isEmpty)
                    const PlanoraMessageState(
                      icon: Icons.folder_off_rounded,
                      title: 'No plans available',
                      message: 'Create a plan first, then add tasks inside it.',
                      topMargin: 0,
                    )
                  else ...[
                    DropdownButtonFormField<int>(
                      value: selectedCreateProjectId,
                      decoration: const InputDecoration(
                        labelText: 'Plan',
                        prefixIcon: Icon(Icons.folder_outlined),
                      ),
                      items: projects.map((project) {
                        return DropdownMenuItem<int>(
                          value: project.projectId,
                          child: Text(project.title),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setSheetState(() => selectedCreateProjectId = value);
                        setState(() => selectedCreateProjectId = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Task title',
                        prefixIcon: Icon(Icons.check_box_outlined),
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
                    Row(
                      children: TaskPriority.values.map((priority) {
                        final selected = selectedPriority == priority;
                        final color = priorityColor(priority);
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: InkWell(
                              onTap: () {
                                setSheetState(() => selectedPriority = priority);
                                setState(() => selectedPriority = priority);
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: selected ? color.withValues(alpha: .13) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: selected ? color : borderColor(context)),
                                ),
                                child: Center(
                                  child: Text(
                                    priority.label,
                                    style: TextStyle(
                                      color: selected ? color : null,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    PlanoraSecondaryButton(
                      icon: Icons.calendar_month_rounded,
                      label: selectedDueDate == null ? 'Choose due date' : formatInputDate(selectedDueDate!),
                      onPressed: () async {
                        final picked = await pickDueDate();
                        if (picked == null) return;
                        setSheetState(() => selectedDueDate = picked);
                        setState(() => selectedDueDate = picked);
                      },
                    ),
                    const SizedBox(height: 18),
                    PlanoraGradientButton(
                      label: 'Create Task',
                      icon: Icons.add_rounded,
                      isLoading: isCreatingTask,
                      onTap: () => createTaskFromSheet(sheetContext),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<DateTime?> pickDueDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDueDate ?? now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (pickedDate == null) return null;
    return DateTime(pickedDate.year, pickedDate.month, pickedDate.day, 12);
  }

  Future<void> createTaskFromSheet(BuildContext sheetContext) async {
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    final project = projects.where((item) => item.projectId == selectedCreateProjectId).cast<TaskProjectSummary?>().firstOrNull;

    if (project == null || title.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a plan and enter a task title.')),
      );
      return;
    }

    setState(() => isCreatingTask = true);
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
    } catch (error, stackTrace) {
      debugPrint('Task creation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => isCreatingTask = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create task.')),
      );
    }
  }

  Future<void> openTaskDetail(TaskListItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaskDetailScreen(initialTask: item, onTaskChanged: loadTasks),
      ),
    );
    if (!mounted) return;
    await loadTasks();
  }

  @override
  Widget build(BuildContext context) {
    return PlanoraPage(
      title: 'Tasks',
      subtitle: 'Track work, priorities, deadlines, and progress',
      onBack: widget.onBack,
      onRefresh: loadTasks,
      actions: [
        PlanoraIconButton(
          icon: isSearchVisible ? Icons.close_rounded : Icons.search_rounded,
          tooltip: isSearchVisible ? 'Close search' : 'Search tasks',
          onTap: toggleSearch,
        ),
        const SizedBox(width: 10),
        PlanoraIconButton(
          icon: Icons.tune_rounded,
          tooltip: 'Filter tasks',
          onTap: showTaskFilterSheet,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PlanoraAnimatedIn(
            index: 0,
            child: PlanoraHeroPromptCard(
              title: 'What task needs attention today?',
              description: 'Create a task, focus the next deadline, or generate an AI plan.',
              buttonText: widget.onCreateAiPlan == null ? 'Create Task' : 'Generate AI Plan',
              onButtonPressed: widget.onCreateAiPlan ?? showCreateTaskSheet,
              leadingIcon: Icons.task_alt_rounded,
              trailingIcon: Icons.add_task_rounded,
              badgeText: 'Focus',
            ),
          ),
          if (isSearchVisible) ...[
            const SizedBox(height: 14),
            PlanoraAnimatedIn(index: 1, child: buildSearchField()),
          ],
          const SizedBox(height: 18),
          PlanoraAnimatedIn(index: 2, child: buildPlanSelector()),
          const SizedBox(height: 18),
          PlanoraAnimatedIn(index: 3, child: buildStatsAndAction()),
          const SizedBox(height: 20),
          PlanoraAnimatedIn(index: 4, child: buildContent()),
        ],
      ),
    );
  }

  Widget buildSearchField() {
    return TextField(
      controller: searchController,
      onChanged: (value) => setState(() => searchQuery = value),
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

  Widget buildPlanSelector() {
    if (isLoading || projects.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          buildPlanChip('All Plans', tasks.length, Icons.dashboard_customize_outlined, selectedProjectId == null, () {
            setState(() => selectedProjectId = null);
          }),
          const SizedBox(width: 10),
          for (final project in projects) ...[
            buildPlanChip(
              project.title,
              tasks.where((item) => item.project.projectId == project.projectId).length,
              project.isTeamProject ? Icons.groups_2_outlined : Icons.folder_outlined,
              selectedProjectId == project.projectId,
              () => setState(() {
                selectedProjectId = project.projectId;
                selectedCreateProjectId = project.projectId;
              }),
            ),
            if (project != projects.last) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }

  Widget buildPlanChip(String label, int count, IconData icon, bool selected, VoidCallback onTap) {
    return PlanoraCard(
      onTap: onTap,
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      gradient: selected ? PlanoraTheme.primaryGradientFor(context) : null,
      border: Border.all(color: selected ? Colors.transparent : borderColor(context)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 112, maxWidth: 190),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? Colors.white : Theme.of(context).colorScheme.primary, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: selected ? Colors.white : null, fontWeight: FontWeight.w900)),
                  Text('$count tasks', style: TextStyle(color: selected ? Colors.white70 : mutedColor(context), fontWeight: FontWeight.w800, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildStatsAndAction() {
    if (isLoading || projects.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: stat('All', '${scopedTasks.length}', Icons.list_alt_rounded, Theme.of(context).colorScheme.primary)),
            const SizedBox(width: 9),
            Expanded(child: stat('Doing', '$inProgressCount', Icons.play_circle_rounded, PlanoraTheme.info)),
            const SizedBox(width: 9),
            Expanded(child: stat('Overdue', '$overdueCount', Icons.warning_rounded, PlanoraTheme.warning)),
          ],
        ),
        const SizedBox(height: 14),
        PlanoraGradientButton(icon: Icons.add_rounded, label: 'New Task', onTap: showCreateTaskSheet),
      ],
    );
  }

  Widget stat(String label, String value, IconData icon, Color color) {
    return PlanoraCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: mutedColor(context), fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget buildContent() {
    if (isLoading) return const PlanoraLoadingState(message: 'Loading tasks...');
    if (errorMessage != null) {
      return PlanoraMessageState(
        icon: Icons.wifi_off_rounded,
        title: 'Could not load tasks',
        message: errorMessage!,
        actionText: 'Try Again',
        onAction: loadTasks,
      );
    }
    if (projects.isEmpty) {
      return PlanoraMessageState(
        icon: Icons.folder_open_rounded,
        title: 'No plans yet',
        message: 'Create a plan first, then add tasks inside it.',
        actionText: widget.onCreateAiPlan == null ? null : 'Create AI Plan',
        onAction: widget.onCreateAiPlan,
      );
    }
    if (visibleTasks.isEmpty) {
      return PlanoraMessageState(
        icon: Icons.task_alt_rounded,
        title: 'No tasks found',
        message: 'Create a task or clear your current filter.',
        actionText: 'Create Task',
        onAction: showCreateTaskSheet,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("Today's Work", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        for (var index = 0; index < visibleTasks.length; index++) ...[
          PlanoraAnimatedIn(index: index, child: buildTaskCard(visibleTasks[index])),
          if (index != visibleTasks.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget buildTaskCard(TaskListItem item) {
    final task = item.task;
    final color = statusColor(task.status);
    return PlanoraCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      onTap: () => openTaskDetail(item),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: .12),
              border: Border.all(color: color),
            ),
            child: Icon(task.isCompleted ? Icons.check_rounded : Icons.radio_button_unchecked_rounded, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text('${item.project.title} • ${task.dueDateLabel}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: mutedColor(context), fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Row(children: [
                  tinyChip(task.status.label, color),
                  const SizedBox(width: 8),
                  tinyChip(task.priority.label, priorityColor(task.priority)),
                ]),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: mutedColor(context)),
        ],
      ),
    );
  }

  Widget tinyChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: .11), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10)),
    );
  }

  Color statusColor(TaskStatus status) => switch (status) {
        TaskStatus.todo => PlanoraTheme.primaryPurple,
        TaskStatus.inProgress => PlanoraTheme.info,
        TaskStatus.completed => PlanoraTheme.success,
        TaskStatus.blocked => PlanoraTheme.textMuted,
      };

  Color priorityColor(TaskPriority priority) => switch (priority) {
        TaskPriority.low => PlanoraTheme.success,
        TaskPriority.medium => PlanoraTheme.info,
        TaskPriority.high => PlanoraTheme.secondaryPurple,
      };

  Color borderColor(BuildContext context) =>
      PlanoraTheme.isDark(context) ? PlanoraTheme.darkBorder : PlanoraTheme.border;

  Color mutedColor(BuildContext context) => PlanoraTheme.isDark(context)
      ? PlanoraTheme.darkTextSecondary
      : PlanoraTheme.textSecondary;
}
