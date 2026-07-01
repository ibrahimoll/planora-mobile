import 'package:flutter/material.dart';

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
  late final AiPlanApi _aiPlanApi = widget.aiPlanApi;
  late final ProjectInsightsApi _insightsApi = widget.insightsApi;

  late ProjectModel project = widget.project;

  bool isLoadingProject = false;
  bool isLoadingMembers = false;
  bool isLoadingTasks = false;
  bool isLoadingRisk = false;
  bool isLoadingProgress = false;
  bool isLoadingActivity = false;
  bool isLoadingExports = false;
  bool isLoadingAiPlans = false;
  bool isGeneratingReport = false;
  bool isGeneratingAiPlan = false;
  bool isPreviewingSchedule = false;
  bool isDeletingProject = false;
  bool isInvitingMember = false;

  String? pageError;
  String? progressError;
  String? activityError;
  String? reportError;
  String? aiPlanError;

  List<ProjectMemberModel> members = [];
  List<TaskListItem> projectTasks = [];
  RiskAnalysisPreviewModel? riskPreview;
  ProjectProgressModel? progressData;
  List<ProjectActivityModel> activity = [];
  ProjectReportModel? projectReport;
  List<ReportExportHistoryItemModel> reportExports = [];
  List<AiPlanHistoryModel> aiPlans = [];

  @override
  void initState() {
    super.initState();
    loadProjectDetails();
  }

  Future<void> loadProjectDetails() async {
    if (!mounted) return;

    setState(() {
      isLoadingProject = true;
      pageError = null;
    });

    try {
      final loadedProject = await _projectsApi.getProject(project);

      if (!mounted) return;
      setState(() {
        project = loadedProject;
        isLoadingProject = false;
      });

      await Future.wait([
        loadProjectMembers(loadedProject),
        loadProjectTasks(loadedProject),
        loadRiskPreview(loadedProject),
        loadProgress(loadedProject),
        loadActivity(loadedProject),
        loadReportExports(loadedProject),
        loadAiPlans(loadedProject),
      ]);
    } catch (error, stackTrace) {
      debugPrint('Project detail load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;
      setState(() {
        isLoadingProject = false;
        pageError = friendlyError(error, 'Could not refresh project details.');
      });
    }
  }

  Future<void> loadProjectMembers([ProjectModel? source]) async {
    final targetProject = source ?? project;
    if (!mounted) return;

    setState(() => isLoadingMembers = true);

    try {
      final loadedMembers = await _projectsApi.getProjectMembers(targetProject);
      if (!mounted) return;
      setState(() {
        members = loadedMembers;
        isLoadingMembers = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Project members load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => isLoadingMembers = false);
    }
  }

  Future<void> loadProjectTasks([ProjectModel? source]) async {
    final targetProject = source ?? project;
    if (!mounted) return;

    setState(() => isLoadingTasks = true);

    try {
      final loadedTasks = await _tasksApi.getProjectTasks(
        project: TaskProjectSummary.fromProject(targetProject),
      );
      loadedTasks.sort(compareTaskItemsByDueDate);

      if (!mounted) return;
      setState(() {
        projectTasks = loadedTasks;
        isLoadingTasks = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Project tasks load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => isLoadingTasks = false);
    }
  }

  Future<void> loadRiskPreview([ProjectModel? source]) async {
    final targetProject = source ?? project;
    if (!mounted) return;

    setState(() => isLoadingRisk = true);

    try {
      final preview = await _insightsApi.previewRisk(targetProject.projectId);
      if (!mounted) return;
      setState(() {
        riskPreview = preview;
        isLoadingRisk = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Risk preview load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        riskPreview = null;
        isLoadingRisk = false;
      });
    }
  }

  Future<void> loadProgress([ProjectModel? source]) async {
    final targetProject = source ?? project;
    if (!mounted) return;

    setState(() {
      isLoadingProgress = true;
      progressError = null;
    });

    try {
      final progress = await _insightsApi.getProjectProgress(
        targetProject.projectId,
      );
      if (!mounted) return;
      setState(() {
        progressData = progress;
        isLoadingProgress = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Project progress load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        progressData = null;
        progressError = friendlyError(error, 'Could not load backend progress.');
        isLoadingProgress = false;
      });
    }
  }

  Future<void> loadActivity([ProjectModel? source]) async {
    final targetProject = source ?? project;
    if (!mounted) return;

    setState(() {
      isLoadingActivity = true;
      activityError = null;
    });

    try {
      final loadedActivity = await _insightsApi.getProjectActivity(
        projectId: targetProject.projectId,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        activity = loadedActivity;
        isLoadingActivity = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Project activity load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        activity = [];
        activityError = friendlyError(error, 'Could not load activity.');
        isLoadingActivity = false;
      });
    }
  }

  Future<void> loadReportExports([ProjectModel? source]) async {
    final targetProject = source ?? project;
    if (!mounted) return;

    setState(() => isLoadingExports = true);

    try {
      final page = await _insightsApi.getProjectReportExports(
        projectId: targetProject.projectId,
        limit: 6,
      );
      if (!mounted) return;
      setState(() {
        reportExports = page.items;
        isLoadingExports = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Report export history load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => isLoadingExports = false);
    }
  }

  Future<void> loadAiPlans([ProjectModel? source]) async {
    final targetProject = source ?? project;
    if (!mounted) return;

    setState(() {
      isLoadingAiPlans = true;
      aiPlanError = null;
    });

    try {
      final plans = await _insightsApi.getAiPlanHistory(targetProject);
      plans.sort((left, right) => right.createdAt.compareTo(left.createdAt));
      if (!mounted) return;
      setState(() {
        aiPlans = plans;
        isLoadingAiPlans = false;
      });
    } catch (error, stackTrace) {
      debugPrint('AI plan history load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        aiPlans = [];
        aiPlanError = friendlyError(error, 'Could not load AI plan history.');
        isLoadingAiPlans = false;
      });
    }
  }

  Future<void> generateReport() async {
    if (isGeneratingReport) return;

    setState(() {
      isGeneratingReport = true;
      reportError = null;
    });

    try {
      final report = await _insightsApi.generateProjectReport(project.projectId);
      if (!mounted) return;
      setState(() {
        projectReport = report;
        isGeneratingReport = false;
      });
      await loadReportExports(project);
      if (!mounted) return;
      showReportSheet(report);
      showMessage('Project report is ready.');
    } catch (error, stackTrace) {
      debugPrint('Project report generation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        reportError = friendlyError(error, 'Could not generate project report.');
        isGeneratingReport = false;
      });
    }
  }

  Future<void> inviteMember({
    required String emailOrUsername,
    required String role,
  }) async {
    final cleanEmailOrUsername = emailOrUsername.trim();

    if (cleanEmailOrUsername.isEmpty || isInvitingMember) {
      return;
    }

    setState(() => isInvitingMember = true);

    try {
      if (!project.isTeamProject && members.length <= 1) {
        final updatedProject =
            await _projectsApi.invitePersonalProjectMemberAndConvert(
          project: project,
          emailOrUsername: cleanEmailOrUsername,
          role: role,
        );

        if (mounted) {
          setState(() => project = updatedProject);
        }
      } else {
        await _projectsApi.inviteProjectMember(
          project: project,
          emailOrUsername: cleanEmailOrUsername,
          role: role,
        );
      }

      if (!mounted) return;
      setState(() => isInvitingMember = false);
      showMessage('Invitation sent.');
      await loadProjectMembers(project);
      widget.onProjectChanged?.call();
    } catch (error, stackTrace) {
      debugPrint('Project invite failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => isInvitingMember = false);
      showMessage(friendlyError(error, 'Could not invite this person.'));
    }
  }

  Future<void> generateAiPlan(String prompt) async {
    final cleanPrompt = prompt.trim();
    if (cleanPrompt.length < 8 || isGeneratingAiPlan) return;

    setState(() => isGeneratingAiPlan = true);

    try {
      final result = await _aiPlanApi.generatePlan(
        project: project,
        prompt: cleanPrompt,
        generateTasks: true,
        overwriteExistingTasks: false,
        preferredTaskCount: projectTasks.isEmpty ? 8 : 5,
        includeMilestones: true,
      );

      if (!mounted) return;
      setState(() => isGeneratingAiPlan = false);
      showMessage(
        result.tasksCreated > 0
            ? 'AI plan created ${result.tasksCreated} tasks.'
            : 'AI plan generated.',
      );
      await Future.wait([loadProjectTasks(project), loadAiPlans(project)]);
      widget.onProjectChanged?.call();
    } catch (error, stackTrace) {
      debugPrint('AI plan generation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => isGeneratingAiPlan = false);
      showMessage(friendlyError(error, 'Could not generate AI plan.'));
    }
  }

  Future<void> previewSmartSchedule() async {
    if (isPreviewingSchedule) return;

    setState(() => isPreviewingSchedule = true);

    try {
      final preview = await _insightsApi.previewSmartSchedule(project: project);
      if (!mounted) return;
      setState(() => isPreviewingSchedule = false);
      await showSmartSchedulePreviewSheet(preview);
    } catch (error, stackTrace) {
      debugPrint('Smart schedule preview failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => isPreviewingSchedule = false);
      showMessage(friendlyError(error, 'Could not preview smart schedule.'));
    }
  }

  Future<void> deleteProject() async {
    if (isDeletingProject) return;

    setState(() => isDeletingProject = true);

    try {
      await _projectsApi.deleteProject(project);
      widget.onProjectChanged?.call();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error, stackTrace) {
      debugPrint('Project delete failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => isDeletingProject = false);
      showMessage(friendlyError(error, 'Could not delete project.'));
    }
  }

  int compareTaskItemsByDueDate(TaskListItem left, TaskListItem right) {
    final leftDue = left.task.dueDate;
    final rightDue = right.task.dueDate;

    if (leftDue == null && rightDue == null) {
      return left.task.createdAt.compareTo(right.task.createdAt);
    }

    if (leftDue == null) return 1;
    if (rightDue == null) return -1;
    return leftDue.compareTo(rightDue);
  }

  int get localCompletedTaskCount {
    return projectTasks.where((item) => item.task.isCompleted).length;
  }

  int get localOverdueTaskCount {
    return projectTasks.where((item) => item.task.isOverdue).length;
  }

  double get localProgressPercent {
    if (projectTasks.isEmpty) {
      return project.isCompleted ? 100 : 0;
    }

    return (localCompletedTaskCount / projectTasks.length) * 100;
  }

  double get completionPercent {
    return progressData?.project.completionPercentage ?? localProgressPercent;
  }

  Color statusColor(BuildContext context) {
    switch (project.status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Theme.of(context).colorScheme.primary;
      case 'on_hold':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  Color riskColor(String riskLevel) {
    switch (riskLevel) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  String friendlyError(Object error, String fallback) {
    if (error is ApiException && error.message.trim().isNotEmpty) {
      return error.message;
    }

    return fallback;
  }

  String formatDate(DateTime? date) {
    if (date == null) return 'Not set';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String formatDateTime(DateTime? date) {
    if (date == null) return 'Not available';

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${formatDate(date)} • $hour:$minute';
  }

  String titleCase(String value) {
    final words = value.replaceAll('_', ' ').split(' ');
    return words
        .where((word) => word.trim().isNotEmpty)
        .map((word) {
          final lower = word.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadProjectDetails,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            children: [
              buildHeader(context),
              const SizedBox(height: 18),
              if (pageError != null) ...[
                buildMessageCard(
                  context,
                  icon: Icons.wifi_off_rounded,
                  title: 'Could not refresh',
                  message: pageError!,
                ),
                const SizedBox(height: 14),
              ],
              buildHeroCard(context),
              const SizedBox(height: 14),
              buildMetricsGrid(context),
              const SizedBox(height: 14),
              buildBackendProgressCard(context),
              const SizedBox(height: 14),
              buildRiskCard(context),
              const SizedBox(height: 14),
              buildAiToolsCard(context),
              const SizedBox(height: 14),
              buildAiHistoryCard(context),
              const SizedBox(height: 14),
              buildTasksCard(context),
              const SizedBox(height: 14),
              buildActivityCard(context),
              const SizedBox(height: 14),
              buildReportCard(context),
              const SizedBox(height: 14),
              buildMembersCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Project Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Backend-powered overview',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: isLoadingProject ? null : loadProjectDetails,
          icon: isLoadingProject
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') {
              showDeleteProjectDialog();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, color: Colors.red),
                  SizedBox(width: 10),
                  Text('Delete project'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildHeroCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = statusColor(context);
    final percent = completionPercent.clamp(0, 100);

    return buildCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: accent.withOpacity(.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  project.isTeamProject
                      ? Icons.groups_2_rounded
                      : Icons.folder_rounded,
                  color: accent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
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
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        buildChip(
                          context,
                          project.statusLabel,
                          Icons.flag_rounded,
                          accent,
                        ),
                        buildChip(
                          context,
                          project.projectTypeLabel,
                          Icons.workspaces_rounded,
                          colors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((project.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              project.description!.trim(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${percent.round()}% complete',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                project.deadlineLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: project.daysLeft < 0 ? Colors.red : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: percent / 100,
              backgroundColor: accent.withOpacity(.12),
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMetricsGrid(BuildContext context) {
    final progress = progressData;
    final totalTasks = progress?.project.totalTasks ?? projectTasks.length;
    final completedTasks =
        progress?.project.completedTasks ?? localCompletedTaskCount;
    final overdueTasks = progress?.project.overdueTasks ?? localOverdueTaskCount;
    final remainingHours = progress?.hours.remainingEstimatedHours ??
        projectTasks.fold<double>(
          0,
          (sum, item) => sum + (item.task.estimatedHours ?? 0),
        );

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.72,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        buildMetricTile(context, 'Tasks', '$totalTasks', Icons.list_alt_rounded),
        buildMetricTile(
          context,
          'Completed',
          '$completedTasks',
          Icons.check_circle_rounded,
          color: Colors.green,
        ),
        buildMetricTile(
          context,
          'Overdue',
          '$overdueTasks',
          Icons.timer_off_rounded,
          color: overdueTasks > 0 ? Colors.red : Colors.green,
        ),
        buildMetricTile(
          context,
          'Remaining',
          '${remainingHours.toStringAsFixed(1)}h',
          Icons.schedule_rounded,
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget buildBackendProgressCard(BuildContext context) {
    final progress = progressData;

    return buildSectionCard(
      context,
      title: 'Backend Progress',
      subtitle: 'Real progress, hours, members, and recommendations',
      icon: Icons.insights_rounded,
      isLoading: isLoadingProgress,
      error: progressError,
      child: progress == null
          ? buildEmptyText(context, 'Progress data will appear here.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: buildInfoPill(
                        context,
                        'Status',
                        titleCase(progress.project.productivityStatus),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: buildInfoPill(
                        context,
                        'Your progress',
                        '${progress.currentUserProgress.completionPercentage.round()}%',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                buildStatusBreakdown(context, progress.taskStatusCounts),
                if (progress.recommendations.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Recommendations',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final item in progress.recommendations.take(3))
                    buildBullet(context, item),
                ],
                if (progress.members.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Member progress',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final member in progress.members.take(4))
                    buildProgressMemberRow(context, member),
                ],
              ],
            ),
    );
  }

  Widget buildRiskCard(BuildContext context) {
    final risk = riskPreview;
    final color = risk == null ? Colors.blueGrey : riskColor(risk.riskLevel);

    return buildSectionCard(
      context,
      title: 'Risk Preview',
      subtitle: 'AI-backed delay and delivery risk signals',
      icon: Icons.warning_amber_rounded,
      isLoading: isLoadingRisk,
      child: risk == null
          ? buildEmptyText(
              context,
              'Risk analysis will appear after enough project activity.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildChip(
                  context,
                  '${titleCase(risk.riskLevel)} risk',
                  Icons.shield_rounded,
                  color,
                ),
                const SizedBox(height: 12),
                Text(
                  risk.reason.isEmpty ? 'No detailed reason returned.' : risk.reason,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.45,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (risk.recommendation.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  buildBullet(context, risk.recommendation),
                ],
              ],
            ),
    );
  }

  Widget buildAiToolsCard(BuildContext context) {
    return buildSectionCard(
      context,
      title: 'Planora AI Tools',
      subtitle: 'Improve this plan or reschedule remaining work',
      icon: Icons.auto_awesome_rounded,
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isGeneratingAiPlan ? null : showAiPlanSheet,
              icon: isGeneratingAiPlan
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bolt_rounded),
              label: Text(
                isGeneratingAiPlan
                    ? 'Generating plan...'
                    : 'Ask AI to improve this plan',
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isPreviewingSchedule ? null : previewSmartSchedule,
              icon: isPreviewingSchedule
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.calendar_month_rounded),
              label: Text(
                isPreviewingSchedule
                    ? 'Checking schedule...'
                    : 'Preview smart schedule',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildAiHistoryCard(BuildContext context) {
    return buildSectionCard(
      context,
      title: 'AI Plan History',
      subtitle: 'Saved plans generated for this project',
      icon: Icons.history_rounded,
      isLoading: isLoadingAiPlans,
      error: aiPlanError,
      child: aiPlans.isEmpty
          ? buildEmptyText(context, 'No AI plans saved yet.')
          : Column(
              children: [
                for (final plan in aiPlans.take(4)) buildAiPlanRow(context, plan),
              ],
            ),
    );
  }

  Widget buildTasksCard(BuildContext context) {
    return buildSectionCard(
      context,
      title: 'Project Tasks',
      subtitle: 'Open any task to manage subtasks, comments, and attachments',
      icon: Icons.task_alt_rounded,
      isLoading: isLoadingTasks,
      child: projectTasks.isEmpty
          ? buildEmptyText(context, 'No tasks in this project yet.')
          : Column(
              children: [
                for (final item in projectTasks.take(6)) buildTaskRow(context, item),
                if (projectTasks.length > 6)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '+${projectTasks.length - 6} more tasks',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget buildActivityCard(BuildContext context) {
    return buildSectionCard(
      context,
      title: 'Activity Timeline',
      subtitle: 'Backend activity log for this project',
      icon: Icons.timeline_rounded,
      isLoading: isLoadingActivity,
      error: activityError,
      child: activity.isEmpty
          ? buildEmptyText(context, 'No activity has been logged yet.')
          : Column(
              children: [
                for (final item in activity.take(8)) buildActivityRow(context, item),
              ],
            ),
    );
  }

  Widget buildReportCard(BuildContext context) {
    final report = projectReport;

    return buildSectionCard(
      context,
      title: 'Reports',
      subtitle: 'Generate a readable project report',
      icon: Icons.description_rounded,
      isLoading: isLoadingExports,
      error: reportError,
      trailing: TextButton.icon(
        onPressed: isGeneratingReport
            ? null
            : report == null
                ? generateReport
                : () => showReportSheet(report),
        icon: isGeneratingReport
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(report == null ? Icons.summarize_rounded : Icons.visibility_rounded, size: 18),
        label: Text(
          isGeneratingReport
              ? 'Generating'
              : report == null
                  ? 'Generate'
                  : 'View',
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (report != null) ...[
            Row(
              children: [
                Expanded(
                  child: buildInfoPill(
                    context,
                    'Report progress',
                    '${report.progress.completionPercentage.round()}%',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: buildInfoPill(
                    context,
                    'Generated',
                    formatDate(report.generatedAt),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            buildBullet(
              context,
              '${report.tasks.length} tasks, ${report.members.length} members, ${report.activity.commentsCount} comments.',
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => showReportSheet(report),
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('View full report'),
              ),
            ),
            const SizedBox(height: 14),
          ] else ...[
            buildEmptyText(
              context,
              'Generate a report to view task status, priority, hours, members, and activity summary.',
            ),
            const SizedBox(height: 14),
          ],
          Text(
            'Recent reports',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          if (reportExports.isEmpty)
            buildEmptyText(context, 'No report history yet.')
          else
            for (final export in reportExports.take(5))
              buildReportExportRow(context, export),
        ],
      ),
    );
  }

  Widget buildMembersCard(BuildContext context) {
    return buildSectionCard(
      context,
      title: project.isTeamProject ? 'Members' : 'Collaborators',
      subtitle: 'People connected to this project',
      icon: Icons.groups_rounded,
      isLoading: isLoadingMembers,
      trailing: TextButton.icon(
        onPressed: isInvitingMember ? null : showInviteMemberSheet,
        icon: isInvitingMember
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.person_add_alt_1_rounded, size: 18),
        label: Text(isInvitingMember ? 'Inviting' : 'Invite'),
      ),
      child: members.isEmpty
          ? buildEmptyText(context, 'No members found.')
          : Column(
              children: [
                for (final member in members) buildMemberRow(context, member),
              ],
            ),
    );
  }

  Widget buildSectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
    bool isLoading = false,
    String? error,
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
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              ),
            )
          else if (error != null)
            buildMessageCard(
              context,
              icon: Icons.info_outline_rounded,
              title: 'Not available',
              message: error,
              compact: true,
            )
          else
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

  Widget buildMetricTile(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    final colors = Theme.of(context).colorScheme;
    final accent = color ?? colors.primary;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withOpacity(.40),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withOpacity(.45)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withOpacity(.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

  Widget buildChip(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
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

  Widget buildInfoPill(BuildContext context, String label, String value) {
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStatusBreakdown(
    BuildContext context,
    ProgressTaskStatusCountsModel counts,
  ) {
    final total = counts.todo + counts.inProgress + counts.completed + counts.blocked;

    return Column(
      children: [
        buildStatusLine(context, 'To Do', counts.todo, total, Colors.blueGrey),
        buildStatusLine(context, 'In Progress', counts.inProgress, total, Colors.blue),
        buildStatusLine(context, 'Completed', counts.completed, total, Colors.green),
        buildStatusLine(context, 'Blocked', counts.blocked, total, Colors.orange),
      ],
    );
  }

  Widget buildStatusLine(
    BuildContext context,
    String label,
    int count,
    int total,
    Color color,
  ) {
    final ratio = total == 0 ? 0.0 : count / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$count',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: ratio,
              color: color,
              backgroundColor: color.withOpacity(.10),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildProgressMemberRow(BuildContext context, UserProgressItemModel member) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(child: Text(member.displayName[0].toUpperCase())),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${member.tasksCompleted}/${member.tasksTotal} tasks • ${titleCase(member.role)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${member.completionPercentage.round()}%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildAiPlanRow(BuildContext context, AiPlanHistoryModel plan) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(.07),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Plan #${plan.planId}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  formatDate(plan.createdAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              plan.summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                height: 1.35,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (plan.generatedTaskCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${plan.generatedTaskCount} generated tasks',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildTaskRow(BuildContext context, TaskListItem item) {
    final task = item.task;
    final color = task.status == TaskStatus.completed
        ? Colors.green
        : task.status == TaskStatus.blocked
            ? Colors.orange
            : Theme.of(context).colorScheme.primary;

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
                  loadProjectTasks(project);
                  loadProgress(project);
                  widget.onProjectChanged?.call();
                },
              ),
            ),
          );
          await Future.wait([loadProjectTasks(project), loadProgress(project)]);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withOpacity(.5),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.circle, color: color, size: 12),
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
                    const SizedBox(height: 4),
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
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildActivityRow(BuildContext context, ProjectActivityModel item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              activityIcon(item.eventType),
              size: 17,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.message.isEmpty ? titleCase(item.eventType) : item.message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.actorLabel} • ${formatDateTime(item.createdAt)}',
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

  IconData activityIcon(String eventType) {
    if (eventType.contains('task')) return Icons.task_alt_rounded;
    if (eventType.contains('comment')) return Icons.chat_bubble_outline_rounded;
    if (eventType.contains('attachment')) return Icons.attach_file_rounded;
    if (eventType.contains('ai')) return Icons.auto_awesome_rounded;
    if (eventType.contains('deadline')) return Icons.timer_rounded;
    return Icons.history_rounded;
  }

  Widget buildReportExportRow(BuildContext context, ReportExportHistoryItemModel export) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${titleCase(export.exportFormat)} report • ${export.completionPercentageSnapshot.round()}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${export.exportedByLabel} • ${formatDateTime(export.createdAt)}',
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
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
          buildChip(context, member.roleLabel, Icons.badge_rounded, Colors.blueGrey),
        ],
      ),
    );
  }

  Widget buildBullet(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Icon(
              Icons.circle,
              size: 6,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEmptyText(BuildContext context, String message) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget buildMessageCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    bool compact = false,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: colors.errorContainer.withOpacity(.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.error.withOpacity(.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
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

  void showInviteMemberSheet() {
    final inviteController = TextEditingController();
    var selectedRole = 'member';

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
                      project.isTeamProject ? 'Invite member' : 'Invite collaborator',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter an email or username to invite someone to this project.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: inviteController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email or username',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'member', child: Text('Member')),
                        DropdownMenuItem(value: 'manager', child: Text('Manager')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setSheetState(() => selectedRole = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final value = inviteController.text.trim();
                          Navigator.of(sheetContext).pop();
                          inviteMember(
                            emailOrUsername: value,
                            role: selectedRole,
                          );
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
    ).whenComplete(inviteController.dispose);
  }

  void showReportSheet(ProjectReportModel report) {
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Project Report',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Generated ${formatDateTime(report.generatedAt)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                buildCard(
                  context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.project.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if ((report.project.description ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          report.project.description!.trim(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: buildInfoPill(
                              context,
                              'Status',
                              titleCase(report.project.status),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: buildInfoPill(
                              context,
                              'Deadline',
                              formatDate(report.project.deadline),
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
                        'Progress summary',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: buildInfoPill(
                              context,
                              'Completion',
                              '${report.progress.completionPercentage.round()}%',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: buildInfoPill(
                              context,
                              'Overdue',
                              '${report.progress.overdueTasks}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      buildStatusBreakdown(context, report.taskStatusCounts),
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
                        'Hours and activity',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: buildInfoPill(
                              context,
                              'Estimated',
                              '${report.hours.estimatedHoursTotal.toStringAsFixed(1)}h',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: buildInfoPill(
                              context,
                              'Actual',
                              '${report.hours.actualHoursTotal.toStringAsFixed(1)}h',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      buildBullet(context, '${report.activity.commentsCount} comments'),
                      buildBullet(context, '${report.activity.attachmentsCount} attachments'),
                      buildBullet(
                        context,
                        '${report.activity.deadlineRemindersCount} deadline reminders',
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
                        'Priority breakdown',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      buildBullet(context, 'High: ${report.taskPriorityCounts.high}'),
                      buildBullet(context, 'Medium: ${report.taskPriorityCounts.medium}'),
                      buildBullet(context, 'Low: ${report.taskPriorityCounts.low}'),
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
                      if (report.tasks.isEmpty)
                        buildEmptyText(context, 'No tasks included in this report.')
                      else
                        for (final task in report.tasks.take(12))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Icon(
                                  task.status == 'completed'
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  size: 18,
                                ),
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
                                        '${titleCase(task.status)} • ${titleCase(task.priority)} • ${formatDate(task.dueDate)}',
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
                              ],
                            ),
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

  void showAiPlanSheet() {
    final promptController = TextEditingController(
      text:
          'Review this project and improve the plan with clear next tasks, milestones, and deadline-aware priorities.',
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Improve with AI',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: promptController,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Instruction',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final prompt = promptController.text;
                      Navigator.of(sheetContext).pop();
                      generateAiPlan(prompt);
                    },
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Generate improved plan'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(promptController.dispose);
  }

  Future<void> showSmartSchedulePreviewSheet(
    SmartSchedulePreviewModel preview,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        var applying = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart Schedule Preview',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: buildInfoPill(
                          context,
                          'Schedulable',
                          '${preview.schedulableTaskCount}/${preview.totalTasks}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: buildInfoPill(
                          context,
                          'Hours',
                          preview.estimatedTotalHours.toStringAsFixed(1),
                        ),
                      ),
                    ],
                  ),
                  if (preview.warnings.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    for (final warning in preview.warnings) buildBullet(context, warning),
                  ],
                  const SizedBox(height: 12),
                  for (final task in preview.tasks.take(8))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: buildCard(
                        context,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Suggested: ${formatDate(task.suggestedDueDate)}',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: task.isAfterProjectDeadline
                                    ? Colors.red
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: applying
                          ? null
                          : () async {
                              setSheetState(() => applying = true);
                              try {
                                await _insightsApi.applySmartSchedule(
                                  project: project,
                                );
                                if (!mounted || !sheetContext.mounted) return;
                                Navigator.of(sheetContext).pop();
                                showMessage('Schedule updated.');
                                await Future.wait([
                                  loadProjectTasks(project),
                                  loadProgress(project),
                                ]);
                                widget.onProjectChanged?.call();
                              } catch (error, stackTrace) {
                                debugPrint('Smart schedule apply failed: $error');
                                debugPrintStack(stackTrace: stackTrace);
                                if (mounted) {
                                  showMessage(
                                    friendlyError(error, 'Could not apply schedule.'),
                                  );
                                }
                              } finally {
                                if (sheetContext.mounted) {
                                  setSheetState(() => applying = false);
                                }
                              }
                            },
                      icon: applying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(applying ? 'Applying...' : 'Apply schedule'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> showDeleteProjectDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete project?'),
          content: Text(
            'This will delete "${project.title}" and its tasks. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.tonalIcon(
              onPressed: isDeletingProject
                  ? null
                  : () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await deleteProject();
    }
  }
}
