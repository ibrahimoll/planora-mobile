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

  late ProjectModel project = widget.project;
  List<TaskListItem> tasks = [];
  List<ProjectMemberModel> members = [];
  bool loading = true;
  String? error;
  int filter = 0;

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
      final loadedProject = await widget.projectsApi.getProject(project);
      final loadedTasks = await widget.tasksApi.getProjectTasks(project: TaskProjectSummary.fromProject(loadedProject));
      final loadedMembers = await widget.projectsApi.getProjectMembers(loadedProject);
      if (!mounted) return;
      setState(() {
        project = loadedProject;
        tasks = loadedTasks;
        members = loadedMembers;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Could not load project details.';
      });
    }
  }

  int get done => tasks.where((item) => item.task.isCompleted).length;
  int get active => tasks.where((item) => !item.task.isCompleted).length;
  int get overdue => tasks.where((item) => item.task.isOverdue).length;
  double get percent => tasks.isEmpty ? (project.isCompleted ? 100 : 0) : (done / tasks.length) * 100;

  List<TaskListItem> get visibleTasks {
    final items = tasks.where((item) {
      switch (filter) {
        case 1:
          return !item.task.isCompleted;
        case 2:
          return item.task.isOverdue;
        case 3:
          return item.task.isCompleted;
        default:
          return true;
      }
    }).toList();
    items.sort((a, b) {
      if (a.task.isCompleted != b.task.isCompleted) return a.task.isCompleted ? 1 : -1;
      if (a.task.isOverdue != b.task.isOverdue) return a.task.isOverdue ? -1 : 1;
      return a.task.title.compareTo(b.task.title);
    });
    return items;
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
                    IconButton.filledTonal(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded)),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Project Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                    IconButton(onPressed: loading ? null : refresh, icon: const Icon(Icons.refresh_rounded)),
                  ],
                ),
              ),
              if (loading) Padding(padding: const EdgeInsets.symmetric(horizontal: pageX), child: LinearProgressIndicator(minHeight: 2, borderRadius: BorderRadius.circular(999))),
              if (error != null) Padding(padding: const EdgeInsets.fromLTRB(pageX, 8, pageX, 8), child: errorBox(error!)),
              Container(
                height: 46,
                margin: const EdgeInsets.fromLTRB(pageX, 8, pageX, 10),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: colors.surfaceVariant.withOpacity(.45), borderRadius: BorderRadius.circular(18)),
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: colors.onPrimary,
                  unselectedLabelColor: colors.onSurfaceVariant,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  indicator: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(14)),
                  tabs: const [Tab(text: 'Overview'), Tab(text: 'Tasks'), Tab(text: 'AI Tools'), Tab(text: 'Reports')],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    page([overview(), stats(), if (members.isNotEmpty) memberList()]),
                    page([tasksPanel()]),
                    page([placeholder('AI Tools', 'Risk analysis, smart schedule, and AI plan history will stay here.')]),
                    page([placeholder('Reports', 'Reports and activity timeline will stay here.')]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget page(List<Widget> children) => RefreshIndicator(
        onRefresh: refresh,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(pageX, 4, pageX, 24),
          itemBuilder: (_, index) => children[index],
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemCount: children.length,
        ),
      );

  Widget overview() {
    final colors = Theme.of(context).colorScheme;
    final progress = percent.clamp(0, 100).toDouble();
    final description = (project.description ?? '').trim();
    return card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: colors.primary.withOpacity(.12), borderRadius: BorderRadius.circular(15)), child: Icon(project.isTeamProject ? Icons.groups_2_rounded : Icons.folder_rounded, color: colors.primary)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(project.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text('${project.statusLabel} • ${project.projectTypeLabel} • ${project.deadlineLabel}', style: muted())])),
      ]),
      if (description.isNotEmpty) ...[const SizedBox(height: 12), Text(description.replaceFirst('AI planning brief', '').trim(), style: muted())],
      const SizedBox(height: 12),
      Row(children: [Text('${progress.round()}% complete', style: bold()), const Spacer(), Text('$done/${tasks.length} tasks', style: muted())]),
      const SizedBox(height: 8),
      ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: progress / 100, minHeight: 8)),
    ]));
  }

  Widget stats() => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 2.45,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          stat('Tasks', '${tasks.length}', Icons.list_alt_rounded),
          stat('Completed', '$done', Icons.check_circle_rounded),
          stat('Overdue', '$overdue', Icons.timer_off_rounded),
          stat('Members', '${members.length}', Icons.groups_rounded),
        ],
      );

  Widget tasksPanel() {
    final visible = visibleTasks;
    final todo = visible.where((item) => item.task.status == TaskStatus.todo).toList();
    final doing = visible.where((item) => item.task.status == TaskStatus.inProgress).toList();
    final blocked = visible.where((item) => item.task.status == TaskStatus.blocked).toList();
    final completed = visible.where((item) => item.task.status == TaskStatus.completed).toList();
    return section('Project Tasks', '${visible.length} showing • $active active • $overdue overdue', Icons.task_alt_rounded, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: mini('All', '${tasks.length}')), const SizedBox(width: 8), Expanded(child: mini('Active', '$active')), const SizedBox(width: 8), Expanded(child: mini('Done', '$done'))]),
      const SizedBox(height: 12),
      filters(),
      const SizedBox(height: 14),
      if (tasks.isEmpty) empty('No tasks in this project yet.', 'Generate a plan or add tasks from the main Tasks screen.') else if (visible.isEmpty) empty('No tasks match this filter.', 'Try another filter above.') else ...[
        if (todo.isNotEmpty) group('To Do', todo, Icons.radio_button_unchecked_rounded),
        if (doing.isNotEmpty) group('In Progress', doing, Icons.timelapse_rounded),
        if (blocked.isNotEmpty) group('Blocked', blocked, Icons.block_rounded),
        if (completed.isNotEmpty) group('Completed', completed, Icons.check_circle_rounded),
      ],
    ]));
  }

  Widget filters() {
    const labels = ['All', 'Active', 'Overdue', 'Done'];
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [for (var i = 0; i < labels.length; i++) ...[
      ChoiceChip(selected: filter == i, label: Text(labels[i]), selectedColor: colors.primary, backgroundColor: colors.surfaceVariant.withOpacity(.45), labelStyle: TextStyle(fontWeight: FontWeight.w900, color: filter == i ? colors.onPrimary : colors.onSurfaceVariant), onSelected: (_) => setState(() => filter = i)),
      if (i != labels.length - 1) const SizedBox(width: 8),
    ]]));
  }

  Widget group(String title, List<TaskListItem> items, IconData icon) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 6), Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(width: 6), Text('${items.length}', style: muted())]), const SizedBox(height: 8), for (final item in items) taskTile(item)]));

  Widget taskTile(TaskListItem item) {
    final task = item.task;
<<<<<<< HEAD
    final deleting = _deletingTaskId == task.taskId;
    final statusColor = _statusColor(task.status);
    final priorityColor = _priorityColor(task.priority);
    final double? progress = task.subtaskCount == 0 ? null : (task.completedSubtaskCount / task.subtaskCount).clamp(0.0, 1.0).toDouble();

    return Padding(padding: const EdgeInsets.only(bottom: 8), child: InkWell(borderRadius: BorderRadius.circular(18), onTap: () async { await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TaskDetailScreen(initialTask: item, onTaskChanged: () { _refresh(); widget.onProjectChanged?.call(); }))); await _refresh(); }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.20), borderRadius: BorderRadius.circular(18), border: Border.all(color: task.isOverdue ? Theme.of(context).colorScheme.error.withOpacity(.30) : Theme.of(context).colorScheme.outlineVariant.withOpacity(.45))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 5), decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(task.title, style: _bold(), maxLines: 2, overflow: TextOverflow.ellipsis), const SizedBox(height: 4), Wrap(spacing: 6, runSpacing: 6, children: [_taskBadge(task.status.label, statusColor), _taskBadge(task.priority.label, priorityColor), _taskBadge(task.dueDateLabel, task.isOverdue ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary), if (task.subtaskCount > 0) _taskBadge('${task.completedSubtaskCount}/${task.subtaskCount} subtasks', Theme.of(context).colorScheme.tertiary)])])), deleting ? const Padding(padding: EdgeInsets.only(left: 8, top: 4), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))) : IconButton(onPressed: () => _deleteTask(item), icon: const Icon(Icons.delete_outline_rounded), visualDensity: VisualDensity.compact)]), if (progress != null) ...[const SizedBox(height: 10), ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: progress, minHeight: 5, color: statusColor))]])))););
