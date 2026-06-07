import 'package:flutter/material.dart';

import '../../core/theme/planora_theme.dart';
import '../auth/data/project_api.dart';
import '../auth/models/project_models.dart';

class ProjectDetailScreen extends StatefulWidget {
  final ProjectModel project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final ProjectsApi _projectsApi = const ProjectsApi();

  late ProjectModel project = widget.project;
  bool isLoadingProject = false;
  bool isLoadingMembers = false;
  String? errorMessage;
  String? membersErrorMessage;
  List<ProjectMemberModel> members = [];

  @override
  void initState() {
    super.initState();
    loadProjectDetails();
  }

  Future<void> loadProjectDetails() async {
    setState(() {
      isLoadingProject = true;
      isLoadingMembers = project.isTeamProject;
      errorMessage = null;
      membersErrorMessage = null;
    });

    try {
      final loadedProject = await _projectsApi.getProject(project);
      final loadedMembers = loadedProject.isTeamProject
          ? await _projectsApi.getProjectMembers(loadedProject)
          : <ProjectMemberModel>[];

      if (!mounted) return;

      setState(() {
        project = loadedProject;
        members = loadedMembers;
        isLoadingProject = false;
        isLoadingMembers = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isLoadingProject = false;
        isLoadingMembers = false;
        errorMessage = 'Could not refresh project details.';
        membersErrorMessage = project.isTeamProject
            ? 'Could not load project members.'
            : null;
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
    if (project.isCompleted) return 1;
    if (project.status == 'in_progress') return 0.55;
    if (project.status == 'on_hold') return 0.35;
    if (project.status == 'cancelled') return 0;
    return 0.12;
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
        ],
      ),
    );
  }

  Widget buildMembersCard(BuildContext context) {
    if (!project.isTeamProject) {
      return buildSectionCard(
        context,
        title: 'Members',
        icon: Icons.person_rounded,
        child: Text(
          'This is a personal project.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: mutedColor(context),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    Widget child;

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
      child = buildInlineMessage(
        context,
        icon: Icons.group_off_rounded,
        message: 'No project members returned by the API.',
      );
    } else {
      child = Column(
        children: [
          for (final member in members) ...[
            buildMemberRow(context, member),
            if (member != members.last) const SizedBox(height: 10),
          ],
        ],
      );
    }

    return buildSectionCard(
      context,
      title: 'Project Members',
      icon: Icons.groups_2_rounded,
      child: child,
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
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
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
            child: Text(
              member.userId.toString().substring(0, 1),
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
                  'User #${member.userId}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  member.roleLabel,
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
                    buildDescriptionCard(context),
                    const SizedBox(height: 16),
                    buildScheduleCard(context),
                    const SizedBox(height: 16),
                    buildMembersCard(context),
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
