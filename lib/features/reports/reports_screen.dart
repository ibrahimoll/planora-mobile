import 'package:flutter/material.dart';

import '../../core/theme/planora_theme.dart';
import '../auth/data/project_api.dart';
import '../auth/models/project_models.dart';
import '../tasks/data/tasks_api.dart';
import '../tasks/models/task_models.dart';
import 'data/reports_api.dart';

class ReportsScreen extends StatefulWidget {
  final ProjectsApi projectsApi;
  final ReportsApi reportsApi;
  final TasksApi tasksApi;

  const ReportsScreen({
    super.key,
    this.projectsApi = const ProjectsApi(),
    this.reportsApi = const ReportsApi(),
    this.tasksApi = const TasksApi(),
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final ProjectsApi _projectsApi;
  late final ReportsApi _reportsApi;
  late final TasksApi _tasksApi;

  bool isLoadingProjects = true;
  bool isLoadingReport = false;
  bool isLoadingTaskSummary = false;
  String? errorMessage;
  String? reportMessage;
  String? taskSummaryMessage;
  List<ProjectModel> projects = [];
  List<TaskListItem> allTasks = [];
  List<ReportExportModel> exports = [];
  ProjectModel? selectedProject;
  ProjectReportModel? report;

  @override
  void initState() {
    super.initState();
    _projectsApi = widget.projectsApi;
    _reportsApi = widget.reportsApi;
    _tasksApi = widget.tasksApi;
    loadProjects();
  }

  Future<void> loadProjects() async {
    setState(() {
      isLoadingProjects = true;
      isLoadingTaskSummary = true;
      errorMessage = null;
      taskSummaryMessage = null;
    });

    try {
      final loadedProjects = await _projectsApi.getProjects();
      var loadedTasks = <TaskListItem>[];

      try {
        final taskBoard = await _tasksApi.getTasks();
        loadedTasks = taskBoard.tasks;

        if (taskBoard.isFromCache) {
          taskSummaryMessage =
              'Could not connect. Showing last saved task data.';
        }
      } catch (error, stackTrace) {
        debugPrint('Reports task summary load failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        taskSummaryMessage = 'Could not load task summary.';
      }

      if (!mounted) {
        return;
      }

      setState(() {
        projects = loadedProjects;
        allTasks = loadedTasks;
        selectedProject = loadedProjects.isEmpty ? null : loadedProjects.first;
        isLoadingProjects = false;
        isLoadingTaskSummary = false;
      });

      if (loadedProjects.isNotEmpty) {
        await loadReport(loadedProjects.first);
      }
    } catch (error, stackTrace) {
      debugPrint('Reports project load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        isLoadingProjects = false;
        isLoadingTaskSummary = false;
        errorMessage = 'Could not load projects for reports.';
      });
    }
  }

  Future<void> loadReport(ProjectModel project) async {
    setState(() {
      selectedProject = project;
      isLoadingReport = true;
      reportMessage = null;
    });

    try {
      final loadedReport = await _reportsApi.getProjectReport(
        project.projectId,
      );
      final loadedExports = await _reportsApi.getExportHistory(
        projectId: project.projectId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        report = loadedReport;
        exports = loadedExports;
        isLoadingReport = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Project report load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        isLoadingReport = false;
        reportMessage = 'Could not generate this report right now.';
        report = buildLocalProjectReport(project);
      });
    }
  }

  ProjectReportModel buildLocalProjectReport(ProjectModel project) {
    final projectTasks = allTasks
        .where((item) => item.project.projectId == project.projectId)
        .toList();
    final completed = projectTasks
        .where((item) => item.task.isCompleted)
        .length;
    final overdue = projectTasks.where((item) => item.task.isOverdue).length;
    final total = projectTasks.length;
    final pending = total - completed;
    final statusCounts = {
      for (final status in TaskStatus.values)
        status.value: projectTasks
            .where((item) => item.task.status == status)
            .length,
    };
    final priorityCounts = {
      for (final priority in TaskPriority.values)
        priority.value: projectTasks
            .where((item) => item.task.priority == priority)
            .length,
    };

    return ProjectReportModel(
      generatedAt: DateTime.now(),
      totalTasks: total,
      completedTasks: completed,
      pendingTasks: pending,
      overdueTasks: overdue,
      completionPercentage: total == 0 ? 0 : (completed / total) * 100,
      statusCounts: statusCounts,
      priorityCounts: priorityCounts,
      exportId: null,
    );
  }

  int get activeProjectCount {
    return projects.where((project) => project.isActive).length;
  }

  int get completedProjectCount {
    return projects.where((project) => project.isCompleted).length;
  }

  int get overdueTaskCount {
    return allTasks.where((item) => item.task.isOverdue).length;
  }

  int get completedTaskCount {
    return allTasks.where((item) => item.task.isCompleted).length;
  }

  double get portfolioCompletion {
    if (allTasks.isEmpty) {
      return 0;
    }

    return completedTaskCount / allTasks.length;
  }

  Color mutedColor(BuildContext context) {
    return PlanoraTheme.isDark(context)
        ? PlanoraTheme.darkTextSecondary
        : PlanoraTheme.textSecondary;
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
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 18),
                    Expanded(child: _buildBody(context)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Reports',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (isLoadingProjects) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return _buildState(
        context,
        icon: Icons.wifi_off_rounded,
        title: errorMessage!,
        action: 'Try Again',
        onAction: loadProjects,
      );
    }

