import 'package:flutter/material.dart';

import '../../core/theme/planora_theme.dart';
import 'data/productivity_insights_api.dart';
import 'models/productivity_insights_model.dart';

class ProductivityInsightsScreen extends StatefulWidget {
  final ProductivityInsightsApi insightsApi;

  const ProductivityInsightsScreen({
    super.key,
    this.insightsApi = const ProductivityInsightsApi(),
  });

  @override
  State<ProductivityInsightsScreen> createState() =>
      _ProductivityInsightsScreenState();
}

class _ProductivityInsightsScreenState extends State<ProductivityInsightsScreen> {
  late final ProductivityInsightsApi _insightsApi;

  bool isLoading = true;
  String? errorMessage;
  ProductivityInsightsModel? insights;

  @override
  void initState() {
    super.initState();
    _insightsApi = widget.insightsApi;
    loadInsights();
  }

  Future<void> loadInsights() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final loadedInsights = await _insightsApi.getMyInsights();

      if (!mounted) return;

      setState(() {
        insights = loadedInsights;
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Productivity insights load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        errorMessage = 'Could not load productivity insights.';
        isLoading = false;
      });
    }
  }

  Color mutedColor(BuildContext context) {
    return PlanoraTheme.isDark(context)
        ? PlanoraTheme.darkTextMuted
        : PlanoraTheme.textSecondary;
  }

  BoxDecoration cardDecoration(BuildContext context, {double radius = 24}) {
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

  String percentLabel(double value) {
    return '${value.clamp(0, 100).round()}%';
  }

  String formatDate(DateTime? value) {
    if (value == null) return 'Just now';

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();

    return '$day/$month/$year';
  }

  Color healthColor(String healthStatus) {
    switch (healthStatus.toLowerCase()) {
      case 'healthy':
      case 'good':
      case 'on_track':
        return PlanoraTheme.success;
      case 'at_risk':
      case 'warning':
        return PlanoraTheme.warning;
      case 'critical':
      case 'blocked':
      case 'overdue':
        return PlanoraTheme.error;
      default:
        return PlanoraTheme.secondaryPurple;
    }
  }

  String cleanLabel(String value) {
    if (value.trim().isEmpty) return 'Unknown';
    return value.replaceAll('_', ' ');
  }

  Widget buildHeader(BuildContext context) {
    final currentInsights = insights;

    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 44,
            height: 44,
            decoration: cardDecoration(context, radius: 999),
            child: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Productivity Insights',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                currentInsights == null
                    ? 'Personal progress overview'
                    : 'Updated ${formatDate(currentInsights.generatedAt)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: mutedColor(context),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildHeroSummary(BuildContext context, ProductivityInsightsModel data) {
    final summary = data.summary;
    final workload = data.workload;
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: PlanoraTheme.primaryGradientFor(context),
        borderRadius: BorderRadius.circular(30),
        boxShadow: PlanoraTheme.floatingShadowFor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  workload.overloaded ? 'Overloaded' : 'Balanced',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            percentLabel(summary.completionPercentage),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'assigned task completion',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: isDark ? 0.84 : 0.90),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: buildHeroMetric(
                  context,
                  '${summary.overdueAssignedTasks}',
                  'overdue',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: buildHeroMetric(
                  context,
                  '${workload.estimatedHoursRemaining.toStringAsFixed(1)}h',
                  'remaining',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: buildHeroMetric(
                  context,
                  '${workload.highPriorityOpenTasks}',
                  'high priority',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildHeroMetric(BuildContext context, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  Widget buildSummaryGrid(BuildContext context, ProductivityInsightsModel data) {
    final summary = data.summary;
    final workload = data.workload;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildSectionTitle(context, 'Summary'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: [
            buildMetricCard(
              context,
              icon: Icons.folder_copy_rounded,
              label: 'Projects',
              value: '${summary.totalProjects}',
            ),
            buildMetricCard(
              context,
              icon: Icons.play_circle_outline_rounded,
              label: 'Active',
              value: '${summary.activeProjects}',
            ),
            buildMetricCard(
              context,
              icon: Icons.task_alt_rounded,
              label: 'Tasks',
              value: '${summary.assignedTasks}',
            ),
            buildMetricCard(
              context,
              icon: Icons.pending_actions_rounded,
              label: 'Open',
              value: '${workload.assignedIncompleteTasks}',
            ),
          ],
        ),
      ],
    );
  }

  Widget buildMetricCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final color = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(context, radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 2),
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
        ],
      ),
    );
  }

  Widget buildProjectsHealth(BuildContext context, ProductivityInsightsModel data) {
    final projects = data.projects.take(4).toList();

    if (projects.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildSectionTitle(context, 'Project Health'),
        const SizedBox(height: 10),
        for (final project in projects) ...[
          buildProjectHealthTile(context, project),
          if (project != projects.last) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget buildProjectHealthTile(BuildContext context, ProjectInsightModel project) {
    final color = healthColor(project.healthStatus);
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(context, radius: 22),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.folder_rounded, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? PlanoraTheme.darkTextPrimary
                            : PlanoraTheme.textPrimary,
                      ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: (project.completionPercentage / 100).clamp(0, 1),
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${percentLabel(project.completionPercentage)} complete · ${project.overdueTasks} overdue',
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
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              cleanLabel(project.healthStatus),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRecommendations(BuildContext context, ProductivityInsightsModel data) {
    if (data.recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildSectionTitle(context, 'Recommendations'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDecoration(context, radius: 22),
          child: Column(
            children: [
              for (var index = 0; index < data.recommendations.length; index++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 15,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        data.recommendations[index],
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: mutedColor(context),
                              height: 1.38,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                if (index != data.recommendations.length - 1)
                  const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
    );
  }

  Widget buildStateCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? message,
    String? buttonText,
    VoidCallback? onPressed,
    bool showSpinner = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: cardDecoration(context),
      child: Column(
        children: [
          if (showSpinner)
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            )
          else
            Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mutedColor(context),
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
          if (buttonText != null && onPressed != null) ...[
            const SizedBox(height: 14),
            ElevatedButton(onPressed: onPressed, child: Text(buttonText)),
          ],
        ],
      ),
    );
  }

  Widget buildContent(BuildContext context) {
    if (isLoading) {
      return buildStateCard(
        context,
        icon: Icons.sync_rounded,
        title: 'Loading productivity insights...',
        message: 'Checking your progress, workload, and project health.',
        showSpinner: true,
      );
    }

    if (errorMessage != null) {
      return buildStateCard(
        context,
        icon: Icons.wifi_off_rounded,
        title: errorMessage!,
        message: 'Refresh when the backend is reachable.',
        buttonText: 'Try Again',
        onPressed: loadInsights,
      );
    }

    final data = insights;
    if (data == null) {
      return buildStateCard(
        context,
        icon: Icons.insights_rounded,
        title: 'No insights yet',
        message: 'Create projects and tasks to generate productivity insights.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildHeroSummary(context, data),
        const SizedBox(height: 18),
        buildSummaryGrid(context, data),
        const SizedBox(height: 18),
        buildProjectsHealth(context, data),
        const SizedBox(height: 18),
        buildRecommendations(context, data),
      ],
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
              constraints: const BoxConstraints(maxWidth: 540),
              child: RefreshIndicator(
                onRefresh: loadInsights,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: [
                    buildHeader(context),
                    const SizedBox(height: 20),
                    buildContent(context),
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
