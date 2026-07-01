import 'package:flutter/material.dart';

import '../ai/data/ai_plan_api.dart';
import '../auth/data/project_api.dart';
import '../auth/models/project_models.dart';
import '../tasks/data/tasks_api.dart';
import '../tasks/models/task_models.dart';
import '../tasks/task_detail_screen.dart';
import 'data/project_insights_api.dart';

class ProjectDetailScreen extends StatefulWidget {
  final ProjectModel project;
  final ProjectsApi projectsApi;
  final TasksApi tasksApi;
  final AiPlanApi aiPlanApi;
  final ProjectInsightsApi insightsApi;
  final VoidCallback? onProjectChanged;

  const ProjectDetailScreen({
    super.key,
    required this.project,
    this.projectsApi = const ProjectsApi(),
    this.tasksApi = const TasksApi(),
    this.aiPlanApi = const AiPlanApi(),
    this.insightsApi = const ProjectInsightsApi(),
    this.onProjectChanged,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  static const double pageX = 8;

  late final ProjectsApi projectsApi = widget.projectsApi;
  late final TasksApi tasksApi = widget.tasksApi;
  late ProjectModel project = widget.project;

  bool loading = true;
  String? error;
  int? deletingTaskId;
  int taskFilterIndex = 0;
  List<TaskListItem> tasks = [];
  List<ProjectMemberModel> members = [];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final loadedProject = await projectsApi.getProject(project);
      final loadedTasks = await tasksApi.getProjectTasks(
        project: TaskProjectSummary.fromProject(loadedProject),
      );
      final loadedMembers = await projectsApi.getProjectMembers(loadedProject);

      if (!mounted) return;
      setState(() {
        project = loadedProject;
        tasks = loadedTasks;
        members = loadedMembers;
        loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Could not load project details.';
      });
    }
  }

  double get completion {
    if (tasks.isEmpty) return project.isCompleted ? 100 : 0;
    return (doneTasks / tasks.length) * 100;
  }

  int get doneTasks => tasks.where((item) => item.task.isCompleted).length;
  int get activeTasks => tasks.where((item) => !item.task.isCompleted).length;
  int get overdueTasks => tasks.where((item) => item.task.isOverdue).length;

  List<TaskListItem> get filteredTasks {
    final filtered = tasks.where((item) {
      final task = item.task;
      switch (taskFilterIndex) {
        case 1:
          return !task.isCompleted;
        case 2:
          return task.isOverdue;
        case 3:
          return task.isCompleted;
        default:
          return true;
      }
    }).toList();
    filtered.sort(compareTasks);
    return filtered;
  }

