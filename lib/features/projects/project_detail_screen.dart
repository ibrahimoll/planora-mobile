import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
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
  late final ProjectsApi projectsApi = widget.projectsApi;
  late final TasksApi tasksApi = widget.tasksApi;
  late final ProjectInsightsApi insightsApi = widget.insightsApi;
  late ProjectModel project = widget.project;

  bool loading = true;
  bool savingRisk = false;
  bool previewingSchedule = false;
  bool applyingSchedule = false;
  bool requestingReport = false;
  bool openingReport = false;
  bool inviting = false;
  int? deletingTaskId;
  String? error;
  String? reportStatus;
  String? reportReason;
  String? reportDate;
  String? message;

  List<TaskListItem> tasks = [];
  List<ProjectMemberModel> members = [];
  List<ProjectActivityModel> activities = [];
  List<Map<String, dynamic>> riskHistory = [];
  List<AiPlanHistoryModel> aiPlans = [];
  ProjectProgressModel? progress;
  RiskAnalysisPreviewModel? risk;
  SmartSchedulePreviewModel? schedule;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Map<String, dynamic> asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<dynamic> asList(dynamic value) => value is List ? value : const <dynamic>[];

  String textValue(Map<String, dynamic> map, String key, {String fallback = ''}) {
    final value = map[key];
    return value == null ? fallback : value.toString();
  }

  num numValue(Map<String, dynamic> map, String key, {num fallback = 0}) {
    final value = map[key];
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? fallback;
    return fallback;
  }

  String friendlyError(Object err, String fallback) {
    if (err is ApiException && err.message.trim().isNotEmpty) return err.message;
    return fallback;
  }

  void snack(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<List<Map<String, dynamic>>> loadRiskHistory(int projectId) async {
    final response = await ApiClient.get('/projects/$projectId/risk-analysis');
    return asList(response).map(asMap).where((item) => item.isNotEmpty).toList();
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

      ProjectProgressModel? loadedProgress;
      RiskAnalysisPreviewModel? loadedRisk;
      List<Map<String, dynamic>> loadedRiskHistory = const [];
      List<ProjectActivityModel> loadedActivities = const [];
      List<AiPlanHistoryModel> loadedPlans = const [];
      String? loadedReportStatus;
      String? loadedReportReason;
      String? loadedReportDate;

      try {
        loadedProgress = await insightsApi.getProjectProgress(loadedProject.projectId);
      } catch (err) {
        debugPrint('Progress load failed: $err');
      }
      try {
        loadedRisk = await insightsApi.previewRisk(loadedProject.projectId);
      } catch (err) {
        debugPrint('Risk preview load failed: $err');
      }
      try {
        loadedRiskHistory = await loadRiskHistory(loadedProject.projectId);
      } catch (err) {
        debugPrint('Risk history load failed: $err');
      }
      try {
        loadedActivities = await insightsApi.getProjectActivity(projectId: loadedProject.projectId, limit: 8);
      } catch (err) {
        debugPrint('Activity load failed: $err');
      }
      try {
        loadedPlans = await insightsApi.getAiPlanHistory(loadedProject);
      } catch (err) {
        debugPrint('AI plan history load failed: $err');
      }
      try {
        final data = await ApiClient.get(
          '/reports/requests/me',
          queryParameters: {'project_id': loadedProject.projectId},
        );
        final items = asList(asMap(data)['items']);
        if (items.isNotEmpty) {
          final latest = asMap(items.first);
          loadedReportStatus = textValue(latest, 'status');
          loadedReportReason = textValue(latest, 'rejection_reason');
          loadedReportDate = textValue(latest, 'resolved_at');
        }
      } catch (err) {
        debugPrint('Report request status failed: $err');
      }
      try {
        final exports = await ApiClient.get(
          '/reports/projects/${loadedProject.projectId}/exports',
          queryParameters: {'limit': 1, 'offset': 0},
        );
        final items = asList(asMap(exports)['items']);
        if (items.isNotEmpty && loadedReportStatus != 'pending' && loadedReportStatus != 'rejected') {
          loadedReportStatus = 'ready';
          loadedReportDate ??= textValue(asMap(items.first), 'created_at');
        }
      } catch (err) {
        debugPrint('Report export status failed: $err');
      }

      if (!mounted) return;
      setState(() {
        project = loadedProject;
        tasks = loadedTasks;
        members = loadedMembers;
        progress = loadedProgress;
        risk = loadedRisk;
        riskHistory = loadedRiskHistory;
        activities = loadedActivities;
        aiPlans = loadedPlans;
        reportStatus = loadedReportStatus;
        reportReason = loadedReportReason;
        reportDate = loadedReportDate;
        loading = false;
      });
    } catch (err, stackTrace) {
      debugPrint('Project details refresh failed: $err');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        loading = false;
        error = friendlyError(err, 'Could not load project details.');
      });
    }
  }

  Future<void> saveRiskAnalysis() async {
    if (savingRisk) return;
    setState(() => savingRisk = true);
    try {
      await ApiClient.postJson('/projects/${project.projectId}/risk-analysis');
      final nextRisk = await insightsApi.previewRisk(project.projectId);
      final nextHistory = await loadRiskHistory(project.projectId);
      if (!mounted) return;
      setState(() {
        risk = nextRisk;
        riskHistory = nextHistory;
        savingRisk = false;
      });
      snack('Risk analysis saved.');
    } catch (err, stackTrace) {
      debugPrint('Risk save failed: $err');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => savingRisk = false);
      snack(friendlyError(err, 'Could not save risk analysis.'));
    }
  }

  Future<void> previewSmartSchedule() async {
    if (previewingSchedule) return;
    setState(() {
      previewingSchedule = true;
      message = null;
    });
    try {
      final preview = await insightsApi.previewSmartSchedule(project: project);
      if (!mounted) return;
      setState(() {
        schedule = preview;
        previewingSchedule = false;
        message = preview.tasks.isEmpty
            ? 'No schedulable tasks found.'
            : 'Preview ready for ${preview.schedulableTaskCount} task(s).';
      });
    } catch (err, stackTrace) {
      debugPrint('Schedule preview failed: $err');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        previewingSchedule = false;
        message = friendlyError(err, 'Could not preview schedule.');
      });
    }
  }

  Future<void> applySmartSchedule() async {
    if (applyingSchedule || schedule == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apply smart schedule?'),
        content: const Text('This will update task due dates using the previewed schedule.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Apply')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => applyingSchedule = true);
    try {
      await insightsApi.applySmartSchedule(project: project);
      if (!mounted) return;
      setState(() {
        applyingSchedule = false;
        schedule = null;
        message = 'Smart schedule applied.';
      });
      widget.onProjectChanged?.call();
      await refresh();
      snack('Smart schedule applied.');
    } catch (err, stackTrace) {
      debugPrint('Schedule apply failed: $err');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        applyingSchedule = false;
        message = friendlyError(err, 'Could not apply smart schedule.');
      });
    }
  }

  Future<void> requestReport() async {
    if (requestingReport) return;
    setState(() => requestingReport = true);
    try {
      await ApiClient.postJson('/reports/projects/${project.projectId}/request');
      if (!mounted) return;
      setState(() {
        requestingReport = false;
        reportStatus = 'pending';
      });
      snack('Report request sent to admin.');
    } catch (err, stackTrace) {
      debugPrint('Report request failed: $err');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => requestingReport = false);
      snack(friendlyError(err, 'Could not send report request.'));
    }
  }

  Future<void> openLatestReport() async {
    if (openingReport) return;
    setState(() => openingReport = true);
    try {
      final data = await ApiClient.get('/reports/projects/${project.projectId}/latest');
      if (!mounted) return;
      setState(() => openingReport = false);
      showReportSheet(asMap(data));
    } catch (err, stackTrace) {
      debugPrint('Open report failed: $err');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => openingReport = false);
      snack(friendlyError(err, 'Could not open report.'));
    }
  }

  Future<void> inviteMember(String emailOrUsername, String role) async {
    final value = emailOrUsername.trim();
    if (value.isEmpty || inviting) return;
    setState(() => inviting = true);
    try {
      if (!project.isTeamProject && members.length <= 1) {
        project = await projectsApi.invitePersonalProjectMemberAndConvert(
          project: project,
          emailOrUsername: value,
          role: role,
        );
      } else {
        await projectsApi.inviteProjectMember(project: project, emailOrUsername: value, role: role);
      }
      if (!mounted) return;
      setState(() => inviting = false);
      snack('Invitation sent.');
      await refresh();
      widget.onProjectChanged?.call();
    } catch (err, stackTrace) {
      debugPrint('Invite failed: $err');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => inviting = false);
      snack(friendlyError(err, 'Could not invite this person.'));
    }
  }

  Future<void> removeTask(TaskListItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('Delete "${item.task.title}" from this project?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete'),
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
        tasks.removeWhere((taskItem) => taskItem.task.taskId == item.task.taskId);
        deletingTaskId = null;
      });
      widget.onProjectChanged?.call();
      snack('Task deleted.');
    } catch (err, stackTrace) {
      debugPrint('Task delete failed: $err');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => deletingTaskId = null);
      snack(friendlyError(err, 'Could not delete task.'));
    }
  }

  double get completionPercent {
    if (progress != null) return progress!.project.completionPercentage;
    if (tasks.isEmpty) return project.isCompleted ? 100 : 0;
    return (tasks.where((item) => item.task.isCompleted).length / tasks.length) * 100;
  }

  int get doneTasks => tasks.where((item) => item.task.isCompleted).length;
  int get overdueTasks => tasks.where((item) => item.task.isOverdue).length;
  bool get isReportReady => reportStatus == 'ready';
  bool get isReportPending => reportStatus == 'pending';
  bool get isReportRejected => reportStatus == 'rejected';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            children: [
              topBar(context),
              const SizedBox(height: 16),
              if (error != null) ...[messageBox(context, error!, isError: true), const SizedBox(height: 12)],
              projectCard(context),
              const SizedBox(height: 12),
              statsGrid(context),
              const SizedBox(height: 12),
              riskCard(context),
              const SizedBox(height: 12),
              smartScheduleCard(context),
              const SizedBox(height: 12),
              aiPlanHistoryCard(context),
              const SizedBox(height: 12),
              activityCard(context),
              const SizedBox(height: 12),
              reportCard(context),
              const SizedBox(height: 12),
              tasksCard(context),
              const SizedBox(height: 12),
              membersCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget topBar(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded)),
        const SizedBox(width: 8),
        Expanded(child: Text('Project Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
        IconButton(
          onPressed: loading ? null : refresh,
          icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget projectCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final percent = completionPercent.clamp(0, 100);
    return card(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: colors.primary.withOpacity(.12),
                child: Icon(project.isTeamProject ? Icons.groups_2_rounded : Icons.folder_rounded, color: colors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    Text('${project.statusLabel} • ${project.projectTypeLabel} • ${project.deadlineLabel}', style: smallMuted(context)),
                  ],
                ),
              ),
            ],
          ),
          if ((project.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(project.description!.trim(), style: smallMuted(context)),
          ],
          const SizedBox(height: 14),
          Text('${percent.round()}% complete', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: percent / 100, minHeight: 8),
        ],
      ),
    );
  }

  Widget statsGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.75,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        statTile(context, 'Tasks', '${tasks.length}', Icons.list_alt_rounded),
        statTile(context, 'Completed', '$doneTasks', Icons.check_circle_rounded),
        statTile(context, 'Overdue', '$overdueTasks', Icons.timer_off_rounded),
        statTile(context, 'Members', '${members.length}', Icons.groups_rounded),
      ],
    );
  }

  Widget riskCard(BuildContext context) {
    final latestSaved = riskHistory.isNotEmpty ? riskHistory.first : null;
    final riskLevel = risk?.riskLevel ?? textValue(latestSaved ?? const <String, dynamic>{}, 'risk_level', fallback: 'unknown');
    final riskColor = colorForRisk(context, riskLevel);
    return section(
      context,
      title: 'Risk Analysis',
      subtitle: riskLevel == 'unknown' ? 'Not analyzed yet' : '${riskLevel.toUpperCase()} risk',
      icon: Icons.warning_amber_rounded,
      trailing: TextButton.icon(
        onPressed: savingRisk ? null : saveRiskAnalysis,
        icon: savingRisk ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_as_rounded, size: 18),
        label: Text(savingRisk ? 'Saving' : 'Analyze'),
      ),
      child: risk == null && latestSaved == null
          ? emptyText(context, 'No saved risk analysis yet. Tap Analyze to save one and notify members if risk is high.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (latestSaved != null) banner(context, Icons.verified_rounded, 'Latest saved • ${formatDateText(textValue(latestSaved, 'created_at'))}', riskColor),
                if (latestSaved != null) const SizedBox(height: 10),
                if (risk != null) ...[
                  banner(context, Icons.shield_rounded, '${risk!.predictedDelayDays} predicted delay days • ${risk!.daysUntilDeadline} days until deadline', riskColor),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      pill(context, 'Overdue', '${risk!.overdueTasks}'),
                      pill(context, 'Blocked', '${risk!.blockedTasks}'),
                      pill(context, 'Remaining', '${risk!.remainingEstimatedHours.toStringAsFixed(1)}h'),
                      pill(context, 'Done', '${risk!.completedTasks}/${risk!.totalTasks}'),
                    ],
                  ),
                  if (risk!.reason.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(risk!.reason.trim(), style: smallMuted(context))),
                  if (risk!.recommendation.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Recommendation: ${risk!.recommendation.trim()}', style: smallPrimary(context))),
                ],
                if (riskHistory.length > 1) ...[
                  const SizedBox(height: 14),
                  Text('Risk History', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  for (final item in riskHistory.take(4)) historyRow(context, textValue(item, 'risk_level', fallback: 'medium'), '${numValue(item, 'predicted_delay_days').round()} delay day(s) • ${formatDateText(textValue(item, 'created_at'))}'),
                ],
              ],
            ),
    );
  }

  Widget smartScheduleCard(BuildContext context) {
    final preview = schedule;
    return section(
      context,
      title: 'Smart Schedule',
      subtitle: preview == null ? 'Preview better task due dates' : '${preview.schedulableTaskCount} schedulable • ${preview.estimatedTotalHours.toStringAsFixed(1)}h',
      icon: Icons.event_available_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: previewingSchedule ? null : previewSmartSchedule,
                  icon: previewingSchedule ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_motion_rounded),
                  label: Text(previewingSchedule ? 'Previewing...' : 'Preview'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: applyingSchedule || preview == null ? null : applySmartSchedule,
                  icon: applyingSchedule ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.done_all_rounded),
                  label: Text(applyingSchedule ? 'Applying...' : 'Apply'),
                ),
              ),
            ],
          ),
          if (message != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(message!, style: smallMuted(context))),
          if (preview == null) Padding(padding: const EdgeInsets.only(top: 10), child: emptyText(context, 'Preview first, then apply the suggested due dates.')),
          if (preview != null) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              pill(context, 'Capacity', '${preview.dailyCapacityHours.toStringAsFixed(1)}h/day'),
              pill(context, 'Tasks', '${preview.schedulableTaskCount}/${preview.totalTasks}'),
              pill(context, 'Done', '${preview.completedTaskCount}'),
            ]),
            if (preview.warnings.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final warning in preview.warnings.take(2)) Text('Warning: $warning', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w800)),
            ],
            const SizedBox(height: 10),
            for (final item in preview.tasks.take(5)) scheduleTaskRow(context, item),
          ],
        ],
      ),
    );
  }

  Widget aiPlanHistoryCard(BuildContext context) {
    return section(
      context,
      title: 'AI Plan History',
      subtitle: aiPlans.isEmpty ? 'No AI plans yet' : '${aiPlans.length} saved AI plan(s)',
      icon: Icons.auto_awesome_rounded,
      child: aiPlans.isEmpty
          ? emptyText(context, 'Generated AI plans for this project will appear here.')
          : Column(children: [for (final item in aiPlans.take(4)) aiPlanRow(context, item)]),
    );
  }

  Widget aiPlanRow(BuildContext context, AiPlanHistoryModel item) {
    return simpleInkRow(
      context,
      icon: Icons.psychology_alt_rounded,
      title: item.summary,
      subtitle: '${item.generatedTaskCount} generated task(s) • ${formatDateTime(item.createdAt)}',
      onTap: () => showAiPlanSheet(item),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }

  Widget activityCard(BuildContext context) {
    return section(
      context,
      title: 'Activity Timeline',
      subtitle: activities.isEmpty ? 'No recent activity' : '${activities.length} latest event(s)',
      icon: Icons.timeline_rounded,
      child: activities.isEmpty
          ? emptyText(context, 'Project activity will appear here when tasks, comments, attachments, or reports change.')
          : Column(children: [for (final item in activities) activityRow(context, item)]),
    );
  }

  Widget activityRow(BuildContext context, ProjectActivityModel item) {
    return simpleRow(
      context,
      icon: iconForActivity(item.eventType),
      title: item.message.trim().isEmpty ? item.eventType.replaceAll('_', ' ') : item.message.trim(),
      subtitle: '${item.actorLabel} • ${formatDateTime(item.createdAt)}',
    );
  }

  Widget reportCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tone = isReportReady ? Colors.green : isReportRejected ? colors.error : isReportPending ? Colors.orange : colors.primary;
    final subtitle = isReportReady ? 'Ready' : isReportRejected ? 'Rejected' : isReportPending ? 'Pending admin review' : 'No request yet';
    return section(
      context,
      title: 'Reports',
      subtitle: subtitle,
      icon: Icons.description_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        banner(context, isReportReady ? Icons.verified_rounded : isReportRejected ? Icons.cancel_rounded : isReportPending ? Icons.hourglass_top_rounded : Icons.admin_panel_settings_rounded, isReportReady ? 'Report ready. Open it inside Planora.' : isReportRejected ? 'Request rejected. You can request again.' : isReportPending ? 'Waiting for admin review.' : 'Ask admins to prepare a report.', tone),
        if (isReportRejected && (reportReason ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Reason: $reportReason', style: TextStyle(color: colors.error, fontWeight: FontWeight.w800))),
        if (isReportReady && reportDate != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Latest report: $reportDate', style: smallMuted(context))),
        const SizedBox(height: 12),
        if (isReportReady) ...[
          fullButton(context, openingReport ? 'Opening report...' : 'View report in app', openingReport ? null : openLatestReport, Icons.visibility_rounded),
          const SizedBox(height: 8),
          fullOutlineButton(context, 'Request updated report', requestingReport ? null : requestReport, Icons.refresh_rounded),
        ] else
          fullButton(context, requestingReport ? 'Sending request...' : isReportPending ? 'Waiting for admin' : 'Request report from admin', requestingReport || isReportPending ? null : requestReport, isReportPending ? Icons.hourglass_top_rounded : Icons.mail_outline_rounded),
      ]),
    );
  }

  Widget tasksCard(BuildContext context) {
    return section(
      context,
      title: 'Project Tasks',
      subtitle: 'Open or delete project tasks directly',
      icon: Icons.task_alt_rounded,
      child: tasks.isEmpty ? emptyText(context, 'No tasks in this project yet.') : Column(children: [for (final item in tasks.take(8)) taskRow(context, item)]),
    );
  }

  Widget membersCard(BuildContext context) {
    return section(
      context,
      title: project.isTeamProject ? 'Members' : 'Collaborators',
      subtitle: 'People connected to this project',
      icon: Icons.groups_rounded,
      trailing: TextButton.icon(onPressed: inviting ? null : showInviteSheet, icon: const Icon(Icons.person_add_alt_1_rounded, size: 18), label: Text(inviting ? 'Inviting' : 'Invite')),
      child: members.isEmpty ? emptyText(context, 'No members found.') : Column(children: [for (final member in members) memberRow(context, member)]),
    );
  }

  Widget taskRow(BuildContext context, TaskListItem item) {
    final task = item.task;
    final deleting = deletingTaskId == task.taskId;
    return simpleInkRow(
      context,
      icon: Icons.circle,
      iconSize: 11,
      title: task.title,
      subtitle: '${task.status.label} • ${task.priority.label} • ${task.dueDateLabel}',
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TaskDetailScreen(initialTask: item, onTaskChanged: () { refresh(); widget.onProjectChanged?.call(); })));
        await refresh();
      },
      trailing: deleting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : IconButton(onPressed: () => removeTask(item), icon: const Icon(Icons.delete_outline_rounded)),
    );
  }

  Widget memberRow(BuildContext context, ProjectMemberModel member) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        CircleAvatar(child: Text(member.initials)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(member.displayName, style: boldSmall(context)), Text(member.email ?? member.roleLabel, style: smallMuted(context))])),
        Chip(label: Text(member.roleLabel)),
      ]),
    );
  }

  Widget scheduleTaskRow(BuildContext context, SmartScheduleTaskItemModel item) {
    return simpleRow(
      context,
      icon: item.isAfterProjectDeadline ? Icons.warning_amber_rounded : Icons.event_rounded,
      title: item.title,
      subtitle: '${item.priority} • ${item.estimatedHours.toStringAsFixed(1)}h • ${formatDateTime(item.suggestedDueDate)}',
      iconColor: item.isAfterProjectDeadline ? Theme.of(context).colorScheme.error : null,
    );
  }

  Widget historyRow(BuildContext context, String level, String subtitle) {
    return simpleRow(context, icon: Icons.insights_rounded, title: level.toUpperCase(), subtitle: subtitle, iconColor: colorForRisk(context, level));
  }

  Widget section(BuildContext context, {required String title, required String subtitle, required IconData icon, required Widget child, Widget? trailing}) {
    final colors = Theme.of(context).colorScheme;
    return card(context, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(backgroundColor: colors.primary.withOpacity(.10), child: Icon(icon, color: colors.primary, size: 21)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: smallMuted(context))])),
        if (trailing != null) trailing,
      ]),
      const SizedBox(height: 14),
      child,
    ]));
  }

  Widget card(BuildContext context, Widget child) {
    final colors = Theme.of(context).colorScheme;
    return Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: colors.surfaceVariant.withOpacity(.45), borderRadius: BorderRadius.circular(24), border: Border.all(color: colors.outlineVariant.withOpacity(.55))), child: child);
  }

  Widget statTile(BuildContext context, String label, String value, IconData icon) {
    final colors = Theme.of(context).colorScheme;
    return Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: colors.surfaceVariant.withOpacity(.28), borderRadius: BorderRadius.circular(20), border: Border.all(color: colors.outlineVariant.withOpacity(.45))), child: Row(children: [Icon(icon, color: colors.primary), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: smallMuted(context))]))]));
  }

  Widget banner(BuildContext context, IconData icon, String text, Color color) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withOpacity(.18))), child: Row(children: [Icon(icon, color: color), const SizedBox(width: 10), Expanded(child: Text(text, style: smallMuted(context)?.copyWith(fontWeight: FontWeight.w800)))]));
  }

  Widget pill(BuildContext context, String label, String value) {
    final colors = Theme.of(context).colorScheme;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8), decoration: BoxDecoration(color: colors.surface.withOpacity(.55), borderRadius: BorderRadius.circular(999), border: Border.all(color: colors.outlineVariant.withOpacity(.55))), child: Text('$label: $value', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900)));
  }

  Widget simpleRow(BuildContext context, {required IconData icon, required String title, required String subtitle, Color? iconColor}) {
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [Icon(icon, color: iconColor ?? Theme.of(context).colorScheme.primary, size: 19), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: boldSmall(context)), Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: smallMuted(context))]))]));
  }

  Widget simpleInkRow(BuildContext context, {required IconData icon, double iconSize = 19, required String title, required String subtitle, required VoidCallback onTap, Widget? trailing}) {
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(.5))), child: Row(children: [Icon(icon, size: iconSize, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: boldSmall(context)), Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: smallMuted(context))])), if (trailing != null) trailing]))));
  }

  Widget fullButton(BuildContext context, String label, VoidCallback? onPressed, IconData icon) => SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(label)));
  Widget fullOutlineButton(BuildContext context, String label, VoidCallback? onPressed, IconData icon) => SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(label)));
  Widget emptyText(BuildContext context, String value) => Text(value, style: smallMuted(context));
  Widget messageBox(BuildContext context, String value, {required bool isError}) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: (isError ? Theme.of(context).colorScheme.errorContainer : Theme.of(context).colorScheme.primaryContainer).withOpacity(.35), borderRadius: BorderRadius.circular(18)), child: Text(value));
  TextStyle? smallMuted(BuildContext context) => Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700, height: 1.35);
  TextStyle? smallPrimary(BuildContext context) => Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900, height: 1.35);
  TextStyle? boldSmall(BuildContext context) => Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900);

  Color colorForRisk(BuildContext context, String riskLevel) {
    final level = riskLevel.toLowerCase();
    if (level.contains('high')) return Theme.of(context).colorScheme.error;
    if (level.contains('medium')) return Colors.orange;
    if (level.contains('low')) return Colors.green;
    return Theme.of(context).colorScheme.primary;
  }

  IconData iconForActivity(String eventType) {
    final value = eventType.toLowerCase();
    if (value.contains('risk')) return Icons.warning_amber_rounded;
    if (value.contains('task')) return Icons.task_alt_rounded;
    if (value.contains('comment')) return Icons.chat_bubble_outline_rounded;
    if (value.contains('attachment')) return Icons.attach_file_rounded;
    if (value.contains('report')) return Icons.description_rounded;
    if (value.contains('member') || value.contains('invite')) return Icons.group_add_rounded;
    return Icons.bolt_rounded;
  }

  String formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }

  String formatDateText(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value.isEmpty ? 'just now' : value;
    return formatDateTime(parsed.toLocal());
  }

  void showAiPlanSheet(AiPlanHistoryModel item) {
    final generatedTasks = item.generatedPlan['tasks'];
    showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, builder: (sheetContext) => DraggableScrollableSheet(expand: false, initialChildSize: .78, minChildSize: .45, maxChildSize: .95, builder: (context, controller) => ListView(controller: controller, padding: const EdgeInsets.fromLTRB(20, 18, 20, 28), children: [Row(children: [Expanded(child: Text('AI Plan Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))), IconButton(onPressed: () => Navigator.of(sheetContext).pop(), icon: const Icon(Icons.close_rounded))]), const SizedBox(height: 12), card(context, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.summary, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text('Generated ${formatDateTime(item.createdAt)}'), if (item.inputPrompt.trim().isNotEmpty) ...[const SizedBox(height: 10), Text('Prompt: ${item.inputPrompt.trim()}')]])), if (generatedTasks is List && generatedTasks.isNotEmpty) ...[const SizedBox(height: 12), card(context, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Generated tasks', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(height: 10), for (final rawTask in generatedTasks.take(20)) generatedPlanTaskRow(context, asMap(rawTask))]))]])));
  }

  Widget generatedPlanTaskRow(BuildContext context, Map<String, dynamic> task) {
    final title = textValue(task, 'title', fallback: textValue(task, 'name', fallback: 'Untitled task'));
    final description = textValue(task, 'description', fallback: textValue(task, 'details'));
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.task_alt_rounded, size: 18), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: boldSmall(context)), if (description.trim().isNotEmpty) Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: smallMuted(context))]))]));
  }

  void showReportSheet(Map<String, dynamic> report) {
    final projectData = asMap(report['project']);
    final progressData = asMap(report['progress']);
    final hoursData = asMap(report['hours']);
    final tasksData = asList(report['tasks']);
    final title = textValue(projectData, 'title', fallback: project.title);
    final status = textValue(projectData, 'status', fallback: project.statusLabel).replaceAll('_', ' ');
    showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, builder: (sheetContext) => DraggableScrollableSheet(expand: false, initialChildSize: .86, minChildSize: .50, maxChildSize: .95, builder: (context, controller) => ListView(controller: controller, padding: const EdgeInsets.fromLTRB(20, 18, 20, 28), children: [Row(children: [Expanded(child: Text('Project Report', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))), IconButton(onPressed: () => Navigator.of(sheetContext).pop(), icon: const Icon(Icons.close_rounded))]), const SizedBox(height: 12), card(context, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: [pill(context, 'Status', status), pill(context, 'Completion', '${numValue(progressData, "completion_percentage").round()}%'), pill(context, 'Completed', '${numValue(progressData, "completed_tasks").round()}/${numValue(progressData, "total_tasks").round()}'), pill(context, 'Estimated', '${numValue(hoursData, "estimated_hours_total").toStringAsFixed(1)}h')])])), const SizedBox(height: 12), card(context, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Tasks', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(height: 10), if (tasksData.isEmpty) emptyText(context, 'No tasks included.') else for (final rawTask in tasksData.take(20)) reportTaskRow(context, asMap(rawTask))]))])));
  }

  Widget reportTaskRow(BuildContext context, Map<String, dynamic> task) {
    return simpleRow(context, icon: Icons.task_alt_rounded, title: textValue(task, 'title', fallback: 'Untitled task'), subtitle: '${textValue(task, "status").replaceAll("_", " ")} • ${textValue(task, "priority")}');
  }

  void showInviteSheet() {
    final controller = TextEditingController();
    var role = 'member';
    showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, builder: (sheetContext) { final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom; return StatefulBuilder(builder: (context, setSheetState) => Padding(padding: EdgeInsets.only(bottom: bottomInset), child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(project.isTeamProject ? 'Invite member' : 'Invite collaborator', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(height: 14), TextField(controller: controller, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email or username', border: OutlineInputBorder())), const SizedBox(height: 12), DropdownButtonFormField<String>(value: role, decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'member', child: Text('Member')), DropdownMenuItem(value: 'manager', child: Text('Manager')), DropdownMenuItem(value: 'admin', child: Text('Admin'))], onChanged: (value) { if (value != null) setSheetState(() => role = value); }), const SizedBox(height: 16), SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () { final value = controller.text; Navigator.of(sheetContext).pop(); inviteMember(value, role); }, icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Send invitation')))])))); });
  }
}