    if (projects.isEmpty) {
      return _buildState(
        context,
        icon: Icons.folder_open_rounded,
        title: 'Create a project to generate reports.',
      );
    }

    return RefreshIndicator(
      onRefresh: selectedProject == null
          ? loadProjects
          : () => loadReport(selectedProject!),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          _buildPortfolioSummary(context),
          const SizedBox(height: 16),
          _buildPortfolioStatusBreakdown(context),
          const SizedBox(height: 16),
          _buildProjectSelector(context),
          const SizedBox(height: 16),
          if (taskSummaryMessage != null) ...[
            _buildMessageCard(context, taskSummaryMessage!),
            const SizedBox(height: 14),
          ],
          if (isLoadingReport)
            const LinearProgressIndicator(minHeight: 3)
          else if (reportMessage != null)
            _buildMessageCard(context, reportMessage!)
          else
            const SizedBox(height: 3),
          const SizedBox(height: 14),
          _buildReportSummary(context),
          const SizedBox(height: 16),
          _buildCountBreakdown(context),
          const SizedBox(height: 16),
          _buildExportHistory(context),
        ],
      ),
    );
  }

  Widget _buildProjectSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(context),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedProject?.projectId,
          isExpanded: true,
          borderRadius: BorderRadius.circular(16),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
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
          onChanged: (projectId) {
            if (projectId == null) {
              return;
            }

            final project = projects.firstWhere(
              (item) => item.projectId == projectId,
              orElse: () => projects.first,
            );

            loadReport(project);
          },
        ),
      ),
    );
  }

  Widget _buildPortfolioSummary(BuildContext context) {
    final progress = portfolioCompletion.clamp(0, 1).toDouble();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Planora Insights',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              if (isLoadingTaskSummary)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            minHeight: 9,
            borderRadius: BorderRadius.circular(999),
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMetric(
                context,
                label: 'Projects',
                value: '${projects.length}',
              ),
              _buildMetric(
                context,
                label: 'Active',
                value: '$activeProjectCount',
              ),
              _buildMetric(
                context,
                label: 'Completed',
                value: '$completedProjectCount',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildMetric(
                context,
                label: 'Tasks',
                value: '${allTasks.length}',
              ),
              _buildMetric(
                context,
                label: 'Done',
                value: '$completedTaskCount',
              ),
              _buildMetric(
                context,
                label: 'Overdue',
                value: '$overdueTaskCount',
              ),
            ],
          ),
          if (selectedProject != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isLoadingReport
                    ? null
                    : () => loadReport(selectedProject!),
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Generate export snapshot'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPortfolioStatusBreakdown(BuildContext context) {
    final counts = {
      for (final status in TaskStatus.values)
        status.label: allTasks
            .where((item) => item.task.status == status)
            .length,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Task Status',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          if (allTasks.isEmpty)
            Text(
              'No task activity loaded yet.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: mutedColor(context),
                fontWeight: FontWeight.w700,
              ),
            )
          else
            for (final entry in counts.entries) ...[
              _buildBreakdownBar(
                context,
                label: entry.key,
                count: entry.value,
                total: allTasks.length,
              ),
              if (entry.key != counts.keys.last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _buildBreakdownBar(
    BuildContext context, {
    required String label,
    required int count,
    required int total,
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
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: ratio,
          minHeight: 7,
          borderRadius: BorderRadius.circular(999),
          color: Theme.of(context).colorScheme.primary,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.12),
        ),
      ],
    );
  }

  Widget _buildReportSummary(BuildContext context) {
    final currentReport = report ?? const ProjectReportModel.empty();
    final progress = (currentReport.completionPercentage / 100).clamp(0, 1);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Project Report',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              if (currentReport.generatedAt != null)
                Text(
                  formatShortDate(currentReport.generatedAt!),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: mutedColor(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress.toDouble(),
            minHeight: 9,
            borderRadius: BorderRadius.circular(999),
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMetric(
                context,
                label: 'Total',
                value: '${currentReport.totalTasks}',
              ),
              _buildMetric(
                context,
                label: 'Completed',
                value: '${currentReport.completedTasks}',
              ),
              _buildMetric(
                context,
                label: 'Overdue',
                value: '${currentReport.overdueTasks}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: mutedColor(context),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountBreakdown(BuildContext context) {
    final currentReport = report ?? const ProjectReportModel.empty();
    final entries = [
      ...currentReport.statusCounts.entries.map(
        (entry) => MapEntry('Status: ${entry.key}', entry.value),
      ),
      ...currentReport.priorityCounts.entries.map(
        (entry) => MapEntry('Priority: ${entry.key}', entry.value),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Breakdown',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Text(
              'No breakdown fields returned yet.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: mutedColor(context),
                fontWeight: FontWeight.w700,
              ),
            )
          else
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      '${entry.value}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildExportHistory(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Export History',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          if (exports.isEmpty)
            Text(
              'No exports found for this project.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: mutedColor(context),
                fontWeight: FontWeight.w700,
              ),
            )
          else
            for (final item in exports.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${item.reportType} - ${item.exportFormat}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      formatShortDate(item.createdAt),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: mutedColor(context),
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

  Widget _buildMessageCard(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PlanoraTheme.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildState(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? action,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 40),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (action != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(action)),
          ],
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return BoxDecoration(
      color: isDark ? PlanoraTheme.darkSurface : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
      ),
      boxShadow: PlanoraTheme.cardShadowFor(context),
    );
  }
}
