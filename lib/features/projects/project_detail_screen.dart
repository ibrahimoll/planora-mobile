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
  late final ProjectsApi _projectsApi = widget.projectsApi;
  late final TasksApi _tasksApi = widget.tasksApi;
  late final ProjectInsightsApi _insightsApi = widget.insightsApi;
  late ProjectModel project = widget.project;

  bool loading = true;
  bool requestingReport = false;
  bool openingReport = false;
  bool inviting = false;
  int? removingTaskId;
  String? error;
  String? reportMessage;
  String? reportStatus;
  String? reportReason;
  String? latestReportDate;

  List<TaskListItem> tasks = [];
  List<ProjectMemberModel> members = [];
  ProjectProgressModel? progress;

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

  List<dynamic> asList(dynamic value) {
    if (value is List) return value;
    return const <dynamic>[];
  }

  String stringValue(
    Map<String, dynamic> map,
    String key, {
    String fallback = '',
  }) {
    final value = map[key];
    if (value == null) return fallback;
    return value.toString();
  }

  num numValue(Map<String, dynamic> map, String key, {num fallback = 0}) {
    final value = map[key];
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? fallback;
    return fallback;
  }

  Future<void> refresh() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final loadedProject = await _projectsApi.getProject(project);
      final loadedTasks = await _tasksApi.getProjectTasks(
        project: TaskProjectSummary.fromProject(loadedProject),
      );
      final loadedMembers = await _projectsApi.getProjectMembers(loadedProject);
      ProjectProgressModel? loadedProgress;
      String? loadedStatus;
      String? loadedReason;
      String? loadedReportDate;

      try {
        loadedProgress = await _insightsApi.getProjectProgress(
          loadedProject.projectId,
        );
      } catch (_) {
        loadedProgress = null;
      }

      try {
        final requestsData = await ApiClient.get(
          '/reports/requests/me',
          queryParameters: {'project_id': loadedProject.projectId},
        );
        final requestItems = asList(asMap(requestsData)['items']);
        if (requestItems.isNotEmpty) {
          final latest = asMap(requestItems.first);
          loadedStatus = stringValue(latest, 'status');
          loadedReason = stringValue(latest, 'rejection_reason');
          loadedReportDate = stringValue(latest, 'resolved_at');
        }
      } catch (err) {
        debugPrint('Report request status check failed: $err');
      }

      try {
        final exportsData = await ApiClient.get(
          '/reports/projects/${loadedProject.projectId}/exports',
          queryParameters: {'limit': 1, 'offset': 0},
        );
        final items = asList(asMap(exportsData)['items']);
        if (items.isNotEmpty &&
            loadedStatus != 'pending' &&
            loadedStatus != 'rejected') {
          loadedStatus = 'ready';
          loadedReportDate ??= stringValue(asMap(items.first), 'created_at');
        }
      } catch (err) {
        debugPrint('Report ready check failed: $err');
      }

      if (!mounted) return;
      setState(() {
        project = loadedProject;
        tasks = loadedTasks;
        members = loadedMembers;
        progress = loadedProgress;
        reportStatus = loadedStatus;
        reportReason = loadedReason;
        latestReportDate = loadedReportDate;
        loading = false;
      });
    } catch (err, stackTrace) {
      debugPrint('Project detail refresh failed: $err');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        loading = false;
        error = friendlyError(err, 'Could not load project details.');
      });
    }
  }

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
        reportMessage = 'Request sent. You can track the status here.';
      });
      showMessage('Report request sent to admin.');
    } catch (err, stackTrace) {
      debugPrint('Report request failed: $err');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        requestingReport = false;
        reportMessage = friendlyError(
          err,
          'Could not send the report request.',
        );
      });
    }
  }

  Future<void> openLatestReport() async {
    if (openingReport) return;

    setState(() => openingReport = true);

    try {
      final data = await ApiClient.get(
        '/reports/projects/${project.projectId}/latest',
      );
      if (!mounted) return;
      setState(() => openingReport = false);
      showReportSheet(asMap(data));
    } catch (err, stackTrace) {
      debugPrint('Latest report load failed: $err');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => openingReport = false);
      showMessage(friendlyError(err, 'Could not open the ready report.'));
    }
  }

  Future<void> inviteMember(String emailOrUsername, String role) async {
    final value = emailOrUsername.trim();
    if (value.isEmpty || inviting) return;

    setState(() => inviting = true);

    try {
      if (!project.isTeamProject && members.length <= 1) {
        project = await _projectsApi.invitePersonalProjectMemberAndConvert(
          project: project,
          emailOrUsername: value,
          role: role,
        );
      } else {
        await _projectsApi.inviteProjectMember(
          project: project,
          emailOrUsername: value,
          role: role,
        );
      }

      if (!mounted) return;
      setState(() => inviting = false);
      showMessage('Invitation sent.');
      await refresh();
      widget.onProjectChanged?.call();
    } catch (err, stackTrace) {
      debugPrint('Invite failed: $err');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => inviting = false);
      showMessage(friendlyError(err, 'Could not invite this person.'));
    }
  }

  Future<void> removeTask(TaskListItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('Delete "${item.task.title}" from this project?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => removingTaskId = item.task.taskId);

    try {
      await _tasksApi.deleteTask(
        project: item.project,
        taskId: item.task.taskId,
      );
      if (!mounted) return;
      setState(() {
        tasks.removeWhere(
          (taskItem) => taskItem.task.taskId == item.task.taskId,
        );
        removingTaskId = null;
      });
      showMessage('Task deleted.');
      widget.onProjectChanged?.call();
    } catch (err, stackTrace) {
      debugPrint('Task delete failed: $err');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => removingTaskId = null);
      showMessage(friendlyError(err, 'Could not delete task.'));
    }
  }

  String friendlyError(Object err, String fallback) {
    if (err is ApiException && err.message.trim().isNotEmpty)
      return err.message;
    return fallback;
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  double get completionPercent {
    if (progress != null) return progress!.project.completionPercentage;
    if (tasks.isEmpty) return project.isCompleted ? 100 : 0;
    final done = tasks.where((item) => item.task.isCompleted).length;
    return (done / tasks.length) * 100;
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
              buildTopBar(context),
              const SizedBox(height: 16),
              if (error != null) ...[
                buildMessage(context, error!, isError: true),
                const SizedBox(height: 12),
              ],
              buildProjectCard(context),
              const SizedBox(height: 12),
              buildStatsGrid(context),
              const SizedBox(height: 12),
              buildReportCard(context),
              const SizedBox(height: 12),
              buildTasksCard(context),
              const SizedBox(height: 12),
              buildMembersCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTopBar(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 8),
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
          icon: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget buildProjectCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final percent = completionPercent.clamp(0, 100);

    return buildCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  project.isTeamProject
                      ? Icons.groups_2_rounded
                      : Icons.folder_rounded,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 12),
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((project.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              project.description!.trim(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            '${percent.round()}% complete',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: percent / 100, minHeight: 8),
        ],
      ),
    );
  }

  Widget buildStatsGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.75,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        buildStatTile(
          context,
          'Tasks',
          '${tasks.length}',
          Icons.list_alt_rounded,
        ),
        buildStatTile(
          context,
          'Completed',
          '$doneTasks',
          Icons.check_circle_rounded,
        ),
        buildStatTile(
          context,
          'Overdue',
          '$overdueTasks',
          Icons.timer_off_rounded,
        ),
        buildStatTile(
          context,
          'Members',
          '${members.length}',
          Icons.groups_rounded,
        ),
      ],
    );
  }

  Widget buildReportCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tone = isReportReady
        ? Colors.green
        : isReportRejected
        ? colors.error
        : isReportPending
        ? Colors.orange
        : colors.primary;
    final statusLabel = isReportReady
        ? 'Ready'
        : isReportRejected
        ? 'Rejected'
        : isReportPending
        ? 'Pending admin review'
        : 'No request yet';

    return buildSection(
      context,
      title: 'Reports',
      subtitle: statusLabel,
      icon: Icons.description_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tone.withOpacity(.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tone.withOpacity(.18)),
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
                        ? 'Your admin prepared this report. The email only notifies you; the report details stay inside Planora.'
                        : isReportRejected
                        ? 'The admin rejected this report request. You can request again when needed.'
                        : isReportPending
                        ? 'Your report request is waiting for admin review.'
                        : 'Ask admins to prepare or approve a report. You can track the status here.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isReportRejected && (reportReason ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Reason: $reportReason',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.error,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (isReportReady && latestReportDate != null) ...[
            const SizedBox(height: 10),
            Text(
              'Latest report: $latestReportDate',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (isReportReady) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: openingReport ? null : openLatestReport,
                icon: openingReport
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.visibility_rounded),
                label: Text(
                  openingReport ? 'Opening report...' : 'View report in app',
                ),
              ),
            ),
            const SizedBox(height: 10),
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
              child: ElevatedButton.icon(
                onPressed: requestingReport || isReportPending
                    ? null
                    : requestReport,
                icon: requestingReport
                    ? const SizedBox(
                        width: 16,
                        height: 16,
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
            Text(
              reportMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildTasksCard(BuildContext context) {
    return buildSection(
      context,
      title: 'Project Tasks',
      subtitle: 'Open or delete project tasks directly',
      icon: Icons.task_alt_rounded,
      child: tasks.isEmpty
          ? buildEmpty(context, 'No tasks in this project yet.')
          : Column(
              children: [
                for (final item in tasks.take(8)) buildTaskRow(context, item),
              ],
            ),
    );
  }

  Widget buildMembersCard(BuildContext context) {
    return buildSection(
      context,
      title: project.isTeamProject ? 'Members' : 'Collaborators',
      subtitle: 'People connected to this project',
      icon: Icons.groups_rounded,
      trailing: TextButton.icon(
        onPressed: inviting ? null : showInviteSheet,
        icon: inviting
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.person_add_alt_1_rounded, size: 18),
        label: Text(inviting ? 'Inviting' : 'Invite'),
      ),
      child: members.isEmpty
          ? buildEmpty(context, 'No members found.')
          : Column(
              children: [
                for (final member in members) buildMemberRow(context, member),
              ],
            ),
    );
  }

  Widget buildTaskRow(BuildContext context, TaskListItem item) {
    final task = item.task;
    final deleting = removingTaskId == task.taskId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withOpacity(.5),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.circle, size: 11),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${task.status.label} • ${task.priority.label} • ${task.dueDateLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              deleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      tooltip: 'Delete task',
                      onPressed: () => removeTask(item),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildMemberRow(BuildContext context, ProjectMemberModel member) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(child: Text(member.initials)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  member.email ?? member.roleLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Chip(label: Text(member.roleLabel)),
        ],
      ),
    );
  }

  Widget buildSection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    final colors = Theme.of(context).colorScheme;

    return buildCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: colors.primary, size: 21),
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget buildCard(BuildContext context, {required Widget child}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withOpacity(.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withOpacity(.55)),
      ),
      child: child,
    );
  }

  Widget buildStatTile(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withOpacity(.40),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withOpacity(.45)),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMessage(
    BuildContext context,
    String message, {
    required bool isError,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError
            ? colors.errorContainer.withOpacity(.35)
            : colors.primaryContainer.withOpacity(.35),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(message),
    );
  }

  Widget buildEmpty(BuildContext context, String message) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget buildReportInfoPill(BuildContext context, String label, String value) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  void showReportSheet(Map<String, dynamic> report) {
    final projectData = asMap(report['project']);
    final progressData = asMap(report['progress']);
    final hoursData = asMap(report['hours']);
    final activityData = asMap(report['activity']);
    final tasksData = asList(report['tasks']);
    final title = stringValue(projectData, 'title', fallback: project.title);
    final status = stringValue(
      projectData,
      'status',
      fallback: project.statusLabel,
    ).replaceAll('_', ' ');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .88,
          minChildSize: .55,
          maxChildSize: .95,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Project Report',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                buildCard(
                  context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: buildReportInfoPill(
                              context,
                              'Status',
                              status,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: buildReportInfoPill(
                              context,
                              'Completion',
                              '${numValue(progressData, "completion_percentage").round()}%',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                buildCard(
                  context,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: buildReportInfoPill(
                              context,
                              'Completed',
                              '${numValue(progressData, "completed_tasks").round()}/${numValue(progressData, "total_tasks").round()}',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: buildReportInfoPill(
                              context,
                              'Overdue',
                              '${numValue(progressData, "overdue_tasks").round()}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: buildReportInfoPill(
                              context,
                              'Estimated',
                              '${numValue(hoursData, "estimated_hours_total").toStringAsFixed(1)}h',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: buildReportInfoPill(
                              context,
                              'Actual',
                              '${numValue(hoursData, "actual_hours_total").toStringAsFixed(1)}h',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                buildCard(
                  context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Activity',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Comments: ${numValue(activityData, "comments_count").round()}',
                      ),
                      Text(
                        'Attachments: ${numValue(activityData, "attachments_count").round()}',
                      ),
                      Text(
                        'Deadline reminders: ${numValue(activityData, "deadline_reminders_count").round()}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                buildCard(
                  context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tasks',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (tasksData.isEmpty)
                        buildEmpty(context, 'No tasks included.')
                      else
                        for (final rawTask in tasksData.take(20))
                          buildReportTaskRow(context, asMap(rawTask)),
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

  Widget buildReportTaskRow(BuildContext context, Map<String, dynamic> task) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.task_alt_rounded, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stringValue(task, 'title', fallback: 'Untitled task'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  '${stringValue(task, "status").replaceAll("_", " ")} • ${stringValue(task, "priority")}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void showInviteSheet() {
    final controller = TextEditingController();
    var role = 'member';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.isTeamProject
                          ? 'Invite member'
                          : 'Invite collaborator',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email or username',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: role,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'member',
                          child: Text('Member'),
                        ),
                        DropdownMenuItem(
                          value: 'manager',
                          child: Text('Manager'),
                        ),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      ],
                      onChanged: (value) {
                        if (value != null) setSheetState(() => role = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final value = controller.text;
                          Navigator.of(sheetContext).pop();
                          inviteMember(value, role);
                        },
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('Send invitation'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }
}
