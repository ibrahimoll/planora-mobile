import 'package:flutter/material.dart';

import '../auth/data/project_api.dart';
import '../auth/models/project_models.dart';

class ProjectsScreen extends StatefulWidget {
  final VoidCallback onBack;

  const ProjectsScreen({super.key, required this.onBack});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final ProjectsApi _projectsApi = const ProjectsApi();

  int selectedFilterIndex = 0;
  bool isLoading = true;
  String? errorMessage;
  List<ProjectModel> projects = [];

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  DateTime? selectedDeadline;
  bool isCreatingProject = false;

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    loadProjects();
  }

  Future<void> loadProjects() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final loadedProjects = await _projectsApi.getProjects();

      if (!mounted) return;

      setState(() {
        projects = loadedProjects;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Could not load projects. Please try again.';
        isLoading = false;
      });
    }
  }

  List<ProjectModel> get filteredProjects {
    if (selectedFilterIndex == 1) {
      return projects.where((project) => project.isActive).toList();
    }

    if (selectedFilterIndex == 2) {
      return projects.where((project) => project.isCompleted).toList();
    }

    return projects;
  }

  int get totalProjectsCount {
    return projects.length;
  }

  int get activeProjectsCount {
    return projects.where((project) => project.isActive).length;
  }

  int get completedProjectsCount {
    return projects.where((project) => project.isCompleted).length;
  }

  Color getStatusColor(BuildContext context, ProjectModel project) {
    switch (project.status) {
      case 'completed':
        return const Color(0xFF7C3AED);
      case 'in_progress':
        return const Color(0xFF22C55E);
      case 'on_hold':
        return const Color(0xFFF59E0B);
      case 'cancelled':
        return const Color(0xFFEF4444);
      case 'not_started':
        return const Color(0xFF3B82F6);
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  Color getProjectIconColor(ProjectModel project) {
    switch (project.status) {
      case 'completed':
        return const Color(0xFF7C3AED);
      case 'in_progress':
        return const Color(0xFF8B5CF6);
      case 'on_hold':
        return const Color(0xFFF59E0B);
      case 'cancelled':
        return const Color(0xFFEF4444);
      case 'not_started':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  double getProjectProgress(ProjectModel project) {
    if (project.isCompleted) {
      return 1;
    }

    if (project.status == 'in_progress') {
      return 0.55;
    }

    if (project.status == 'on_hold') {
      return 0.35;
    }

    if (project.status == 'cancelled') {
      return 0;
    }

    return 0.12;
  }

  String getProjectProgressLabel(ProjectModel project) {
    final progress = getProjectProgress(project);
    return '${(progress * 100).round()}%';
  }

  Widget buildProjectsHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        InkWell(
          onTap: widget.onBack,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              Icons.arrow_back_rounded,
              size: 28,
              color: isDark ? Colors.white : const Color(0xFF1E1B4B),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Projects',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF1E1B4B),
          ),
        ),
        const Spacer(),
        buildCircleIconButton(
          context,
          icon: Icons.search_rounded,
          onTap: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Search is next.')));
          },
        ),
        const SizedBox(width: 10),
        buildCircleIconButton(
          context,
          icon: Icons.tune_rounded,
          onTap: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Filters are next.')));
          },
        ),
      ],
    );
  }

  Widget buildCircleIconButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF111827) : Colors.white,
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDark ? Colors.white70 : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget buildProjectTabsAndAction(BuildContext context) {
    return Row(
      children: [
        Expanded(child: buildProjectTabs(context)),
        const SizedBox(width: 12),
        buildNewProjectButton(context),
      ],
    );
  }

  Widget buildProjectTabs(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabs = ['All', 'Active', 'Completed'];

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = selectedFilterIndex == index;

          return Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  selectedFilterIndex = index;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withValues(
                          alpha: isDark ? 0.22 : 0.12,
                        )
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tabs[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : isDark
                        ? Colors.white70
                        : const Color(0xFF4B5563),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget buildNewProjectButton(BuildContext context) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Create project screen is next.')),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 48,
        width: 142,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6D28D9).withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 6),
            Text(
              'New Project',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildProjectStats(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: buildProjectStatCard(
            context,
            icon: Icons.folder_rounded,
            value: totalProjectsCount.toString(),
            label: 'Total Projects',
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: buildProjectStatCard(
            context,
            icon: Icons.bar_chart_rounded,
            value: activeProjectsCount.toString(),
            label: 'Active',
            color: const Color(0xFF22C55E),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: buildProjectStatCard(
            context,
            icon: Icons.check_circle_rounded,
            value: completedProjectsCount.toString(),
            label: 'Completed',
            color: const Color(0xFF7C3AED),
          ),
        ),
      ],
    );
  }

  Widget buildProjectStatCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildProjectContent(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return buildMessageState(
        context,
        icon: Icons.wifi_off_rounded,
        title: 'Could not load projects',
        message: errorMessage!,
        buttonText: 'Try Again',
        onPressed: loadProjects,
      );
    }

    final visibleProjects = filteredProjects;

    if (visibleProjects.isEmpty) {
      return buildMessageState(
        context,
        icon: Icons.folder_open_rounded,
        title: 'No projects yet',
        message:
            'Create your first project and Planora will help you organize it.',
        buttonText: 'New Project',
        onPressed: () {
          showCreateProjectSheet();
        },
      );
    }

    return Column(
      children: [
        for (final project in visibleProjects) ...[
          buildProjectCard(context, project),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget buildMessageState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E1B4B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.white70 : const Color(0xFF4B5563),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(onPressed: onPressed, child: Text(buttonText)),
        ],
      ),
    );
  }

  Widget buildProjectCard(BuildContext context, ProjectModel project) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = getStatusColor(context, project);
    final iconColor = getProjectIconColor(project);
    final progress = getProjectProgress(project);

    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${project.title} details screen is next.')),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    project.isTeamProject
                        ? Icons.groups_2_rounded
                        : Icons.folder_rounded,
                    color: iconColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E1B4B),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        project.projectTypeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: isDark
                                  ? Colors.white60
                                  : const Color(0xFF64748B),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                buildStatusBadge(context, project, statusColor),
                const SizedBox(width: 8),
                Icon(
                  Icons.more_vert_rounded,
                  color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE5E7EB),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        project.isCompleted
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFF8B5CF6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  getProjectProgressLabel(project),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    project.deadlineLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                buildProjectTypeChip(context, project),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildStatusBadge(
    BuildContext context,
    ProjectModel project,
    Color statusColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        project.statusLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: statusColor,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget buildProjectTypeChip(BuildContext context, ProjectModel project) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: project.isTeamProject
            ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
            : const Color(0xFF64748B).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            project.isTeamProject
                ? Icons.groups_2_rounded
                : Icons.person_rounded,
            size: 12,
            color: project.isTeamProject
                ? const Color(0xFF8B5CF6)
                : isDark
                ? Colors.white60
                : const Color(0xFF64748B),
          ),
          const SizedBox(width: 4),
          Text(
            project.isTeamProject ? 'Team' : 'Personal',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 10,
              color: project.isTeamProject
                  ? const Color(0xFF8B5CF6)
                  : isDark
                  ? Colors.white60
                  : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: loadProjects,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            buildProjectsHeader(context),
            const SizedBox(height: 22),
            buildProjectTabsAndAction(context),
            const SizedBox(height: 18),
            buildProjectStats(context),
            const SizedBox(height: 20),
            buildProjectContent(context),
          ],
        ),
      ),
    );
  }
}
