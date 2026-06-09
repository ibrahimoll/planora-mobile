import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/planora_theme.dart';
import '../ai/data/ai_plan_api.dart';
import '../auth/data/project_api.dart';
import '../auth/models/project_models.dart';
import '../tasks/data/tasks_api.dart';
import '../tasks/models/task_models.dart';
import 'data/project_insights_api.dart';

class ProjectDetailScreen extends StatefulWidget {
  final ProjectModel project;
  final ProjectsApi projectsApi;
  final TasksApi tasksApi;
  final AiPlanApi aiPlanApi;
  final ProjectInsightsApi insightsApi;

  const ProjectDetailScreen({
    super.key,
    required this.project,
    this.projectsApi = const ProjectsApi(),
    this.tasksApi = const TasksApi(),
    this.aiPlanApi = const AiPlanApi(),
    this.insightsApi = const ProjectInsightsApi(),
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late final ProjectsApi _projectsApi;
  late final TasksApi _tasksApi;
  late final AiPlanApi _aiPlanApi;
  late final ProjectInsightsApi _insightsApi;

  late ProjectModel project = widget.project;
  bool isLoadingProject = false;
  bool isLoadingMembers = false;
  bool isLoadingTasks = false;
  bool isLoadingRisk = false;
  bool isPreviewingSchedule = false;
  bool isApplyingSchedule = false;
  bool isGeneratingAiPlan = false;
  bool isDeletingProject = false;
  String? errorMessage;
  String? membersErrorMessage;
  String? tasksErrorMessage;
  String? riskErrorMessage;
  List<ProjectMemberModel> members = [];
  List<TaskListItem> projectTasks = [];
  RiskAnalysisPreviewModel? riskPreview;

  @override
  void initState() {
    super.initState();
    _projectsApi = widget.projectsApi;
    _tasksApi = widget.tasksApi;
    _aiPlanApi = widget.aiPlanApi;
    _insightsApi = widget.insightsApi;
    loadProjectDetails();
  }

  Future<void> loadProjectDetails() async {
    setState(() {
      isLoadingProject = true;
      isLoadingMembers = true;
      isLoadingTasks = true;
      isLoadingRisk = true;
      errorMessage = null;
      membersErrorMessage = null;
      tasksErrorMessage = null;
      riskErrorMessage = null;
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
      ]);
    } catch (error, stackTrace) {
      debugPrint('Project detail load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        isLoadingProject = false;
        isLoadingMembers = false;
        isLoadingTasks = false;
        isLoadingRisk = false;
        errorMessage = 'Could not refresh project details.';
        membersErrorMessage = 'Could not load project collaborators.';
        tasksErrorMessage = 'Could not load project tasks.';
        riskErrorMessage =
            'Risk analysis will appear after enough project activity.';
      });
    }
  }