  int compareTasks(TaskListItem left, TaskListItem right) {
    final a = left.task;
    final b = right.task;
    if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
    if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
    final ad = a.dueDate;
    final bd = b.dueDate;
    if (ad == null && bd == null) return a.title.compareTo(b.title);
    if (ad == null) return 1;
    if (bd == null) return -1;
    return ad.compareTo(bd);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: colors.surface,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(pageX, 14, pageX, 8),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Project Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      onPressed: loading ? null : refresh,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ),
              if (loading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: pageX),
                  child: LinearProgressIndicator(minHeight: 2, borderRadius: BorderRadius.circular(999)),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(pageX, 8, pageX, 8),
                  child: messageBox(error!),
                ),
              tabs(colors),
              Expanded(
                child: TabBarView(
                  children: [
                    tab([projectCard(), statsGrid(), if (members.isNotEmpty) membersCard()]),
                    tab([tasksCard()]),
                    tab([comingSoonCard('AI Tools', 'Risk analysis, smart schedule, and AI plan history will stay here.')]),
                    tab([comingSoonCard('Reports', 'Reports and activity timeline will stay here.')]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget tabs(ColorScheme colors) {
    return Container(
      height: 46,
      margin: const EdgeInsets.fromLTRB(pageX, 8, pageX, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withOpacity(.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: colors.onPrimary,
        unselectedLabelColor: colors.onSurfaceVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        indicator: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(14)),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Tasks'),
          Tab(text: 'AI Tools'),
          Tab(text: 'Reports'),
        ],
      ),
    );
  }

  Widget tab(List<Widget> children) {
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(pageX, 4, pageX, 24),
        itemBuilder: (_, index) => children[index],
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemCount: children.length,
      ),
    );
  }

  Widget projectCard() {
    final colors = Theme.of(context).colorScheme;
    final percent = completion.clamp(0, 100).toDouble();
    final description = (project.description ?? '').trim();
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(project.isTeamProject ? Icons.groups_2_rounded : Icons.folder_rounded, color: colors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text('${project.statusLabel} • ${project.projectTypeLabel} • ${project.deadlineLabel}', style: muted()),
                  ],
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            brief(description),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text('${percent.round()}% complete', style: bold()),
              const Spacer(),
              Text('$doneTasks/${tasks.length} tasks', style: muted()),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: percent / 100, minHeight: 8),
          ),
        ],
      ),
    );
  }

  Widget brief(String value) {
    final colors = Theme.of(context).colorScheme;
    final cleaned = value.replaceFirst('AI planning brief', '').trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withOpacity(.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: colors.primary),
              const SizedBox(width: 6),
              Text('AI planning brief', style: bold()),
            ],
          ),
          const SizedBox(height: 7),
          Text(cleaned, style: muted()),
        ],
      ),
    );
  }

  Widget statsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.45,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        stat('Tasks', '${tasks.length}', Icons.list_alt_rounded),
        stat('Completed', '$doneTasks', Icons.check_circle_rounded),
        stat('Overdue', '$overdueTasks', Icons.timer_off_rounded),
        stat('Members', '${members.length}', Icons.groups_rounded),
      ],
    );
  }

  Widget tasksCard() {
    final filtered = filteredTasks;
    final todo = filtered.where((item) => item.task.status == TaskStatus.todo).toList();
    final doing = filtered.where((item) => item.task.status == TaskStatus.inProgress).toList();
    final blocked = filtered.where((item) => item.task.status == TaskStatus.blocked).toList();
    final done = filtered.where((item) => item.task.status == TaskStatus.completed).toList();

    return section(
      'Project Tasks',
      '${filtered.length} showing • $activeTasks active • $overdueTasks overdue',
      Icons.task_alt_rounded,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          taskSummaryStrip(),
          const SizedBox(height: 12),
          taskFilters(),
          const SizedBox(height: 14),
          if (tasks.isEmpty)
            emptyState('No tasks in this project yet.', 'Generate a plan or add tasks from the main Tasks screen.')
          else if (filtered.isEmpty)
            emptyState('No tasks match this filter.', 'Try another filter above.')
          else ...[
            if (todo.isNotEmpty) taskGroup('To Do', todo, Icons.radio_button_unchecked_rounded),
            if (doing.isNotEmpty) taskGroup('In Progress', doing, Icons.timelapse_rounded),
            if (blocked.isNotEmpty) taskGroup('Blocked', blocked, Icons.block_rounded),
            if (done.isNotEmpty) taskGroup('Completed', done, Icons.check_circle_rounded),
          ],
        ],
      ),
    );
  }

  Widget taskSummaryStrip() {
    return Row(
      children: [
        Expanded(child: miniStat('All', '${tasks.length}', Icons.list_alt_rounded)),
        const SizedBox(width: 8),
        Expanded(child: miniStat('Active', '$activeTasks', Icons.bolt_rounded)),
        const SizedBox(width: 8),
        Expanded(child: miniStat('Done', '$doneTasks', Icons.check_rounded)),
      ],
    );
  }

  Widget taskFilters() {
    const labels = ['All', 'Active', 'Overdue', 'Done'];
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++) ...[
            ChoiceChip(
              selected: taskFilterIndex == index,
              label: Text(labels[index]),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w900,
                color: taskFilterIndex == index ? colors.onPrimary : colors.onSurfaceVariant,
              ),
              selectedColor: colors.primary,
              backgroundColor: colors.surfaceVariant.withOpacity(.45),
              side: BorderSide(
                color: taskFilterIndex == index ? Colors.transparent : colors.outlineVariant.withOpacity(.55),
              ),
              onSelected: (_) => setState(() => taskFilterIndex = index),
            ),
            if (index != labels.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget taskGroup(String title, List<TaskListItem> items, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary, size: 18),
              const SizedBox(width: 6),
              Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(width: 6),
              Text('${items.length}', style: muted()),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in items) taskLine(item),
        ],
      ),
    );
  }

  Widget taskLine(TaskListItem item) {
    final task = item.task;
    final deleting = deletingTaskId == task.taskId;
    final statusColor = statusColorFor(task.status);
    final priorityColor = priorityColorFor(task.priority);
    final double? progress = task.subtaskCount == 0
        ? null
        : (task.completedSubtaskCount / task.subtaskCount).clamp(0.0, 1.0).toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TaskDetailScreen(
                initialTask: item,
                onTaskChanged: () {
                  refresh();
                  widget.onProjectChanged?.call();
                },
              ),
            ),
          );
          await refresh();
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.20),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: task.isOverdue
                  ? Theme.of(context).colorScheme.error.withOpacity(.30)
                  : Theme.of(context).colorScheme.outlineVariant.withOpacity(.45),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(task.title, style: bold(), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            taskBadge(task.status.label, statusColor),
                            taskBadge(task.priority.label, priorityColor),
                            taskBadge(
                              task.dueDateLabel,
                              task.isOverdue
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            if (task.subtaskCount > 0)
                              taskBadge(
                                '${task.completedSubtaskCount}/${task.subtaskCount} subtasks',
                                Theme.of(context).colorScheme.tertiary,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (deleting)
                    const Padding(
                      padding: EdgeInsets.only(left: 8, top: 4),
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else
                    IconButton(
                      onPressed: () => deleteTask(item),
                      icon: const Icon(Icons.delete_outline_rounded),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              if (progress != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(value: progress, minHeight: 5, color: statusColor),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> deleteTask(TaskListItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('Delete "${item.task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => deletingTaskId = item.task.taskId);
    try {
      await tasksApi.deleteTask(project: item.project, taskId: item.task.taskId);
      if (!mounted) return;
      setState(() {
        tasks.removeWhere((task) => task.task.taskId == item.task.taskId);
        deletingTaskId = null;
      });
      widget.onProjectChanged?.call();
    } catch (_) {
      if (!mounted) return;
      setState(() => deletingTaskId = null);
      snack('Could not delete task.');
    }
  }

  Widget comingSoonCard(String title, String subtitle) {
    return section(title, subtitle, Icons.auto_awesome_rounded, Text(subtitle, style: muted()));
  }

  Widget membersCard() {
    return section(
      'Members',
      '${members.length} connected',
      Icons.groups_rounded,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final member in members)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(child: Text(member.initials)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(member.displayName, style: bold()),
                        Text(member.email ?? member.roleLabel, style: muted()),
                      ],
                    ),
                  ),
                  Chip(label: Text(member.roleLabel)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget section(String title, String subtitle, IconData icon, Widget child) {
    final colors = Theme.of(context).colorScheme;
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: colors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    Text(subtitle, style: muted()),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget card(Widget child) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant.withOpacity(.55)),
        boxShadow: [
          BoxShadow(color: colors.shadow.withOpacity(.04), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }

  Widget stat(String label, String value, IconData icon) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withOpacity(.50)),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.primary, size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, height: 1)),
                Text(label, style: muted(), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget miniStat(String label, String value, IconData icon) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withOpacity(.10)),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.primary, size: 17),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, height: 1)),
                Text(label, style: muted(), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget taskBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget emptyState(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.25),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: bold()),
          const SizedBox(height: 4),
          Text(subtitle, style: muted()),
        ],
      ),
    );
  }

  Widget messageBox(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withOpacity(.35),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(value),
    );
  }

  TextStyle? muted() {
    return Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          height: 1.35,
        );
  }

  TextStyle? bold() => Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900);

  Color statusColorFor(TaskStatus status) {
    final colors = Theme.of(context).colorScheme;
    switch (status) {
      case TaskStatus.todo:
        return colors.primary;
      case TaskStatus.inProgress:
        return Colors.blue;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.blocked:
        return colors.error;
    }
  }

  Color priorityColorFor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.green;
      case TaskPriority.medium:
        return Colors.blue;
      case TaskPriority.high:
        return Colors.orange;
    }
  }
}