=======
    final color = statusColor(task.status);
    final double? subtaskProgress = task.subtaskCount == 0 ? null : (task.completedSubtaskCount / task.subtaskCount).clamp(0.0, 1.0).toDouble();
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: InkWell(borderRadius: BorderRadius.circular(18), onTap: () async { await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TaskDetailScreen(initialTask: item, onTaskChanged: () { refresh(); widget.onProjectChanged?.call(); }))); await refresh(); }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.20), borderRadius: BorderRadius.circular(18), border: Border.all(color: task.isOverdue ? Theme.of(context).colorScheme.error.withOpacity(.30) : Theme.of(context).colorScheme.outlineVariant.withOpacity(.45))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 5), decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(task.title, style: bold(), maxLines: 2, overflow: TextOverflow.ellipsis), const SizedBox(height: 4), Wrap(spacing: 6, runSpacing: 6, children: [badge(task.status.label, color), badge(task.priority.label, priorityColor(task.priority)), badge(task.dueDateLabel, task.isOverdue ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary), if (task.subtaskCount > 0) badge('${task.completedSubtaskCount}/${task.subtaskCount} subtasks', Theme.of(context).colorScheme.tertiary)])]))]), if (subtaskProgress != null) ...[const SizedBox(height: 10), ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: subtaskProgress, minHeight: 5, color: color))]])))));
>>>>>>> d3d8f6ceebe98330b066c9d5d42f57929a48f70a
  }

  Widget memberList() => section('Members', '${members.length} connected', Icons.groups_rounded, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final member in members) Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [CircleAvatar(child: Text(member.initials)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(member.displayName, style: bold()), Text(member.email ?? member.roleLabel, style: muted())])), Chip(label: Text(member.roleLabel))]))]));

  Widget placeholder(String title, String subtitle) => section(title, subtitle, Icons.auto_awesome_rounded, Text(subtitle, style: muted()));

  Widget section(String title, String subtitle, IconData icon, Widget child) => card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(.10), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)), Text(subtitle, style: muted())]))]), const SizedBox(height: 14), child]));

  Widget card(Widget child) => Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(.55)), boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.shadow.withOpacity(.04), blurRadius: 18, offset: const Offset(0, 8))]), child: child);

  Widget stat(String label, String value, IconData icon) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(.50))), child: Row(children: [Icon(icon, color: Theme.of(context).colorScheme.primary, size: 21), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, height: 1)), Text(label, style: muted(), maxLines: 1, overflow: TextOverflow.ellipsis)]))]));

  Widget mini(String label, String value) => Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(.10))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, height: 1)), Text(label, style: muted(), maxLines: 1, overflow: TextOverflow.ellipsis)]));

  Widget badge(String label, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(.18))), child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w900)));

  Widget empty(String title, String subtitle) => Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.25), borderRadius: BorderRadius.circular(18)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: bold()), const SizedBox(height: 4), Text(subtitle, style: muted())]));

  Widget errorBox(String value) => Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer.withOpacity(.35), borderRadius: BorderRadius.circular(18)), child: Text(value));

  TextStyle? muted() => Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700, height: 1.35);
  TextStyle? bold() => Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900);

  Color statusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return Theme.of(context).colorScheme.primary;
      case TaskStatus.inProgress:
        return Colors.blue;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.blocked:
        return Theme.of(context).colorScheme.error;
    }
  }

  Color priorityColor(TaskPriority priority) {
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
