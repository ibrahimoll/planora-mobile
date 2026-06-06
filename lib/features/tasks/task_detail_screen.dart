import 'package:flutter/material.dart';

import '../../core/theme/planora_theme.dart';
import 'data/tasks_api.dart';
import 'models/task_models.dart';

class TaskDetailScreen extends StatefulWidget {
  final TaskListItem initialTask;
  final VoidCallback? onTaskChanged;

  const TaskDetailScreen({
    super.key,
    required this.initialTask,
    this.onTaskChanged,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final TasksApi _tasksApi = const TasksApi();

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  late TaskListItem taskItem;
  late TaskPriority editPriority;
  late TaskStatus editStatus;

  bool isRefreshing = false;
  bool isSaving = false;
  bool isCompleting = false;

  String? errorMessage;
  DateTime? editDueDate;

  @override
  void initState() {
    super.initState();
    taskItem = widget.initialTask;
    prepareEditForm();
    loadTaskDetails();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> loadTaskDetails() async {
    setState(() {
      isRefreshing = true;
      errorMessage = null;
    });

    try {
      final loadedTask = await _tasksApi.getTask(
        project: taskItem.project,
        taskId: taskItem.task.taskId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        taskItem = loadedTask;
        isRefreshing = false;
      });

      prepareEditForm();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        errorMessage = 'Could not refresh this task.';
        isRefreshing = false;
      });
    }
  }

