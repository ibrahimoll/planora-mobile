import 'package:flutter/material.dart';

import '../../core/theme/planora_theme.dart';
import 'data/tasks_api.dart';
import 'models/task_models.dart';
import 'task_detail_screen.dart';

class TasksScreen extends StatefulWidget {
  final VoidCallback onBack;
  final int createRequestId;
  final VoidCallback? onTasksChanged;

  const TasksScreen({
    super.key,
    required this.onBack,
    this.createRequestId = 0,
    this.onTasksChanged,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final TasksApi _tasksApi = const TasksApi();

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  static const List<TaskStatus?> _filters = [
    null,
    TaskStatus.todo,
    TaskStatus.inProgress,
    TaskStatus.completed,
    TaskStatus.blocked,
  ];

  int selectedFilterIndex = 0;
  int? selectedProjectId;
  int? completingTaskId;

  bool isLoading = true;
  bool isCreatingTask = false;
  bool _openCreateAfterLoad = false;
  bool _isCreateSheetOpen = false;

  String? errorMessage;
  DateTime? selectedDueDate;
  TaskPriority selectedPriority = TaskPriority.medium;

  List<TaskProjectSummary> projects = [];
  List<TaskListItem> tasks = [];

  @override
  void initState() {
    super.initState();

    if (widget.createRequestId > 0) {
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
    super.dispose();
  }

  TaskStatus? get selectedStatus {
    return _filters[selectedFilterIndex];
  }

  List<TaskListItem> get filteredTasks {
    final status = selectedStatus;

    if (status == null) {
      return tasks;
    }

    return tasks.where((item) => item.task.status == status).toList();
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

  int get blockedCount {
    return countByStatus(TaskStatus.blocked);
  }

  int countByStatus(TaskStatus status) {
    return tasks.where((item) => item.task.status == status).length;
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
        isLoading = false;
      });
    } catch (error) {
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
      scheduleCreateTaskSheet();
    }
  }

  int? _resolveSelectedProjectId(List<TaskProjectSummary> loadedProjects) {
    if (loadedProjects.isEmpty) {
      return null;
    }

    final currentProjectId = selectedProjectId;

    if (currentProjectId != null &&
        loadedProjects.any(
          (project) => project.projectId == currentProjectId,
        )) {
      return currentProjectId;
    }

    return loadedProjects.first.projectId;
  }

  void requestCreateTaskSheet() {
    if (isLoading) {
      _openCreateAfterLoad = true;
      return;
    }

    scheduleCreateTaskSheet();
  }

  void scheduleCreateTaskSheet() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
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
        return PlanoraTheme.info;
      case TaskStatus.inProgress:
        return PlanoraTheme.secondaryPurple;
      case TaskStatus.completed:
        return PlanoraTheme.success;
      case TaskStatus.blocked:
        return PlanoraTheme.warning;
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
              color: isDark
                  ? PlanoraTheme.darkTextPrimary
                  : PlanoraTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 10),
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
            ).showSnackBar(const SnackBar(content: Text('Filters are ready.')));
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

  Widget buildFilterTabs(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: cardDecoration(context, radius: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = selectedFilterIndex == index;
          final label = filter?.label ?? 'All';

          return InkWell(
            onTap: () {
              setState(() {
                selectedFilterIndex = index;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: filter == TaskStatus.inProgress ? 112 : 92,
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
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : mutedColor(context),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildTaskStats(BuildContext context) {
    final stats = [
      _TaskStatData(
        icon: Icons.checklist_rounded,
        value: tasks.length.toString(),
        label: 'All Tasks',
        color: Theme.of(context).colorScheme.primary,
      ),
      _TaskStatData(
        icon: Icons.radio_button_unchecked_rounded,
        value: todoCount.toString(),
        label: 'To Do',
        color: PlanoraTheme.info,
      ),
      _TaskStatData(
        icon: Icons.timelapse_rounded,
        value: inProgressCount.toString(),
        label: 'In Progress',
        color: PlanoraTheme.secondaryPurple,
      ),
      _TaskStatData(
        icon: Icons.check_circle_rounded,
        value: completedCount.toString(),
        label: 'Done',
        color: PlanoraTheme.success,
      ),
      _TaskStatData(
        icon: Icons.pause_circle_filled_rounded,
        value: blockedCount.toString(),
        label: 'Blocked',
        color: PlanoraTheme.warning,
      ),
    ];

    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stats.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final stat = stats[index];
          return buildTaskStatCard(context, stat);
        },
      ),
    );
  }

  Widget buildTaskStatCard(BuildContext context, _TaskStatData stat) {
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      width: 116,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: cardDecoration(context, radius: 18),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: stat.color.withValues(alpha: isDark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(stat.icon, color: stat.color, size: 19),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? PlanoraTheme.darkTextPrimary
                        : PlanoraTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stat.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
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
      return buildMessageState(
        context,
        icon: Icons.folder_open_rounded,
        title: 'No projects yet',
        message: 'Create a project first, then Planora can attach tasks to it.',
        buttonText: 'Refresh',
        onPressed: loadTasks,
      );
    }

    final visibleTasks = filteredTasks;

    if (visibleTasks.isEmpty) {
      return buildMessageState(
        context,
        icon: Icons.check_box_outlined,
        title: selectedStatus == null
            ? 'No tasks yet'
            : 'No ${selectedStatus!.label.toLowerCase()} tasks',
        message: selectedStatus == null
            ? 'Create your first task and connect it to a confirmed project.'
            : 'Try another status or create a new task for this project set.',
        buttonText: 'New Task',
        onPressed: showCreateTaskSheet,
      );
    }

    return buildGroupedTasks(context, visibleTasks);
  }

  Widget buildLoadingState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 34),
      child: Column(
        children: [
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 18),
          Text(
            'Loading tasks...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: mutedColor(context),
              fontWeight: FontWeight.w700,
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
    const sectionOrder = [
      'Overdue',
      'Today',
      'Tomorrow',
      'Upcoming',
      'No Due Date',
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
    if (task.isOverdue) {
      return 'Overdue';
    }

    final dueDate = task.dueDate;

    if (dueDate == null) {
      return 'No Due Date';
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
        for (final item in sectionTasks) ...[
          buildTaskCard(context, item),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget buildTaskCard(BuildContext context, TaskListItem item) {
    final isDark = PlanoraTheme.isDark(context);
    final task = item.task;
    final taskStatusColor = statusColor(task.status);
    final taskPriorityColor = priorityColor(task.priority);
    final isCompleting = completingTaskId == task.taskId;

    return InkWell(
      onTap: () => openTaskDetail(item),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: cardDecoration(context, radius: 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: task.isCompleted || isCompleting
                  ? null
                  : () => markTaskCompleted(item),
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26,
                height: 26,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: task.isCompleted
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: task.isCompleted
                        ? Theme.of(context).colorScheme.primary
                        : mutedColor(context).withValues(alpha: 0.55),
                    width: 1.4,
                  ),
                ),
                child: isCompleting
                    ? const Padding(
                        padding: EdgeInsets.all(5),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : task.isCompleted
                    ? const Icon(
                        Icons.check_rounded,
                        size: 17,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w900,
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
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: taskStatusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
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
                buildBadge(
                  context,
                  label: task.priority.label,
                  color: taskPriorityColor,
                ),
                const SizedBox(height: 8),
                buildBadge(
                  context,
                  label: task.status.label,
                  color: taskStatusColor,
                  isSubtle: true,
                ),
                const SizedBox(height: 8),
                Icon(
                  Icons.more_horiz_rounded,
                  color: isDark ? Colors.white38 : PlanoraTheme.textMuted,
                  size: 21,
                ),
              ],
            ),
          ],
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
      widget.onTasksChanged?.call();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task marked completed.')));
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
            ..sort(_compareTaskListItems);
    });
  }

  int _compareTaskListItems(TaskListItem first, TaskListItem second) {
    final firstDue = first.task.dueDate;
    final secondDue = second.task.dueDate;

    if (firstDue == null && secondDue != null) {
      return 1;
    }

    if (firstDue != null && secondDue == null) {
      return -1;
    }

    if (firstDue != null && secondDue != null) {
      final dueComparison = firstDue.compareTo(secondDue);

      if (dueComparison != 0) {
        return dueComparison;
      }
    }

    return second.task.createdAt.compareTo(first.task.createdAt);
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

    selectedProjectId ??= projects.first.projectId;
    _isCreateSheetOpen = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final isDark = PlanoraTheme.isDark(sheetContext);

            return FractionallySizedBox(
              heightFactor: 0.88,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? PlanoraTheme.darkSurface
                      : PlanoraTheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      22,
                      12,
                      22,
                      MediaQuery.of(sheetContext).viewInsets.bottom + 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? PlanoraTheme.darkBorder
                                  : PlanoraTheme.border,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                gradient: PlanoraTheme.primaryGradientFor(
                                  sheetContext,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.check_box_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'New Task',
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: isDark
                                          ? PlanoraTheme.darkTextPrimary
                                          : PlanoraTheme.textPrimary,
                                    ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        buildCreateFieldLabel(sheetContext, 'Project'),
                        const SizedBox(height: 8),
                        buildProjectPicker(
                          sheetContext,
                          setSheetState: setSheetState,
                        ),
                        const SizedBox(height: 18),
                        buildCreateFieldLabel(sheetContext, 'Task Name'),
                        const SizedBox(height: 8),
                        buildTaskTextField(
                          sheetContext,
                          controller: titleController,
                          hintText: 'e.g. Draft launch checklist',
                          icon: Icons.task_alt_rounded,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 18),
                        buildCreateFieldLabel(sheetContext, 'Description'),
                        const SizedBox(height: 8),
                        buildTaskTextField(
                          sheetContext,
                          controller: descriptionController,
                          hintText: 'Add useful context...',
                          icon: Icons.notes_rounded,
                          maxLines: 4,
                          maxLength: 500,
                        ),
                        const SizedBox(height: 18),
                        buildCreateFieldLabel(sheetContext, 'Priority'),
                        const SizedBox(height: 10),
                        buildPrioritySelector(
                          sheetContext,
                          setSheetState: setSheetState,
                        ),
                        const SizedBox(height: 18),
                        buildCreateFieldLabel(sheetContext, 'Due Date'),
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
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: isCreatingTask
                                ? null
                                : () => createTaskFromSheet(
                                    sheetContext: sheetContext,
                                    setSheetState: setSheetState,
                                  ),
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
                                gradient: PlanoraTheme.primaryGradientFor(
                                  sheetContext,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: isCreatingTask
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Create Task',
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
              ),
            );
          },
        );
      },
    );

    _isCreateSheetOpen = false;
  }

  Widget buildCreateFieldLabel(BuildContext context, String label) {
    final isDark = PlanoraTheme.isDark(context);

    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w900,
        color: isDark ? PlanoraTheme.darkTextPrimary : PlanoraTheme.textPrimary,
      ),
    );
  }

  Widget buildProjectPicker(
    BuildContext context, {
    required StateSetter setSheetState,
  }) {
    final isDark = PlanoraTheme.isDark(context);

    return DropdownButtonFormField<int>(
      initialValue: selectedProjectId,
      isExpanded: true,
      dropdownColor: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
      decoration: InputDecoration(
        prefixIcon: const Icon(
          Icons.folder_rounded,
          color: PlanoraTheme.secondaryPurple,
        ),
        filled: true,
        fillColor: isDark ? PlanoraTheme.darkBackground : PlanoraTheme.surface,
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
        setSheetState(() {
          selectedProjectId = value;
        });

        setState(() {
          selectedProjectId = value;
        });
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
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Padding(
          padding: EdgeInsets.only(bottom: maxLines > 1 ? 58 : 0),
          child: Icon(icon, color: PlanoraTheme.secondaryPurple),
        ),
        filled: true,
        fillColor: isDark ? PlanoraTheme.darkBackground : PlanoraTheme.surface,
      ),
    );
  }

  Widget buildPrioritySelector(
    BuildContext context, {
    required StateSetter setSheetState,
  }) {
    return Row(
      children: [
        for (final priority in TaskPriority.values) ...[
          Expanded(
            child: buildPriorityOption(
              context,
              priority: priority,
              setSheetState: setSheetState,
            ),
          ),
          if (priority != TaskPriority.values.last) const SizedBox(width: 8),
        ],
      ],
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
    final isDark = PlanoraTheme.isDark(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? PlanoraTheme.darkBackground : PlanoraTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              color: PlanoraTheme.secondaryPurple,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedDueDate == null
                    ? 'Choose due date'
                    : formatInputDate(selectedDueDate!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selectedDueDate == null
                      ? mutedColor(context)
                      : isDark
                      ? PlanoraTheme.darkTextPrimary
                      : PlanoraTheme.textPrimary,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: mutedColor(context)),
          ],
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
    final projectId = selectedProjectId;

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
        ),
        project: project,
      );

      if (!mounted || !sheetContext.mounted) {
        return;
      }

      Navigator.of(sheetContext).pop();
      resetCreateForm();

      setState(() {
        isCreatingTask = false;
      });

      await loadTasks();
      widget.onTasksChanged?.call();

      if (!mounted) {
        return;
      }

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

  void resetCreateForm() {
    titleController.clear();
    descriptionController.clear();
    selectedDueDate = null;
    selectedPriority = TaskPriority.medium;
    selectedProjectId = projects.isEmpty ? null : projects.first.projectId;
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
                const SizedBox(height: 22),
                buildFilterTabs(context),
                const SizedBox(height: 18),
                buildTaskStats(context),
                const SizedBox(height: 20),
                buildTaskContent(context),
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
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _TaskStatData({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
}
