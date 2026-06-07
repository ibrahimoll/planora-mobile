import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/config/app_config.dart';
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
  final TextEditingController commentController = TextEditingController();

  late TaskListItem taskItem;
  late TaskPriority editPriority;
  late TaskStatus editStatus;

  int selectedTabIndex = 0;

  List<TaskAttachmentModel> attachments = [];
  List<TaskCommentModel> comments = [];

  bool isRefreshing = false;
  bool isSaving = false;
  bool isCompleting = false;
  bool isDeleting = false;
  bool isSendingComment = false;

  String? errorMessage;
  String? attachmentMessage;
  String? activityMessage;
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
    commentController.dispose();
    super.dispose();
  }

  Future<void> loadTaskDetails() async {
    setState(() {
      isRefreshing = true;
      errorMessage = null;
      attachmentMessage = null;
      activityMessage = null;
    });

    TaskListItem? loadedTask;
    List<TaskAttachmentModel>? loadedAttachments;
    List<TaskCommentModel>? loadedComments;
    String? taskError;
    String? attachmentsError;
    String? commentsError;

    try {
      loadedTask = await _tasksApi.getTask(
        project: taskItem.project,
        taskId: taskItem.task.taskId,
      );
    } catch (error) {
      taskError = 'Could not refresh this task.';
    }

    final taskForRelatedData = loadedTask ?? taskItem;

    try {
      loadedAttachments = await _tasksApi.getTaskAttachments(
        project: taskForRelatedData.project,
        taskId: taskForRelatedData.task.taskId,
      );
    } catch (error) {
      attachmentsError = 'Attachments will be connected next.';
    }

    try {
      loadedComments = await _tasksApi.getTaskComments(
        project: taskForRelatedData.project,
        taskId: taskForRelatedData.task.taskId,
      );
    } catch (error) {
      commentsError = 'Activity will be connected next.';
    }

    if (!mounted) {
      return;
    }

    setState(() {
      if (loadedTask != null) {
        taskItem = loadedTask;
      }

      if (loadedAttachments != null) {
        attachments = loadedAttachments;
      }

      if (loadedComments != null) {
        comments = loadedComments;
      }

      errorMessage = taskError;
      attachmentMessage = attachmentsError;
      activityMessage = commentsError;
      isRefreshing = false;
    });

    prepareEditForm();
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
        return PlanoraTheme.textMuted;
      case TaskStatus.inProgress:
        return PlanoraTheme.secondaryPurple;
      case TaskStatus.completed:
        return PlanoraTheme.success;
      case TaskStatus.blocked:
        return PlanoraTheme.error;
    }
  }

  Color priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return PlanoraTheme.success;
      case TaskPriority.medium:
        return PlanoraTheme.warning;
      case TaskPriority.high:
        return PlanoraTheme.error;
    }
  }

  Widget buildHeader(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final task = taskItem.task;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: cardDecoration(context, radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              buildCircleButton(
                context,
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              buildCircleButton(
                context,
                icon: Icons.info_outline_rounded,
                onTap: showTaskInfoDialog,
              ),
              const SizedBox(width: 6),
              buildCircleButton(
                context,
                icon: Icons.edit_rounded,
                onTap: showEditTaskSheet,
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 36,
                height: 36,
                child: PopupMenuButton<String>(
                  tooltip: 'More',
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  onSelected: (value) {
                    switch (value) {
                      case 'refresh':
                        loadTaskDetails();
                        break;
                      case 'complete':
                        if (!taskItem.task.isCompleted) {
                          markTaskCompleted();
                        }
                        break;
                    }
                  },
                  itemBuilder: (context) {
                    return [
                      const PopupMenuItem(
                        value: 'refresh',
                        child: Text('Refresh'),
                      ),
                      if (!taskItem.task.isCompleted)
                        const PopupMenuItem(
                          value: 'complete',
                          child: Text('Mark completed'),
                        ),
                    ];
                  },
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: mutedColor(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            task.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: isDark
                  ? PlanoraTheme.darkTextPrimary
                  : PlanoraTheme.textPrimary,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 10),
          buildMetadataWrap(context),
          const SizedBox(height: 14),
          buildTabRow(context),
        ],
      ),
    );
  }

  Widget buildMetadataWrap(BuildContext context) {
    final task = taskItem.task;
    final chips = <Widget>[
      buildMetadataChip(
        context,
        icon: Icons.radio_button_checked_rounded,
        label: task.status.label,
        color: statusColor(task.status),
      ),
      buildMetadataChip(
        context,
        icon: Icons.flag_rounded,
        label: '${task.priority.label} Priority',
        color: priorityColor(task.priority),
      ),
      buildMetadataChip(
        context,
        icon: Icons.calendar_today_rounded,
        label: task.dueDate == null
            ? 'No due date'
            : formatShortDate(task.dueDate!),
        color: task.isOverdue ? PlanoraTheme.error : mutedColor(context),
      ),
      buildMetadataChip(
        context,
        icon: taskItem.project.isTeamProject
            ? Icons.groups_2_rounded
            : Icons.folder_rounded,
        label: taskItem.project.title,
        color: mutedColor(context),
      ),
    ];

    final sectionName = task.sectionName;

    if (sectionName != null && sectionName.trim().isNotEmpty) {
      chips.add(
        buildMetadataChip(
          context,
          icon: Icons.view_column_outlined,
          label: sectionName,
          color: mutedColor(context),
        ),
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget buildMetadataChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ),
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
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: PlanoraTheme.isDark(context)
              ? PlanoraTheme.darkSurfaceVariant
              : PlanoraTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: PlanoraTheme.isDark(context)
                ? PlanoraTheme.darkBorder
                : PlanoraTheme.border,
          ),
        ),
        child: Icon(icon, size: 20, color: mutedColor(context)),
      ),
    );
  }

  Widget buildTabRow(BuildContext context) {
    final labels = ['Overview', 'Subtasks', 'Attachments', 'Activity'];

    return Row(
      children: [
        for (var index = 0; index < labels.length; index++)
          Expanded(
            child: buildTabButton(
              context,
              label: labels[index],
              index: index,
              count: tabCountFor(index),
            ),
          ),
      ],
    );
  }

  int tabCountFor(int index) {
    switch (index) {
      case 1:
        return taskItem.task.subtasks.length;
      case 2:
        return attachments.length;
      case 3:
        return comments.length;
      default:
        return 0;
    }
  }

  Widget buildTabButton(
    BuildContext context, {
    required String label,
    required int index,
    required int count,
  }) {
    final isSelected = selectedTabIndex == index;
    final selectedColor = PlanoraTheme.isDark(context)
        ? PlanoraTheme.darkPrimary
        : PlanoraTheme.primaryPurple;

    return InkWell(
      onTap: () {
        setState(() {
          selectedTabIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? selectedColor : Colors.transparent,
              width: 2.4,
            ),
          ),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isSelected ? selectedColor : mutedColor(context),
                    fontWeight: FontWeight.w900,
                    fontSize: 10.5,
                  ),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: selectedColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    count.toString(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selectedColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
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

  Widget buildOverviewTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildDescriptionCard(context),
        const SizedBox(height: 14),
        buildInfoGrid(context),
        const SizedBox(height: 14),
        buildAssigneeCard(context),
        buildTagsSection(context),
        buildFollowersSection(context),
      ],
    );
  }

  Widget buildInfoGrid(BuildContext context) {
    final task = taskItem.task;
    final rows = <Widget>[];

    void addRow({
      required IconData icon,
      required String label,
      required String value,
      required Color color,
    }) {
      if (rows.isNotEmpty) {
        rows.add(
          Divider(
            height: 1,
            color: PlanoraTheme.isDark(context)
                ? PlanoraTheme.darkBorder
                : PlanoraTheme.border,
          ),
        );
      }

      rows.add(
        buildInfoCard(
          context,
          icon: icon,
          label: label,
          value: value,
          color: color,
        ),
      );
    }

    addRow(
      icon: Icons.radio_button_checked_rounded,
      label: 'Status',
      value: task.status.label,
      color: statusColor(task.status),
    );
    addRow(
      icon: Icons.flag_rounded,
      label: 'Priority',
      value: task.priority.label,
      color: priorityColor(task.priority),
    );
    addRow(
      icon: Icons.folder_rounded,
      label: 'Project',
      value: taskItem.project.title,
      color: PlanoraTheme.secondaryPurple,
    );

    final sectionName = task.sectionName;

    if (sectionName != null && sectionName.trim().isNotEmpty) {
      addRow(
        icon: Icons.view_column_outlined,
        label: 'Section',
        value: sectionName,
        color: PlanoraTheme.info,
      );
    }

    addRow(
      icon: Icons.calendar_today_rounded,
      label: 'Due Date',
      value: task.dueDate == null
          ? 'No due date'
          : formatShortDate(task.dueDate!),
      color: task.isOverdue ? PlanoraTheme.error : PlanoraTheme.info,
    );

    if (task.startDate != null) {
      addRow(
        icon: Icons.event_available_rounded,
        label: 'Start Date',
        value: formatShortDate(task.startDate!),
        color: PlanoraTheme.success,
      );
    }

    if (task.estimatedHours != null) {
      addRow(
        icon: Icons.schedule_rounded,
        label: 'Time Estimate',
        value: formatHoursLabel(task.estimatedHours!),
        color: PlanoraTheme.warning,
      );
    }

    if (task.actualHours != null) {
      addRow(
        icon: Icons.timer_outlined,
        label: 'Time Tracked',
        value: formatHoursLabel(task.actualHours!),
        color: PlanoraTheme.secondaryPurple,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(context, radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle(context, 'Details'),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackValue = constraints.maxWidth < 320;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: stackValue
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.20 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: stackValue
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: mutedColor(context),
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            value,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isDark
                                      ? PlanoraTheme.darkTextPrimary
                                      : PlanoraTheme.textPrimary,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: mutedColor(context),
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: isDark
                                        ? PlanoraTheme.darkTextPrimary
                                        : PlanoraTheme.textPrimary,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
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
            hasDescription ? description : 'No description yet.',
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

  TaskMemberPreview? detailAssigneePreview() {
    final task = taskItem.task;
    final assignee = task.assigneePreview;

    if (assignee != null && assignee.displayLabel != 'Unknown user') {
      return assignee;
    }

    if (!taskItem.project.isTeamProject && task.assignedTo != null) {
      return TaskMemberPreview(
        userId: task.assignedTo,
        name: 'You',
        email: null,
        avatarUrl: null,
      );
    }

    if (taskItem.project.isTeamProject && task.assignedTo != null) {
      return TaskMemberPreview(
        userId: task.assignedTo,
        name: null,
        email: null,
        avatarUrl: null,
        fallbackLabel: 'Assigned member',
      );
    }

    return null;
  }

  Widget buildAssigneeCard(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final assignee = detailAssigneePreview();
    final title =
        assignee?.displayLabel ??
        (taskItem.project.isTeamProject ? 'Unassigned' : 'No assignee');
    final email = assignee?.email;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(context, radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle(context, 'Assignee'),
          const SizedBox(height: 12),
          Row(
            children: [
              buildMemberAvatar(context, assignee, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? PlanoraTheme.darkTextPrimary
                            : PlanoraTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (email != null && email.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: mutedColor(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildTagsSection(BuildContext context) {
    final tags = taskItem.task.tags;

    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration(context, radius: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildSectionTitle(context, 'Tags'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in tags)
                  buildBadge(
                    context,
                    label: tag,
                    color: PlanoraTheme.secondaryPurple,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildFollowersSection(BuildContext context) {
    final followers = taskItem.task.followers;

    if (followers.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleFollowers = followers.take(5).toList();
    final overflowCount = followers.length - visibleFollowers.length;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration(context, radius: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildSectionTitle(context, 'Followers'),
            const SizedBox(height: 12),
            SizedBox(
              height: 34,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var index = 0; index < visibleFollowers.length; index++)
                    Positioned(
                      left: index * 24,
                      child: buildMemberAvatar(
                        context,
                        visibleFollowers[index],
                        size: 34,
                      ),
                    ),
                  if (overflowCount > 0)
                    Positioned(
                      left: visibleFollowers.length * 24,
                      child: buildCountAvatar(context, overflowCount),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMemberAvatar(
    BuildContext context,
    TaskMemberPreview? member, {
    required double size,
  }) {
    final avatarUrl = resolveProfileImageUrl(member?.avatarUrl);
    final hasAvatar = avatarUrl != null && avatarUrl.trim().isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: PlanoraTheme.isDark(context)
              ? PlanoraTheme.darkBorder
              : PlanoraTheme.surface,
          width: 2,
        ),
      ),
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: PlanoraTheme.secondaryPurple.withValues(alpha: 0.14),
        child: hasAvatar
            ? ClipOval(
                child: buildProfileImage(
                  context,
                  avatarUrl: avatarUrl,
                  member: member,
                  size: size,
                ),
              )
            : buildAvatarInitials(context, member),
      ),
    );
  }

  Widget buildProfileImage(
    BuildContext context, {
    required String avatarUrl,
    required TaskMemberPreview? member,
    required double size,
  }) {
    final lowerUrl = avatarUrl.toLowerCase();
    final isSvg = lowerUrl.endsWith('.svg') || lowerUrl.contains('/svg');

    if (isSvg) {
      return SvgPicture.network(
        avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholderBuilder: (context) {
          return Center(child: buildAvatarInitials(context, member));
        },
      );
    }

    return Image.network(
      avatarUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Center(child: buildAvatarInitials(context, member));
      },
    );
  }

  Widget buildAvatarInitials(BuildContext context, TaskMemberPreview? member) {
    return Text(
      member?.initials ?? '?',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: PlanoraTheme.secondaryPurple,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  String? resolveProfileImageUrl(String? rawUrl) {
    final trimmed = rawUrl?.trim();

    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(trimmed);

    if (uri != null && uri.hasScheme) {
      return trimmed;
    }

    if (trimmed.startsWith('/')) {
      return '${AppConfig.apiBaseUrl}$trimmed';
    }

    return '${AppConfig.apiBaseUrl}/$trimmed';
  }

  Widget buildCountAvatar(BuildContext context, int count) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: PlanoraTheme.secondaryPurple.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: PlanoraTheme.isDark(context)
              ? PlanoraTheme.darkBorder
              : PlanoraTheme.surface,
          width: 2,
        ),
      ),
      child: Text(
        '+$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: PlanoraTheme.secondaryPurple,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget buildSectionTitle(BuildContext context, String title) {
    final isDark = PlanoraTheme.isDark(context);

    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w900,
        color: isDark ? PlanoraTheme.darkTextPrimary : PlanoraTheme.textPrimary,
      ),
    );
  }

  String formatHoursLabel(double hours) {
    final totalMinutes = (hours * 60).round();
    final wholeHours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (wholeHours == 0 && minutes == 0) {
      return '0m';
    }

    if (minutes == 0) {
      return '${wholeHours}h';
    }

    if (wholeHours == 0) {
      return '${minutes}m';
    }

    return '${wholeHours}h ${minutes}m';
  }

  Widget buildSubtasksTab(BuildContext context) {
    final subtasks = taskItem.task.subtasks;

    if (subtasks.isEmpty) {
      return buildEmptyStateCard(
        context,
        icon: Icons.checklist_rounded,
        message: 'Subtasks will be connected next.',
        trailing: buildDisabledAddRow(
          context,
          icon: Icons.add_rounded,
          label: 'Add subtask',
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: cardDecoration(context, radius: 20),
      child: Column(
        children: [
          for (var index = 0; index < subtasks.length; index++) ...[
            buildSubtaskRow(context, subtasks[index]),
            if (index != subtasks.length - 1)
              Divider(
                height: 1,
                color: PlanoraTheme.isDark(context)
                    ? PlanoraTheme.darkBorder
                    : PlanoraTheme.border,
              ),
          ],
        ],
      ),
    );
  }

  Widget buildSubtaskRow(BuildContext context, TaskSubtaskPreview subtask) {
    final isDark = PlanoraTheme.isDark(context);

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: subtask.isCompleted
                  ? PlanoraTheme.success
                  : Colors.transparent,
              border: Border.all(
                color: subtask.isCompleted
                    ? PlanoraTheme.success
                    : PlanoraTheme.secondaryPurple,
                width: 1.6,
              ),
            ),
            child: subtask.isCompleted
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              subtask.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark
                    ? PlanoraTheme.darkTextPrimary
                    : PlanoraTheme.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          buildBadge(
            context,
            label: subtask.status.label,
            color: statusColor(subtask.status),
          ),
        ],
      ),
    );
  }

  Widget buildAttachmentsTab(BuildContext context) {
    if (attachmentMessage != null) {
      return buildEmptyStateCard(
        context,
        icon: Icons.attach_file_rounded,
        message: attachmentMessage!,
        trailing: buildUploadCard(context, enabled: false),
      );
    }

    if (attachments.isEmpty) {
      return buildEmptyStateCard(
        context,
        icon: Icons.attach_file_rounded,
        message: 'No attachments yet.',
        trailing: buildUploadCard(context, enabled: false),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final attachment in attachments)
              SizedBox(
                width: itemWidth,
                child: buildAttachmentCard(context, attachment),
              ),
            SizedBox(width: itemWidth, child: buildUploadCard(context)),
          ],
        );
      },
    );
  }

  Widget buildAttachmentCard(
    BuildContext context,
    TaskAttachmentModel attachment,
  ) {
    final isDark = PlanoraTheme.isDark(context);
    final subtitle = attachment.sizeLabel ?? attachment.fileType ?? 'File';

    return Container(
      height: 148,
      padding: const EdgeInsets.all(12),
      decoration: cardDecoration(context, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 64,
            width: double.infinity,
            decoration: BoxDecoration(
              color: attachment.isImage
                  ? PlanoraTheme.secondaryPurple.withValues(alpha: 0.12)
                  : PlanoraTheme.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              attachment.isImage
                  ? Icons.image_outlined
                  : Icons.insert_drive_file_outlined,
              color: attachment.isImage
                  ? PlanoraTheme.secondaryPurple
                  : PlanoraTheme.warning,
              size: 28,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            attachment.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark
                  ? PlanoraTheme.darkTextPrimary
                  : PlanoraTheme.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
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
      ),
    );
  }

  Widget buildUploadCard(BuildContext context, {bool enabled = false}) {
    final isDark = PlanoraTheme.isDark(context);
    final color = enabled ? PlanoraTheme.secondaryPurple : mutedColor(context);

    return InkWell(
      onTap: null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 148,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: enabled
                ? PlanoraTheme.secondaryPurple.withValues(alpha: 0.36)
                : isDark
                ? PlanoraTheme.darkBorder
                : PlanoraTheme.border,
            style: BorderStyle.solid,
          ),
          boxShadow: PlanoraTheme.cardShadowFor(context),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_upload_outlined, color: color, size: 30),
            const SizedBox(height: 10),
            Text(
              enabled ? 'Upload File' : 'Upload will be connected next.',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildActivityTab(BuildContext context) {
    final children = <Widget>[];

    if (activityMessage != null) {
      children.add(
        buildEmptyStateContent(
          context,
          icon: Icons.forum_outlined,
          message: activityMessage!,
        ),
      );
    } else if (comments.isEmpty) {
      children.add(
        buildEmptyStateContent(
          context,
          icon: Icons.forum_outlined,
          message: 'No activity yet.',
        ),
      );
    } else {
      for (final comment in comments) {
        children.add(buildCommentRow(context, comment));
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(context, radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildCommentInput(context),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget buildCommentInput(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final isConnected = activityMessage == null;

    return Row(
      children: [
        buildMemberAvatar(context, detailAssigneePreview(), size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: commentController,
            enabled: isConnected && !isSendingComment,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => sendComment(),
            style: TextStyle(
              color: isDark
                  ? PlanoraTheme.darkTextPrimary
                  : PlanoraTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: 'Add a comment...',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              suffixIcon: IconButton(
                onPressed: isConnected && !isSendingComment
                    ? sendComment
                    : null,
                icon: isSendingComment
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildCommentRow(BuildContext context, TaskCommentModel comment) {
    final isDark = PlanoraTheme.isDark(context);
    final author = comment.authorPreview;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildMemberAvatar(context, author, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        author.displayLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? PlanoraTheme.darkTextPrimary
                              : PlanoraTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatShortDate(comment.createdAt),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: mutedColor(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.commentText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? PlanoraTheme.darkTextSecondary
                        : PlanoraTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEmptyStateCard(
    BuildContext context, {
    required IconData icon,
    required String message,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(context, radius: 20),
      child: Column(
        children: [
          buildEmptyStateContent(context, icon: icon, message: message),
          if (trailing != null) ...[const SizedBox(height: 14), trailing],
        ],
      ),
    );
  }

  Widget buildEmptyStateContent(
    BuildContext context, {
    required IconData icon,
    required String message,
  }) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: PlanoraTheme.secondaryPurple.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: PlanoraTheme.secondaryPurple),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: mutedColor(context),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget buildDisabledAddRow(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: PlanoraTheme.secondaryPurple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: PlanoraTheme.secondaryPurple, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: PlanoraTheme.secondaryPurple,
              fontWeight: FontWeight.w900,
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
            onPressed: isDeleting ? null : showEditTaskSheet,
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Edit Task'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: isDeleting ? null : confirmDeleteTask,
            style: OutlinedButton.styleFrom(
              foregroundColor: PlanoraTheme.error,
              side: BorderSide(
                color: PlanoraTheme.error.withValues(alpha: 0.45),
                width: 1.2,
              ),
            ),
            icon: isDeleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete Task'),
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

  Future<void> sendComment() async {
    final commentText = commentController.text.trim();

    if (commentText.isEmpty || activityMessage != null) {
      return;
    }

    setState(() {
      isSendingComment = true;
    });

    try {
      final createdComment = await _tasksApi.createTaskComment(
        project: taskItem.project,
        taskId: taskItem.task.taskId,
        commentText: commentText,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        comments = [...comments, createdComment];
        isSendingComment = false;
      });

      commentController.clear();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isSendingComment = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add comment. Try again.')),
      );
    }
  }

  Future<void> confirmDeleteTask() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete task?'),
          content: const Text(
            'This task will be permanently deleted. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: PlanoraTheme.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await deleteTask();
    }
  }

  Future<void> deleteTask() async {
    setState(() {
      isDeleting = true;
    });

    try {
      await _tasksApi.deleteTask(
        project: taskItem.project,
        taskId: taskItem.task.taskId,
      );

      if (!mounted) {
        return;
      }

      widget.onTaskChanged?.call();
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Task deleted successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isDeleting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete task. Try again.')),
      );
    }
  }

  Future<void> showTaskInfoDialog() async {
    final task = taskItem.task;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Task Info'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildDialogInfoRow('Created', formatShortDate(task.createdAt)),
              buildDialogInfoRow('Completed', task.completedDateLabel),
              buildDialogInfoRow('Project', taskItem.project.title),
              if (task.sectionName != null)
                buildDialogInfoRow('Section', task.sectionName!),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget buildDialogInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
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
            const SizedBox(height: 14),
            buildSelectedTabContent(context),
            const SizedBox(height: 18),
            buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget buildSelectedTabContent(BuildContext context) {
    switch (selectedTabIndex) {
      case 1:
        return buildSubtasksTab(context);
      case 2:
        return buildAttachmentsTab(context);
      case 3:
        return buildActivityTab(context);
      default:
        return buildOverviewTab(context);
    }
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