  Future<void> loadProjectMembers([ProjectModel? source]) async {
    final targetProject = source ?? project;

    setState(() {
      isLoadingMembers = true;
      membersErrorMessage = null;
    });

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

      setState(() {
        isLoadingMembers = false;
        membersErrorMessage = targetProject.isTeamProject
            ? 'Could not load project members.'
            : 'Could not load project collaborators.';
      });
    }
  }

  Future<void> loadProjectTasks([ProjectModel? source]) async {
    final targetProject = source ?? project;

    setState(() {
      isLoadingTasks = true;
      tasksErrorMessage = null;
    });

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

      setState(() {
        isLoadingTasks = false;
        tasksErrorMessage = 'Could not load project tasks.';
      });
    }
  }

  Future<void> loadRiskPreview([ProjectModel? source]) async {
    final targetProject = source ?? project;

    setState(() {
      isLoadingRisk = true;
      riskErrorMessage = null;
    });

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
        riskErrorMessage =
            'Risk analysis will appear after enough project activity.';
      });
    }
  }

  Color mutedColor(BuildContext context) {
    return PlanoraTheme.isDark(context)
        ? PlanoraTheme.darkTextMuted
        : PlanoraTheme.textSecondary;
  }

  BoxDecoration cardDecoration(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return BoxDecoration(
      color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
      ),
      boxShadow: PlanoraTheme.cardShadowFor(context),
    );
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Color statusColor(BuildContext context) {
    switch (project.status) {
      case 'completed':
        return PlanoraTheme.primaryPurple;
      case 'in_progress':
        return PlanoraTheme.success;
      case 'on_hold':
        return PlanoraTheme.warning;
      case 'cancelled':
        return PlanoraTheme.error;
      case 'not_started':
        return PlanoraTheme.info;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  double get progress {
    if (projectTasks.isNotEmpty) {
      final completed = projectTasks.where((item) => item.task.isCompleted);
      return completed.length / projectTasks.length;
    }

    if (project.isCompleted) return 1;
    if (project.status == 'in_progress') return 0.55;
    if (project.status == 'on_hold') return 0.35;
    if (project.status == 'cancelled') return 0;
    return 0.12;
  }

  int get completedTaskCount {
    return projectTasks.where((item) => item.task.isCompleted).length;
  }

  int get totalTaskCount {
    return projectTasks.length;
  }

  int get remainingTaskCount {
    return projectTasks.where((item) => !item.task.isCompleted).length;
  }

  int get overdueTaskCount {
    return projectTasks.where((item) => item.task.isOverdue).length;
  }

  int get blockedTaskCount {
    return projectTasks.where((item) => item.task.isBlocked).length;
  }

  TaskListItem? get nextDueTask {
    final openTasks =
        projectTasks
            .where(
              (item) => !item.task.isCompleted && item.task.dueDate != null,
            )
            .toList()
          ..sort(compareTaskItemsByDueDate);

    if (openTasks.isEmpty) {
      return null;
    }

    return openTasks.first;
  }

  Map<TaskStatus, int> get taskStatusCounts {
    return {
      for (final status in TaskStatus.values)
        status: projectTasks.where((item) => item.task.status == status).length,
    };
  }

  String get formattedDeadline {
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

    return '${months[project.deadline.month - 1]} ${project.deadline.day}, ${project.deadline.year}';
  }

  Widget buildHeader(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 44,
            height: 44,
            decoration: cardDecoration(context),
            child: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? Colors.white : PlanoraTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'Project Details',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : PlanoraTheme.textPrimary,
            ),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Project actions',
          onSelected: (value) {
            if (value == 'delete') {
              showDeleteProjectDialog();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, color: PlanoraTheme.error),
                  SizedBox(width: 10),
                  Text('Delete project'),
                ],
              ),
            ),
          ],
          icon: const Icon(Icons.more_vert_rounded),
        ),
        IconButton(
          tooltip: 'Refresh project',
          onPressed: isLoadingProject ? null : loadProjectDetails,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget buildHeroCard(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final color = statusColor(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: PlanoraTheme.primaryGradientFor(context),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  project.isTeamProject
                      ? Icons.groups_2_rounded
                      : Icons.folder_rounded,
                  color: Colors.white,
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : PlanoraTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      project.projectTypeLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: mutedColor(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              buildInfoChip(context, Icons.flag_rounded, project.statusLabel),
              const SizedBox(width: 10),
              buildInfoChip(
                context,
                Icons.calendar_today_rounded,
                project.deadlineLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildInfoChip(BuildContext context, IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDescriptionCard(BuildContext context) {
    final description = project.description?.trim();

    return buildSectionCard(
      context,
      title: 'Overview',
      icon: Icons.notes_rounded,
      child: Text(
        description == null || description.isEmpty
            ? 'No project description yet.'
            : description,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: mutedColor(context),
          height: 1.55,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget buildScheduleCard(BuildContext context) {
    return buildSectionCard(
      context,
      title: 'Schedule',
      icon: Icons.event_available_rounded,
      child: Column(
        children: [
          buildDetailRow(context, 'Deadline', formattedDeadline),
          const SizedBox(height: 10),
          buildDetailRow(context, 'Status', project.statusLabel),
          const SizedBox(height: 10),
          buildDetailRow(context, 'Progress', '${(progress * 100).round()}%'),
          const SizedBox(height: 10),
          buildDetailRow(
            context,
            'Tasks',
            '$completedTaskCount done / ${projectTasks.length} total',
          ),
        ],
      ),
    );
  }

  Widget buildProgressControlCard(BuildContext context) {
    final percentage = (progress * 100).round();

    return buildSectionCard(
      context,
      title: 'Project Control Center',
      icon: Icons.speed_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: buildMetricTile(
                  context,
                  label: 'Progress',
                  value: '$percentage%',
                  color: statusColor(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: buildMetricTile(
                  context,
                  label: 'Remaining',
                  value: '$remainingTaskCount',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: buildMetricTile(
                  context,
                  label: 'Completed',
                  value: '$completedTaskCount',
                  color: PlanoraTheme.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: buildMetricTile(
                  context,
                  label: 'Overdue',
                  value: '$overdueTaskCount',
                  color: overdueTaskCount == 0
                      ? PlanoraTheme.info
                      : PlanoraTheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildMetricTile(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: mutedColor(context),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildNextDueCard(BuildContext context) {
    final taskItem = nextDueTask;

    return buildSectionCard(
      context,
      title: 'Next Deadline',
      icon: Icons.event_note_rounded,
      child: taskItem == null
          ? buildInlineMessage(
              context,
              icon: Icons.event_available_rounded,
              message: 'No upcoming task deadlines found.',
            )
          : buildTaskRow(context, taskItem),
    );
  }

  Widget buildRiskAndRecommendationCard(BuildContext context) {
    final preview = riskPreview;

    if (isLoadingRisk) {
      return buildSectionCard(
        context,
        title: 'Risk and Recommendations',
        icon: Icons.warning_amber_rounded,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (preview == null) {
      return buildSectionCard(
        context,
        title: 'Risk and Recommendations',
        icon: Icons.warning_amber_rounded,
        child: buildInlineMessage(
          context,
          icon: Icons.insights_rounded,
          message:
              riskErrorMessage ??
              'Risk analysis will appear after enough project activity.',
        ),
      );
    }

    final riskColor = switch (preview.riskLevel) {
      'high' => PlanoraTheme.error,
      'medium' => PlanoraTheme.warning,
      'low' => PlanoraTheme.success,
      _ => Theme.of(context).colorScheme.primary,
    };

    return buildSectionCard(
      context,
      title: 'Risk and Recommendations',
      icon: Icons.warning_amber_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: riskColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${preview.riskLevel.toUpperCase()} risk',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: riskColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${preview.predictedDelayDays}d delay',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: riskColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (preview.reason.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              preview.reason,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: mutedColor(context),
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (preview.recommendation.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      preview.recommendation,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: mutedColor(context),
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildStatusBreakdownCard(BuildContext context) {
    return buildSectionCard(
      context,
      title: 'Task Status Breakdown',
      icon: Icons.donut_large_rounded,
      child: Column(
        children: [
          for (final entry in taskStatusCounts.entries) ...[
            buildBreakdownRow(
              context,
              label: entry.key.label,
              count: entry.value,
              total: totalTaskCount,
              color: taskStatusColor(entry.key),
            ),
            if (entry.key != TaskStatus.values.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget buildBreakdownRow(
    BuildContext context, {
    required String label,
    required int count,
    required int total,
    required Color color,
  }) {
    final ratio = total == 0 ? 0.0 : count / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
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
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 7,
            color: color,
            backgroundColor: color.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }

  Color taskStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return PlanoraTheme.info;
      case TaskStatus.inProgress:
        return Theme.of(context).colorScheme.primary;
      case TaskStatus.completed:
        return PlanoraTheme.success;
      case TaskStatus.blocked:
        return PlanoraTheme.warning;
    }
  }

  Widget buildMilestonesCard(BuildContext context) {
    final sections = <String, int>{};

    for (final item in projectTasks) {
      final section = item.task.sectionName?.trim();

      if (section == null || section.isEmpty) {
        continue;
      }

      sections[section] = (sections[section] ?? 0) + 1;
    }

    if (sections.isEmpty) {
      return buildSectionCard(
        context,
        title: 'Timeline and Milestones',
        icon: Icons.timeline_rounded,
        child: buildInlineMessage(
          context,
          icon: Icons.timeline_rounded,
          message: 'Milestones will appear when task sections are available.',
        ),
      );
    }

    return buildSectionCard(
      context,
      title: 'Timeline and Milestones',
      icon: Icons.timeline_rounded,
      child: Column(
        children: [
          for (final entry in sections.entries) ...[
            buildDetailRow(context, entry.key, '${entry.value} tasks'),
            if (entry.key != sections.keys.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget buildAiPlanCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Planora AI',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            projectTasks.isEmpty
                ? 'Create a structured plan from this project context.'
                : 'Improve this plan with more focused tasks or a rebuilt schedule.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: mutedColor(context),
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isGeneratingAiPlan ? null : showAiPlanSheet,
              icon: isGeneratingAiPlan
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.bolt_rounded),
              label: Text(
                isGeneratingAiPlan
                    ? 'Generating Plan...'
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
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : const Icon(Icons.calendar_month_rounded),
              label: Text(
                isPreviewingSchedule
                    ? 'Checking Schedule...'
                    : 'Reschedule remaining tasks',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> previewSmartSchedule() async {
    setState(() {
      isPreviewingSchedule = true;
    });

    try {
      final preview = await _insightsApi.previewSmartSchedule(project: project);

      if (!mounted) {
        return;
      }

      setState(() {
        isPreviewingSchedule = false;
      });

      await showSmartSchedulePreviewSheet(preview);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isPreviewingSchedule = false;
      });
      showMessage(error.message);
    } catch (error, stackTrace) {
      debugPrint('Smart schedule preview failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        isPreviewingSchedule = false;
      });
      showMessage('Could not preview a new schedule.');
    }
  }

  Future<void> showSmartSchedulePreviewSheet(
    SmartSchedulePreviewModel preview,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final isDark = PlanoraTheme.isDark(sheetContext);
            final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;

            Future<void> applySchedule() async {
              setSheetState(() {
                isApplyingSchedule = true;
              });

              try {
                await _insightsApi.applySmartSchedule(project: project);

                if (!mounted || !sheetContext.mounted) {
                  return;
                }

                Navigator.of(sheetContext).pop();
                await loadProjectTasks(project);
                showMessage('Schedule updated.');
              } on ApiException catch (error) {
                if (!mounted) {
                  return;
                }

                showMessage(error.message);
              } catch (error, stackTrace) {
                debugPrint('Smart schedule apply failed: $error');
                debugPrintStack(stackTrace: stackTrace);

                if (!mounted) {
                  return;
                }

                showMessage('Could not apply the schedule.');
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() {
                    isApplyingSchedule = false;
                  });
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.86,
                ),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
                decoration: BoxDecoration(
                  color: isDark ? PlanoraTheme.darkSurface : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: PlanoraTheme.floatingShadowFor(sheetContext),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 5,
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
                          Icon(
                            Icons.calendar_month_rounded,
                            color: Theme.of(sheetContext).colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Smart Schedule Preview',
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      buildDetailRow(
                        sheetContext,
                        'Schedulable',
                        '${preview.schedulableTaskCount} of ${preview.totalTasks} tasks',
                      ),
                      const SizedBox(height: 10),
                      buildDetailRow(
                        sheetContext,
                        'Estimated hours',
                        preview.estimatedTotalHours.toStringAsFixed(1),
                      ),
                      if (preview.warnings.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        for (final warning in preview.warnings)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: buildInlineMessage(
                              sheetContext,
                              icon: Icons.info_outline_rounded,
                              message: warning,
                            ),
                          ),
                      ],
                      const SizedBox(height: 14),
                      for (final item in preview.tasks.take(8)) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              sheetContext,
                            ).colorScheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Suggested: ${formatShortDate(item.suggestedDueDate)}',
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: item.isAfterProjectDeadline
                                          ? PlanoraTheme.error
                                          : mutedColor(sheetContext),
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: isApplyingSchedule ? null : applySchedule,
                          icon: isApplyingSchedule
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(
                            isApplyingSchedule
                                ? 'Applying...'
                                : 'Apply schedule',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void showAiPlanSheet() {
    final promptController = TextEditingController(text: defaultAiPrompt);
    var preferredTaskCount = projectTasks.isEmpty ? 8 : 5;
    var overwriteExistingTasks = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = PlanoraTheme.isDark(context);
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.86,
                ),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
                decoration: BoxDecoration(
                  color: isDark ? PlanoraTheme.darkSurface : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isDark
                                ? PlanoraTheme.darkBorder
                                : PlanoraTheme.border,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: PlanoraTheme.primaryGradientFor(
                                context,
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Improve Plan with AI',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: promptController,
                        minLines: 4,
                        maxLines: 6,
                        maxLength: 500,
                        decoration: InputDecoration(
                          labelText: 'Planning prompt',
                          alignLabelWithHint: true,
                          filled: true,
                          fillColor: isDark
                              ? PlanoraTheme.darkBackground
                              : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.format_list_numbered_rounded),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Task count',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: preferredTaskCount,
                                items: [
                                  for (final value in [3, 4, 5, 6, 8, 10, 12])
                                    DropdownMenuItem<int>(
                                      value: value,
                                      child: Text(value.toString()),
                                    ),
                                ],
                                onChanged: isGeneratingAiPlan
                                    ? null
                                    : (value) {
                                        if (value == null) return;
                                        setSheetState(() {
                                          preferredTaskCount = value;
                                        });
                                      },
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (projectTasks.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        SwitchListTile.adaptive(
                          value: overwriteExistingTasks,
                          onChanged: isGeneratingAiPlan
                              ? null
                              : (value) {
                                  setSheetState(() {
                                    overwriteExistingTasks = value;
                                  });
                                },
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Replace existing tasks'),
                          subtitle: Text(
                            overwriteExistingTasks
                                ? 'Current project tasks will be replaced.'
                                : 'Generated tasks will be appended.',
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isGeneratingAiPlan
                              ? null
                              : () => generateAiPlanFromSheet(
                                  sheetContext: sheetContext,
                                  setSheetState: setSheetState,
                                  prompt: promptController.text.trim(),
                                  preferredTaskCount: preferredTaskCount,
                                  overwriteExistingTasks:
                                      overwriteExistingTasks,
                                ),
                          child: isGeneratingAiPlan
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Generate Tasks'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(promptController.dispose);
  }

  String get defaultAiPrompt {
    final description = project.description?.trim();

    if (description != null && description.isNotEmpty) {
      return 'Create a practical task plan for ${project.title}. Context: $description';
    }

    return 'Create a practical task plan for ${project.title}.';
  }

  Future<void> generateAiPlanFromSheet({
    required BuildContext sheetContext,
    required StateSetter setSheetState,
    required String prompt,
    required int preferredTaskCount,
    required bool overwriteExistingTasks,
  }) async {
    final planningPrompt = prompt.isEmpty ? defaultAiPrompt : prompt;

    if (isGeneratingAiPlan) {
      return;
    }

    setSheetState(() {
      isGeneratingAiPlan = true;
    });
    setState(() {
      isGeneratingAiPlan = true;
    });

    try {
      final response = await _aiPlanApi.generatePlan(
        project: project,
        prompt: planningPrompt,
        generateTasks: true,
        overwriteExistingTasks: overwriteExistingTasks,
        preferredTaskCount: preferredTaskCount,
      );

      if (!mounted) return;

      setState(() {
        isGeneratingAiPlan = false;
      });

      if (sheetContext.mounted) {
        Navigator.of(sheetContext).pop();
      }

      await loadProjectTasks(project);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI created ${response.tasksCreated} project tasks.'),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Project AI task generation failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      if (sheetContext.mounted) {
        setSheetState(() {
          isGeneratingAiPlan = false;
        });
      }

      setState(() {
        isGeneratingAiPlan = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not generate AI tasks. Please try again.'),
        ),
      );
    }
  }

  Widget buildTasksCard(BuildContext context) {
    Widget child;

    if (isLoadingTasks) {
      child = const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(),
        ),
      );
    } else if (tasksErrorMessage != null) {
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildInlineMessage(
            context,
            icon: Icons.wifi_off_rounded,
            message: tasksErrorMessage!,
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => loadProjectTasks(project),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ],
      );
    } else if (projectTasks.isEmpty) {
      child = buildInlineMessage(
        context,
        icon: Icons.checklist_rounded,
        message: 'No tasks found for this project.',
      );
    } else {
      final visibleTasks = projectTasks.take(8).toList();

      child = Column(
        children: [
          for (final item in visibleTasks) ...[
            buildTaskRow(context, item),
            if (item != visibleTasks.last) const SizedBox(height: 10),
          ],
          if (projectTasks.length > visibleTasks.length) ...[
            const SizedBox(height: 10),
            Text(
              '+${projectTasks.length - visibleTasks.length} more tasks',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: mutedColor(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      );
    }

    return buildSectionCard(
      context,
      title: 'Project Tasks',
      icon: Icons.checklist_rounded,
      child: child,
    );
  }

  Widget buildTaskRow(BuildContext context, TaskListItem item) {
    final task = item.task;
    final priorityColor = taskPriorityColor(task.priority);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            task.isCompleted
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: task.isCompleted
                ? PlanoraTheme.success
                : Theme.of(context).colorScheme.primary,
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '${task.status.label} - ${task.dueDateLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: task.isOverdue
                        ? PlanoraTheme.error
                        : mutedColor(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: priorityColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              task.priority.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: priorityColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color taskPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return PlanoraTheme.success;
      case TaskPriority.medium:
        return PlanoraTheme.info;
      case TaskPriority.high:
        return Theme.of(context).colorScheme.primary;
    }
  }

  Widget buildMembersCard(BuildContext context) {
    Widget child;
    final title = project.isTeamProject ? 'Project Members' : 'Collaborators';
    final emptyMessage = project.isTeamProject
        ? 'No project members returned by the API.'
        : 'Only you are on this personal project right now.';

    if (isLoadingMembers) {
      child = const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(),
        ),
      );
    } else if (membersErrorMessage != null) {
      child = buildInlineMessage(
        context,
        icon: Icons.wifi_off_rounded,
        message: membersErrorMessage!,
      );
    } else if (members.isEmpty) {
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildInviteMemberButton(context),
          const SizedBox(height: 12),
          buildInlineMessage(
            context,
            icon: Icons.group_off_rounded,
            message: emptyMessage,
          ),
        ],
      );
    } else {
      child = Column(
        children: [
          buildInviteMemberButton(context),
          const SizedBox(height: 12),
          for (final member in members) ...[
            buildMemberRow(context, member),
            if (member != members.last) const SizedBox(height: 10),
          ],
        ],
      );
    }

    return buildSectionCard(
      context,
      title: title,
      icon: project.isTeamProject
          ? Icons.groups_2_rounded
          : Icons.person_add_alt_1_rounded,
      child: child,
    );
  }

  Widget buildInviteMemberButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: showInviteMemberSheet,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(
          project.isTeamProject ? 'Invite Member' : 'Invite collaborator',
        ),
      ),
    );
  }

  Future<void> showInviteMemberSheet() async {
    final emailController = TextEditingController();
    var selectedRole = 'member';
    var isInviting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final isDark = PlanoraTheme.isDark(sheetContext);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                decoration: BoxDecoration(
                  color: isDark ? PlanoraTheme.darkSurface : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: PlanoraTheme.floatingShadowFor(sheetContext),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isDark
                                ? PlanoraTheme.darkBorder
                                : PlanoraTheme.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Icon(
                            Icons.person_add_alt_1_rounded,
                            color: Theme.of(sheetContext).colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              project.isTeamProject
                                  ? 'Invite Project Member'
                                  : 'Invite collaborator',
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          IconButton(
                            onPressed: isInviting
                                ? null
                                : () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: emailController,
                        enabled: !isInviting,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email or username',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          prefixIcon: Icon(Icons.verified_user_outlined),
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
                        ],
                        onChanged: isInviting
                            ? null
                            : (value) {
                                if (value == null) return;
                                setSheetState(() {
                                  selectedRole = value;
                                });
                              },
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isInviting
                              ? null
                              : () async {
                                  final emailOrUsername = emailController.text
                                      .trim();

                                  if (emailOrUsername.isEmpty) {
                                    showMessage('Enter an email or username.');
                                    return;
                                  }

                                  setSheetState(() {
                                    isInviting = true;
                                  });

                                  var shouldCloseSheet = false;

                                  try {
                                    await _projectsApi.inviteProjectMember(
                                      project: project,
                                      emailOrUsername: emailOrUsername,
                                      role: selectedRole,
                                    );

                                    if (!mounted || !sheetContext.mounted) {
                                      return;
                                    }

                                    await loadProjectMembers(project);

                                    if (!mounted) return;

                                    showMessage('Project member added.');
                                    shouldCloseSheet = true;
                                  } on ApiException catch (error) {
                                    if (!mounted) return;
                                    showMessage(error.message);
                                  } catch (error) {
                                    debugPrint(
                                      'Project member invite failed: $error',
                                    );
                                    if (!mounted) return;
                                    showMessage(
                                      'Could not invite project member.',
                                    );
                                  } finally {
                                    if (sheetContext.mounted &&
                                        !shouldCloseSheet) {
                                      setSheetState(() {
                                        isInviting = false;
                                      });
                                    }
                                  }

                                  if (shouldCloseSheet &&
                                      sheetContext.mounted) {
                                    Navigator.of(sheetContext).pop();
                                  }
                                },
                          child: isInviting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  project.isTeamProject
                                      ? 'Invite Member'
                                      : 'Invite collaborator',
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
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

  Future<void> showDeleteProjectDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete project?'),
          content: const Text(
            'This will permanently delete the project and its tasks. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: PlanoraTheme.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await deleteProject();
  }

  Future<void> deleteProject() async {
    setState(() {
      isDeletingProject = true;
    });

    try {
      await _projectsApi.deleteProject(project);

      if (!mounted) {
        return;
      }

      showMessage('Project deleted.');
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isDeletingProject = false;
      });
      showMessage(
        error.statusCode == 403 || error.statusCode == 404
            ? 'You do not have permission to delete this project.'
            : error.message,
      );
    } catch (error, stackTrace) {
      debugPrint('Project delete failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        isDeletingProject = false;
      });
      showMessage('Could not delete project. Please try again.');
    }
  }

  Widget buildDangerZoneCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(context).copyWith(
        border: Border.all(color: PlanoraTheme.error.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: PlanoraTheme.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Danger Zone',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: PlanoraTheme.error,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Delete this project and all of its tasks permanently.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: mutedColor(context),
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: PlanoraTheme.error,
                side: BorderSide(
                  color: PlanoraTheme.error.withValues(alpha: 0.5),
                ),
              ),
              onPressed: isDeletingProject ? null : showDeleteProjectDialog,
              icon: isDeletingProject
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline_rounded),
              label: Text(
                isDeletingProject ? 'Deleting project...' : 'Delete project',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDetailRow(BuildContext context, String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: mutedColor(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget buildInlineMessage(
    BuildContext context, {
    required IconData icon,
    required String message,
  }) {
    return Row(
      children: [
        Icon(icon, color: mutedColor(context)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: mutedColor(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildMemberRow(BuildContext context, ProjectMemberModel member) {
    final profilePic = member.profilePic;
    final hasProfilePic = profilePic != null && profilePic.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            backgroundImage: hasProfilePic ? NetworkImage(profilePic) : null,
            onBackgroundImageError: hasProfilePic
                ? (_, _) {
                    debugPrint(
                      'Could not load profile image for project member.',
                    );
                  }
                : null,
            child: hasProfilePic
                ? null
                : Text(
                    member.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
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
                const SizedBox(height: 3),
                Text(
                  member.email == null
                      ? member.roleLabel
                      : '${member.email} - ${member.roleLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: mutedColor(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.verified_user_outlined, color: mutedColor(context)),
        ],
      ),
    );
  }

  Widget buildErrorBanner(BuildContext context) {
    final message = errorMessage;

    if (message == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PlanoraTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PlanoraTheme.error.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: PlanoraTheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: PlanoraTheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: RefreshIndicator(
                onRefresh: loadProjectDetails,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: [
                    buildHeader(context),
                    const SizedBox(height: 18),
                    if (isLoadingProject)
                      const LinearProgressIndicator(minHeight: 3),
                    if (errorMessage != null) ...[
                      buildErrorBanner(context),
                      const SizedBox(height: 14),
                    ],
                    buildHeroCard(context),
                    const SizedBox(height: 16),
                    buildProgressControlCard(context),
                    const SizedBox(height: 16),
                    buildNextDueCard(context),
                    const SizedBox(height: 16),
                    buildRiskAndRecommendationCard(context),
                    const SizedBox(height: 16),
                    buildStatusBreakdownCard(context),
                    const SizedBox(height: 16),
                    buildDescriptionCard(context),
                    const SizedBox(height: 16),
                    buildScheduleCard(context),
                    const SizedBox(height: 16),
                    buildAiPlanCard(context),
                    const SizedBox(height: 16),
                    buildTasksCard(context),
                    const SizedBox(height: 16),
                    buildMilestonesCard(context),
                    const SizedBox(height: 16),
                    buildMembersCard(context),
                    const SizedBox(height: 16),
                    buildDangerZoneCard(context),
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