  void prepareEditForm() {
    titleController.text = taskItem.task.title;
    descriptionController.text = taskItem.task.description ?? '';
    editPriority = taskItem.task.priority;
    editStatus = taskItem.task.status;
    editDueDate = taskItem.task.dueDate;
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

  Widget buildHeader(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Row(
      children: [
        buildCircleButton(
          context,
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Task Details',
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
        buildCircleButton(
          context,
          icon: Icons.edit_rounded,
          onTap: showEditTaskSheet,
        ),
      ],
    );
  }

  Widget buildCircleButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 42,
        height: 42,
        decoration: cardDecoration(context, radius: 999),
        child: Icon(icon, size: 20, color: mutedColor(context)),
      ),
    );
  }

  Widget buildErrorBanner(BuildContext context) {
    if (errorMessage == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PlanoraTheme.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PlanoraTheme.error.withValues(alpha: 0.26)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: PlanoraTheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              errorMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: PlanoraTheme.error,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildHeroCard(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final task = taskItem.task;
    final taskStatusColor = statusColor(task.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(context, radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: task.isCompleted
                      ? null
                      : PlanoraTheme.primaryGradientFor(context),
                  color: task.isCompleted ? PlanoraTheme.success : null,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  task.isCompleted
                      ? Icons.check_rounded
                      : Icons.check_box_outline_blank_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? PlanoraTheme.darkTextPrimary
                            : PlanoraTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          taskItem.project.isTeamProject
                              ? Icons.groups_2_rounded
                              : Icons.folder_rounded,
                          size: 15,
                          color: mutedColor(context),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            taskItem.project.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: mutedColor(context),
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              buildBadge(
                context,
                label: task.status.label,
                color: taskStatusColor,
              ),
              buildBadge(
                context,
                label: task.priority.label,
                color: priorityColor(task.priority),
              ),
              if (task.isOverdue)
                buildBadge(
                  context,
                  label: 'Overdue',
                  color: PlanoraTheme.error,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildBadge(
    BuildContext context, {
    required String label,
    required Color color,
  }) {
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget buildInfoGrid(BuildContext context) {
    final task = taskItem.task;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: buildInfoCard(
                context,
                icon: Icons.calendar_today_outlined,
                label: 'Due Date',
                value: task.dueDateLabel,
                color: task.isOverdue ? PlanoraTheme.error : PlanoraTheme.info,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: buildInfoCard(
                context,
                icon: Icons.flag_rounded,
                label: 'Priority',
                value: task.priority.label,
                color: priorityColor(task.priority),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: buildInfoCard(
                context,
                icon: Icons.track_changes_rounded,
                label: 'Status',
                value: task.status.label,
                color: statusColor(task.status),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: buildInfoCard(
                context,
                icon: Icons.task_alt_rounded,
                label: 'Completed',
                value: task.completedDateLabel,
                color: PlanoraTheme.success,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      height: 94,
      padding: const EdgeInsets.all(12),
      decoration: cardDecoration(context, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.20 : 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const Spacer(),
            ],
          ),
          const Spacer(),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: mutedColor(context),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark
                  ? PlanoraTheme.darkTextPrimary
                  : PlanoraTheme.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDescriptionCard(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final description = taskItem.task.description;
    final hasDescription = description != null && description.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(context, radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: isDark
                  ? PlanoraTheme.darkTextPrimary
                  : PlanoraTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasDescription ? description : 'No description added.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: hasDescription
                  ? isDark
                        ? PlanoraTheme.darkTextSecondary
                        : PlanoraTheme.textSecondary
                  : mutedColor(context),
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildActions(BuildContext context) {
    final task = taskItem.task;

    return Column(
      children: [
        if (!task.isCompleted) ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: isCompleting ? null : markTaskCompleted,
              icon: isCompleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: const Text('Mark Completed'),
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: showEditTaskSheet,
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Edit Task'),
          ),
        ),
      ],
    );
  }

  Future<void> markTaskCompleted() async {
    setState(() {
      isCompleting = true;
    });

    try {
      final updatedTask = await _tasksApi.markTaskCompleted(
        project: taskItem.project,
        taskId: taskItem.task.taskId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        taskItem = updatedTask;
        isCompleting = false;
      });

      prepareEditForm();
      widget.onTaskChanged?.call();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task marked completed.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isCompleting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not complete task. Try again.')),
      );
    }
  }

  Future<void> showEditTaskSheet() async {
    prepareEditForm();

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
                                Icons.edit_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Edit Task',
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
                        buildFieldLabel(sheetContext, 'Task Name'),
                        const SizedBox(height: 8),
                        buildTaskTextField(
                          sheetContext,
                          controller: titleController,
                          hintText: 'Task name',
                          icon: Icons.task_alt_rounded,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 18),
                        buildFieldLabel(sheetContext, 'Description'),
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
                        buildFieldLabel(sheetContext, 'Status'),
                        const SizedBox(height: 10),
                        buildStatusSelector(
                          sheetContext,
                          setSheetState: setSheetState,
                        ),
                        const SizedBox(height: 18),
                        buildFieldLabel(sheetContext, 'Priority'),
                        const SizedBox(height: 10),
                        buildPrioritySelector(
                          sheetContext,
                          setSheetState: setSheetState,
                        ),
                        const SizedBox(height: 18),
                        buildFieldLabel(sheetContext, 'Due Date'),
                        const SizedBox(height: 8),
                        buildDueDatePicker(
                          sheetContext,
                          onTap: () async {
                            final date = await pickEditDate();

                            if (date == null) {
                              return;
                            }

                            setSheetState(() {
                              editDueDate = date;
                            });

                            setState(() {
                              editDueDate = date;
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () => updateTaskFromSheet(
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
                                child: isSaving
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Save Changes',
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
  }

  Widget buildFieldLabel(BuildContext context, String label) {
    final isDark = PlanoraTheme.isDark(context);

    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w900,
        color: isDark ? PlanoraTheme.darkTextPrimary : PlanoraTheme.textPrimary,
      ),
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

  Widget buildStatusSelector(
    BuildContext context, {
    required StateSetter setSheetState,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final status in TaskStatus.values)
          buildStatusOption(
            context,
            status: status,
            setSheetState: setSheetState,
          ),
      ],
    );
  }

  Widget buildStatusOption(
    BuildContext context, {
    required TaskStatus status,
    required StateSetter setSheetState,
  }) {
    final isSelected = editStatus == status;
    final color = statusColor(status);
    final isDark = PlanoraTheme.isDark(context);

    return InkWell(
      onTap: () {
        setSheetState(() {
          editStatus = status;
        });

        setState(() {
          editStatus = status;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
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
          status.label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: isSelected ? color : mutedColor(context),
            fontWeight: FontWeight.w900,
          ),
        ),
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
    final isSelected = editPriority == priority;
    final color = priorityColor(priority);
    final isDark = PlanoraTheme.isDark(context);

    return InkWell(
      onTap: () {
        setSheetState(() {
          editPriority = priority;
        });

        setState(() {
          editPriority = priority;
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
                editDueDate == null
                    ? 'Choose due date'
                    : formatInputDate(editDueDate!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: editDueDate == null
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

  Future<DateTime?> pickEditDate() async {
    final now = DateTime.now();

    return showDatePicker(
      context: context,
      initialDate: editDueDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
  }

  Future<void> updateTaskFromSheet({
    required BuildContext sheetContext,
    required StateSetter setSheetState,
  }) async {
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();

    if (title.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task name must be at least 2 letters.')),
      );
      return;
    }

    setSheetState(() {
      isSaving = true;
    });

    setState(() {
      isSaving = true;
    });

    try {
      final updatedTask = await _tasksApi.updateTask(
        project: taskItem.project,
        taskId: taskItem.task.taskId,
        request: TaskUpdateRequest(
          title: title,
          description: description,
          priority: editPriority,
          status: editStatus,
          dueDate: editDueDate,
        ),
      );

      if (!mounted || !sheetContext.mounted) {
        return;
      }

      Navigator.of(sheetContext).pop();

      setState(() {
        taskItem = updatedTask;
        isSaving = false;
      });

      prepareEditForm();
      widget.onTaskChanged?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task updated successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setSheetState(() {
        isSaving = false;
      });

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update task. Try again.')),
      );
    }
  }

  Widget buildContent(BuildContext context) {
    return RefreshIndicator(
      onRefresh: loadTaskDetails,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildErrorBanner(context),
            if (isRefreshing)
              const LinearProgressIndicator(minHeight: 3)
            else
              const SizedBox(height: 3),
            const SizedBox(height: 16),
            buildHeroCard(context),
            const SizedBox(height: 14),
            buildInfoGrid(context),
            const SizedBox(height: 14),
            buildDescriptionCard(context),
            const SizedBox(height: 18),
            buildActions(context),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: PlanoraTheme.onboardingBackgroundFor(context),
        ),
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  children: [
                    buildHeader(context),
                    const SizedBox(height: 22),
                    Expanded(child: buildContent(context)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
