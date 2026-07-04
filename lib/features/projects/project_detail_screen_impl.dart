import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
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
  bool loading = true;
  String? error;
  int taskFilter = 0;
  int? deletingTaskId;
  List<TaskListItem> tasks = [];
  List<ProjectMemberModel> members = [];

  RiskAnalysisPreviewModel? riskPreview;
  SmartSchedulePreviewModel? schedulePreview;
  List<AiPlanHistoryModel> aiPlanHistory = [];

  bool analyzingRisk = false;
  bool loadingSchedule = false;
  bool applyingSchedule = false;

  bool requestingReport = false;
  bool openingReport = false;

  String? reportStatus;
  String? reportReason;
  String? reportMessage;
  String? latestReportDate;

  List<ProjectActivityModel> activities = [];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<T?> safeLoad<T>(Future<T> Function() loader, String name) async {
    try {
      return await loader();
    } catch (error, stackTrace) {
      debugPrint('$name load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Map<String, dynamic> asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  List<dynamic> asList(dynamic value) {
    if (value is List) {
      return value;
    }

    return const <dynamic>[];
  }

  String mapString(
    Map<String, dynamic> map,
    String key, {
    String fallback = '',
  }) {
    final value = map[key];

    if (value == null) {
      return fallback;
    }

    return value.toString();
  }

  Future<void> refresh() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final loadedProject = await widget.projectsApi.getProject(project);

      final loadedTasks = await widget.tasksApi.getProjectTasks(
        project: TaskProjectSummary.fromProject(loadedProject),
      );

      final loadedMembers = await widget.projectsApi.getProjectMembers(
        loadedProject,
      );

      final loadedRisk = await safeLoad<RiskAnalysisPreviewModel>(
        () => widget.insightsApi.previewRisk(loadedProject.projectId),
        'Risk analysis',
      );

      final loadedPlanHistory = await safeLoad<List<AiPlanHistoryModel>>(
        () => widget.insightsApi.getAiPlanHistory(loadedProject),
        'AI plan history',
      );

      final loadedActivities = await safeLoad<List<ProjectActivityModel>>(
        () => widget.insightsApi.getProjectActivity(
          projectId: loadedProject.projectId,
          limit: 8,
        ),
        'Project activity',
      );

      String? loadedReportStatus;
      String? loadedReportReason;
      String? loadedReportDate;

      try {
        final requestsData = await ApiClient.get(
          '/reports/requests/me',
          queryParameters: {'project_id': loadedProject.projectId},
        );

        final requestItems = asList(asMap(requestsData)['items']);

        if (requestItems.isNotEmpty) {
          final latestRequest = asMap(requestItems.first);

          loadedReportStatus = mapString(latestRequest, 'status');

          loadedReportReason = mapString(latestRequest, 'rejection_reason');

          loadedReportDate = mapString(latestRequest, 'resolved_at');
        }
      } catch (err, stackTrace) {
        debugPrint('Report request status load failed: $err');
        debugPrintStack(stackTrace: stackTrace);
      }

      try {
        final exportsData = await ApiClient.get(
          '/reports/projects/${loadedProject.projectId}/exports',
          queryParameters: {'limit': 1, 'offset': 0},
        );

        final exportItems = asList(asMap(exportsData)['items']);

        if (exportItems.isNotEmpty &&
            loadedReportStatus != 'pending' &&
            loadedReportStatus != 'rejected') {
          loadedReportStatus = 'ready';

          loadedReportDate ??= mapString(
            asMap(exportItems.first),
            'created_at',
          );
        }
      } catch (err, stackTrace) {
        debugPrint('Report exports load failed: $err');
        debugPrintStack(stackTrace: stackTrace);
      }

      if (!mounted) return;

      setState(() {
        project = loadedProject;
        tasks = loadedTasks;
        members = loadedMembers;

        riskPreview = loadedRisk;
        aiPlanHistory = loadedPlanHistory ?? <AiPlanHistoryModel>[];

        activities = loadedActivities ?? <ProjectActivityModel>[];

        reportStatus = loadedReportStatus;
        reportReason = loadedReportReason;
        latestReportDate = loadedReportDate;

        loading = false;
      });
    } catch (err, stackTrace) {
      debugPrint('Project details load failed: $err');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        loading = false;
        error = 'Could not load project details.';
      });
    }
  }

  int get doneTasks => tasks.where((item) => item.task.isCompleted).length;
  int get activeTasks => tasks.where((item) => !item.task.isCompleted).length;
  int get overdueTasks => tasks.where((item) => item.task.isOverdue).length;

  double get completionPercent {
    if (tasks.isEmpty) return project.isCompleted ? 100 : 0;
    return (doneTasks / tasks.length) * 100;
  }

  List<TaskListItem> get visibleTasks {
    final result = tasks.where((item) {
      final task = item.task;
      switch (taskFilter) {
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

    result.sort((a, b) {
      if (a.task.isCompleted != b.task.isCompleted) {
        return a.task.isCompleted ? 1 : -1;
      }
      if (a.task.isOverdue != b.task.isOverdue) {
        return a.task.isOverdue ? -1 : 1;
      }
      return a.task.title.compareTo(b.task.title);
    });

    return result;
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
              topBar(),
              if (loading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: pageX),
                  child: LinearProgressIndicator(
                    key: const Key('project_detail_loading'),
                    minHeight: 2,
                    borderRadius: BorderRadius.circular(999),
                  ),
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
                    page([
                      overviewCard(),
                      statsGrid(),
                      if (members.isNotEmpty) membersCard(),
                    ]),
                    page([tasksCard()]),
                    page([
                      riskAnalysisCard(),
                      smartScheduleCard(),
                      aiPlanHistoryCard(),
                    ]),
                    page([activityTimelineCard(), reportsCard()]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget topBar() {
    return Padding(
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
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            onPressed: loading ? null : refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
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
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
        indicator: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(key: Key('project_tasks_tab'), text: 'Tasks'),
          Tab(text: 'AI Tools'),
          Tab(text: 'Reports'),
        ],
      ),
    );
  }

  Widget page(List<Widget> children) {
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(pageX, 4, pageX, 24),
        itemBuilder: (_, index) => children[index],
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemCount: children.length,
      ),
    );
  }

  Widget overviewCard() {
    final colors = Theme.of(context).colorScheme;
    final progress = completionPercent.clamp(0, 100).toDouble();
    final description = (project.description ?? '')
        .replaceFirst('AI planning brief', '')
        .trim();

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
                child: Icon(
                  project.isTeamProject
                      ? Icons.groups_2_rounded
                      : Icons.folder_rounded,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${project.statusLabel} • ${project.projectTypeLabel} • ${project.deadlineLabel}',
                      style: muted(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(description, style: muted()),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text('${progress.round()}% complete', style: bold()),
              const Spacer(),
              Text('$doneTasks/${tasks.length} tasks', style: muted()),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: progress / 100, minHeight: 8),
          ),
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
        statTile('Tasks', '${tasks.length}', Icons.list_alt_rounded),
        statTile('Completed', '$doneTasks', Icons.check_circle_rounded),
        statTile('Overdue', '$overdueTasks', Icons.timer_off_rounded),
        statTile('Members', '${members.length}', Icons.groups_rounded),
      ],
    );
  }

  Widget tasksCard() {
    final visible = visibleTasks;
    final todo = visible
        .where((item) => item.task.status == TaskStatus.todo)
        .toList();
    final inProgress = visible
        .where((item) => item.task.status == TaskStatus.inProgress)
        .toList();
    final blocked = visible
        .where((item) => item.task.status == TaskStatus.blocked)
        .toList();
    final completed = visible
        .where((item) => item.task.status == TaskStatus.completed)
        .toList();

    return sectionCard(
      'Project Tasks',
      '${visible.length} showing • $activeTasks active • $overdueTasks overdue',
      Icons.task_alt_rounded,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          taskSummary(),
          const SizedBox(height: 12),
          taskFilters(),
          const SizedBox(height: 14),
          if (tasks.isEmpty)
            emptyState(
              'No tasks in this project yet.',
              'Generate a plan or add tasks from the main Tasks screen.',
            )
          else if (visible.isEmpty)
            emptyState(
              'No tasks match this filter.',
              'Try another filter above.',
            )
          else ...[
            if (todo.isNotEmpty)
              taskGroup('To Do', todo, Icons.radio_button_unchecked_rounded),
            if (inProgress.isNotEmpty)
              taskGroup('In Progress', inProgress, Icons.timelapse_rounded),
            if (blocked.isNotEmpty)
              taskGroup('Blocked', blocked, Icons.block_rounded),
            if (completed.isNotEmpty)
              taskGroup('Completed', completed, Icons.check_circle_rounded),
          ],
        ],
      ),
    );
  }

  Widget taskSummary() {
    return Row(
      children: [
        Expanded(child: miniStat('All', '${tasks.length}')),
        const SizedBox(width: 8),
        Expanded(child: miniStat('Active', '$activeTasks')),
        const SizedBox(width: 8),
        Expanded(child: miniStat('Done', '$doneTasks')),
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
              selected: taskFilter == index,
              label: Text(labels[index]),
              selectedColor: colors.primary,
              backgroundColor: colors.surfaceVariant.withOpacity(.45),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w900,
                color: taskFilter == index
                    ? colors.onPrimary
                    : colors.onSurfaceVariant,
              ),
              onSelected: (_) => setState(() => taskFilter = index),
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
              Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 6),
              Text('${items.length}', style: muted()),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in items) taskTile(item),
        ],
      ),
    );
  }

  Widget taskTile(TaskListItem item) {
    final task = item.task;
    final status = statusColor(task.status);
    final priority = priorityColor(task.priority);
    final deleting = deletingTaskId == task.taskId;
    final double? progress = task.subtaskCount == 0
        ? null
        : (task.completedSubtaskCount / task.subtaskCount)
              .clamp(0.0, 1.0)
              .toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        key: const Key('task_card'),
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
            color: Theme.of(
              context,
            ).colorScheme.surfaceVariant.withOpacity(.20),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: task.isOverdue
                  ? Theme.of(context).colorScheme.error.withOpacity(.30)
                  : Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withOpacity(.45),
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
                    decoration: BoxDecoration(
                      color: status,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: bold(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            badge(task.status.label, status),
                            badge(task.priority.label, priority),
                            badge(
                              task.dueDateLabel,
                              task.isOverdue
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            if (task.subtaskCount > 0)
                              badge(
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
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
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
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    color: status,
                  ),
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
      await widget.tasksApi.deleteTask(
        project: item.project,
        taskId: item.task.taskId,
      );
      if (!mounted) return;
      setState(() {
        tasks.removeWhere(
          (taskItem) => taskItem.task.taskId == item.task.taskId,
        );
        deletingTaskId = null;
      });
      widget.onProjectChanged?.call();
    } catch (_) {
      if (!mounted) return;
      setState(() => deletingTaskId = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not delete task.')));
    }
  }

  Future<void> analyzeRisk() async {
    if (analyzingRisk) return;

    setState(() => analyzingRisk = true);

    try {
      final result = await widget.insightsApi.previewRisk(project.projectId);

      if (!mounted) return;

      setState(() {
        riskPreview = result;
        analyzingRisk = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Risk analysis failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() => analyzingRisk = false);
      showProjectMessage('Could not analyze project risk.');
    }
  }

  Future<void> previewSmartSchedule() async {
    if (loadingSchedule) return;

    setState(() => loadingSchedule = true);

    try {
      final result = await widget.insightsApi.previewSmartSchedule(
        project: project,
      );

      if (!mounted) return;

      setState(() {
        schedulePreview = result;
        loadingSchedule = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Smart schedule preview failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() => loadingSchedule = false);
      showProjectMessage('Could not generate a schedule preview.');
    }
  }

  Future<void> applySmartSchedule() async {
    if (applyingSchedule || schedulePreview == null) return;

    setState(() => applyingSchedule = true);

    try {
      await widget.insightsApi.applySmartSchedule(project: project);

      if (!mounted) return;

      setState(() => applyingSchedule = false);

      showProjectMessage('Smart schedule applied successfully.');

      await refresh();
      widget.onProjectChanged?.call();
    } catch (error, stackTrace) {
      debugPrint('Smart schedule apply failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() => applyingSchedule = false);
      showProjectMessage('Could not apply the smart schedule.');
    }
  }

  void showProjectMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget riskAnalysisCard() {
    final risk = riskPreview;
    final color = riskColor(risk?.riskLevel);

    return sectionCard(
      'Risk Analysis',
      risk == null
          ? 'Analyze the current project status'
          : '${risk.riskLevel.toUpperCase()} risk',
      Icons.warning_amber_rounded,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (risk == null)
            emptyState(
              'No risk analysis available.',
              'Analyze the project to check deadlines, workload, blocked tasks, and overdue work.',
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                badge('${risk.predictedDelayDays} predicted delay days', color),
                badge('${risk.daysUntilDeadline} days remaining', color),
                badge('${risk.overdueTasks} overdue', color),
                badge('${risk.blockedTasks} blocked', color),
              ],
            ),
            const SizedBox(height: 14),
            Text(risk.reason, style: muted()),
            if (risk.recommendation.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Recommendation: ${risk.recommendation}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: miniStat(
                    'Completed',
                    '${risk.completedTasks}/${risk.totalTasks}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: miniStat(
                    'Remaining work',
                    '${risk.remainingEstimatedHours.toStringAsFixed(1)}h',
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: analyzingRisk ? null : analyzeRisk,
            icon: analyzingRisk
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_graph_rounded),
            label: Text(analyzingRisk ? 'Analyzing...' : 'Analyze risk'),
          ),
        ],
      ),
    );
  }

  Widget smartScheduleCard() {
    final preview = schedulePreview;

    return sectionCard(
      'Smart Schedule',
      preview == null
          ? 'Generate optimized task deadlines'
          : '${preview.schedulableTaskCount} tasks can be scheduled',
      Icons.calendar_month_rounded,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (preview == null)
            emptyState(
              'No schedule preview available.',
              'Generate a preview before applying changes to your tasks.',
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: miniStat('Tasks', '${preview.schedulableTaskCount}'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: miniStat(
                    'Estimated work',
                    '${preview.estimatedTotalHours.toStringAsFixed(1)}h',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: miniStat('Warnings', '${preview.warnings.length}'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final task in preview.tasks.take(5))
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceVariant.withOpacity(.25),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: bold(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatProjectDate(task.suggestedDueDate),
                      style: muted(),
                    ),
                  ],
                ),
              ),
            if (preview.warnings.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final warning in preview.warnings.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text('• $warning', style: muted()),
                ),
            ],
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: loadingSchedule ? null : previewSmartSchedule,
                icon: loadingSchedule
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.preview_rounded),
                label: Text(
                  loadingSchedule ? 'Loading...' : 'Preview schedule',
                ),
              ),
              FilledButton.icon(
                onPressed: preview == null || applyingSchedule
                    ? null
                    : applySmartSchedule,
                icon: applyingSchedule
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  applyingSchedule ? 'Applying...' : 'Apply schedule',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget aiPlanHistoryCard() {
    return sectionCard(
      'AI Plan History',
      aiPlanHistory.isEmpty
          ? 'No generated plans yet'
          : '${aiPlanHistory.length} generated plans',
      Icons.auto_awesome_rounded,
      aiPlanHistory.isEmpty
          ? emptyState(
              'No AI plan history.',
              'AI-generated plans for this project will appear here.',
            )
          : Column(
              children: [
                for (final plan in aiPlanHistory.take(6))
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceVariant.withOpacity(.25),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.summary,
                          style: bold(),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${plan.generatedTaskCount} generated tasks • '
                          '${formatProjectDate(plan.createdAt)}',
                          style: muted(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Color riskColor(String? level) {
    switch (level) {
      case 'high':
        return Theme.of(context).colorScheme.error;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String formatProjectDate(DateTime date) {
    final value = date.toLocal();
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');

    return '$day/$month/${value.year}';
  }

  bool get isReportReady => reportStatus == 'ready';

  bool get isReportPending => reportStatus == 'pending';

  bool get isReportRejected => reportStatus == 'rejected';

  Future<void> requestReport() async {
    if (requestingReport) return;

    setState(() {
      requestingReport = true;
      reportMessage = null;
    });

    try {
      await ApiClient.postJson(
        '/reports/projects/${project.projectId}/request',
      );

      if (!mounted) return;

      setState(() {
        requestingReport = false;
        reportStatus = 'pending';
        reportReason = null;
        reportMessage = 'Your request was sent. You can track its status here.';
      });

      showProjectMessage('Report request sent to admin.');
    } catch (err, stackTrace) {
      debugPrint('Report request failed: $err');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        requestingReport = false;
        reportMessage = 'Could not send the report request.';
      });
    }
  }

  Future<void> openLatestReport() async {
    if (openingReport) return;

    setState(() => openingReport = true);

    try {
      final response = await ApiClient.get(
        '/reports/projects/${project.projectId}/latest',
      );

      final report = ProjectReportModel.fromJson(asMap(response));

      if (!mounted) return;

      setState(() => openingReport = false);

      showReportSheet(report);
    } catch (err, stackTrace) {
      debugPrint('Latest report load failed: $err');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() => openingReport = false);

      showProjectMessage('Could not open the latest approved report.');
    }
  }

  void showReportSheet(ProjectReportModel report) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: [
                Text(
                  report.project.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  'Generated ${formatProjectDate(report.generatedAt)}',
                  style: muted(),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: miniStat(
                        'Progress',
                        '${report.progress.completionPercentage.round()}%',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: miniStat(
                        'Completed',
                        '${report.progress.completedTasks}/${report.progress.totalTasks}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: miniStat(
                        'Overdue',
                        '${report.progress.overdueTasks}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Task status',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    badge(
                      '${report.taskStatusCounts.todo} to do',
                      Theme.of(context).colorScheme.primary,
                    ),
                    badge(
                      '${report.taskStatusCounts.inProgress} in progress',
                      Colors.blue,
                    ),
                    badge(
                      '${report.taskStatusCounts.blocked} blocked',
                      Theme.of(context).colorScheme.error,
                    ),
                    badge(
                      '${report.taskStatusCounts.completed} completed',
                      Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Hours',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: miniStat(
                        'Estimated',
                        '${report.hours.estimatedHoursTotal.toStringAsFixed(1)}h',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: miniStat(
                        'Actual',
                        '${report.hours.actualHoursTotal.toStringAsFixed(1)}h',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Tasks',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                if (report.tasks.isEmpty)
                  emptyState(
                    'No tasks in this report.',
                    'Tasks will appear when they are added to the project.',
                  )
                else
                  for (final task in report.tasks)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceVariant.withOpacity(.25),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(task.title, style: bold()),
                          const SizedBox(height: 5),
                          Text(
                            '${task.status} • ${task.priority}',
                            style: muted(),
                          ),
                        ],
                      ),
                    ),
              ],
            );
          },
        );
      },
    );
  }

  Widget activityTimelineCard() {
    return sectionCard(
      'Activity Timeline',
      activities.isEmpty
          ? 'No recent project activity'
          : '${activities.length} recent events',
      Icons.timeline_rounded,
      activities.isEmpty
          ? emptyState(
              'No activity yet.',
              'Task, comment, attachment, and report activity will appear here.',
            )
          : Column(
              children: [
                for (final activity in activities)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 9),
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceVariant.withOpacity(.22),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 17,
                          child: Icon(
                            reportActivityIcon(activity.eventType),
                            size: 17,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activity.message.trim().isEmpty
                                    ? activity.eventType.replaceAll('_', ' ')
                                    : activity.message,
                                style: bold(),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${activity.actorLabel} • '
                                '${formatProjectDate(activity.createdAt)}',
                                style: muted(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget reportsCard() {
    final colors = Theme.of(context).colorScheme;

    final Color tone;

    if (isReportReady) {
      tone = Colors.green;
    } else if (isReportRejected) {
      tone = colors.error;
    } else if (isReportPending) {
      tone = Colors.orange;
    } else {
      tone = colors.primary;
    }

    final String statusText;

    if (isReportReady) {
      statusText = 'Ready';
    } else if (isReportRejected) {
      statusText = 'Rejected';
    } else if (isReportPending) {
      statusText = 'Pending admin review';
    } else {
      statusText = 'No request yet';
    }

    return sectionCard(
      'Project Reports',
      statusText,
      Icons.description_rounded,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tone.withOpacity(.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tone.withOpacity(.20)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isReportReady
                      ? Icons.verified_rounded
                      : isReportRejected
                      ? Icons.cancel_rounded
                      : isReportPending
                      ? Icons.hourglass_top_rounded
                      : Icons.admin_panel_settings_rounded,
                  color: tone,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isReportReady
                        ? 'Your approved project report is ready to view inside Planora.'
                        : isReportRejected
                        ? 'The admin rejected this report request.'
                        : isReportPending
                        ? 'Your report request is waiting for admin review.'
                        : 'Request a project report from the Planora administrators.',
                    style: muted(),
                  ),
                ),
              ],
            ),
          ),
          if (isReportRejected && (reportReason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Reason: $reportReason',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.error,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          if (isReportReady && (latestReportDate ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Latest report: $latestReportDate', style: muted()),
          ],
          const SizedBox(height: 14),
          if (isReportReady) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: openingReport ? null : openLatestReport,
                icon: openingReport
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.visibility_rounded),
                label: Text(
                  openingReport ? 'Opening report...' : 'View report',
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: requestingReport ? null : requestReport,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Request updated report'),
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: requestingReport || isReportPending
                    ? null
                    : requestReport,
                icon: requestingReport
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        isReportPending
                            ? Icons.hourglass_top_rounded
                            : Icons.mail_outline_rounded,
                      ),
                label: Text(
                  requestingReport
                      ? 'Sending request...'
                      : isReportPending
                      ? 'Waiting for admin'
                      : 'Request report from admin',
                ),
              ),
            ),
          if (reportMessage != null) ...[
            const SizedBox(height: 10),
            Text(reportMessage!, style: muted()),
          ],
        ],
      ),
    );
  }

  IconData reportActivityIcon(String eventType) {
    final value = eventType.toLowerCase();

    if (value.contains('task')) {
      return Icons.task_alt_rounded;
    }

    if (value.contains('comment')) {
      return Icons.chat_bubble_outline_rounded;
    }

    if (value.contains('attachment')) {
      return Icons.attach_file_rounded;
    }

    if (value.contains('report')) {
      return Icons.description_rounded;
    }

    if (value.contains('member')) {
      return Icons.person_add_alt_1_rounded;
    }

    return Icons.bolt_rounded;
  }

  Widget membersCard() {
    return sectionCard(
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

  Widget placeholderCard(String title, String subtitle) {
    return sectionCard(
      title,
      subtitle,
      Icons.auto_awesome_rounded,
      Text(subtitle, style: muted()),
    );
  }

  Widget sectionCard(
    String title,
    String subtitle,
    IconData icon,
    Widget child,
  ) {
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
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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
          BoxShadow(
            color: colors.shadow.withOpacity(.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget statTile(String label, String value, IconData icon) {
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
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                Text(
                  label,
                  style: muted(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget miniStat(String label, String value) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withOpacity(.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          Text(
            label,
            style: muted(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.18)),
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

  TextStyle? bold() => Theme.of(
    context,
  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900);

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
