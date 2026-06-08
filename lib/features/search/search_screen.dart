import 'package:flutter/material.dart';

import '../../core/theme/planora_theme.dart';
import '../auth/data/project_api.dart';
import '../auth/models/project_models.dart';
import '../projects/project_detail_screen.dart';
import '../tasks/data/tasks_api.dart';
import '../tasks/models/task_models.dart';
import '../tasks/task_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ProjectsApi _projectsApi = const ProjectsApi();
  final TasksApi _tasksApi = const TasksApi();
  final TextEditingController _searchController = TextEditingController();

  bool isLoading = true;
  String? errorMessage;
  List<ProjectModel> projects = [];
  List<TaskListItem> tasks = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    loadSearchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadSearchData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final loadedProjects = await _projectsApi.getProjects();
      final loadedTasks = await _tasksApi.getTasks();

      if (!mounted) {
        return;
      }

      setState(() {
        projects = loadedProjects;
        tasks = loadedTasks.tasks;
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Search data load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        errorMessage = 'Could not load search results.';
      });
    }
  }

  String get query {
    return _searchController.text.trim().toLowerCase();
  }

  List<ProjectModel> get filteredProjects {
    final value = query;

    if (value.isEmpty) {
      return projects.take(6).toList();
    }

    return projects.where((project) {
      final haystack = [
        project.title,
        project.description ?? '',
        project.statusLabel,
        project.projectTypeLabel,
      ].join(' ').toLowerCase();

      return haystack.contains(value);
    }).toList();
  }

  List<TaskListItem> get filteredTasks {
    final value = query;

    if (value.isEmpty) {
      return tasks.take(8).toList();
    }

    return tasks.where((item) {
      final haystack = [
        item.task.title,
        item.task.description ?? '',
        item.task.status.label,
        item.task.priority.label,
        item.project.title,
      ].join(' ').toLowerCase();

      return haystack.contains(value);
    }).toList();
  }

  Color mutedColor(BuildContext context) {
    return PlanoraTheme.isDark(context)
        ? PlanoraTheme.darkTextSecondary
        : PlanoraTheme.textSecondary;
  }

  void openProject(ProjectModel project) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProjectDetailScreen(project: project)),
    );
  }

  void openTask(TaskListItem task) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TaskDetailScreen(initialTask: task)),
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
                    _buildSearchField(context),
                    const SizedBox(height: 16),
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
            'Search',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return TextField(
      controller: _searchController,
      autofocus: true,
      decoration: InputDecoration(
        hintText: 'Search projects and tasks',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                onPressed: _searchController.clear,
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: isDark ? PlanoraTheme.darkSurface : Colors.white,
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return _buildState(
        context,
        icon: Icons.wifi_off_rounded,
        title: errorMessage!,
        action: 'Try Again',
        onAction: loadSearchData,
      );
    }

    final projectResults = filteredProjects;
    final taskResults = filteredTasks;

    if (projectResults.isEmpty && taskResults.isEmpty) {
      return _buildState(
        context,
        icon: Icons.search_off_rounded,
        title: 'No projects or tasks found.',
      );
    }

    return RefreshIndicator(
      onRefresh: loadSearchData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          _buildSectionTitle(context, 'Projects', projectResults.length),
          const SizedBox(height: 10),
          if (projectResults.isEmpty)
            _buildEmptySection(context, 'No matching projects.')
          else
            for (final project in projectResults)
              _buildProjectResult(context, project),
          const SizedBox(height: 18),
          _buildSectionTitle(context, 'Tasks', taskResults.length),
          const SizedBox(height: 10),
          if (taskResults.isEmpty)
            _buildEmptySection(context, 'No matching tasks.')
          else
            for (final task in taskResults) _buildTaskResult(context, task),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, int count) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        Text(
          '$count',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildProjectResult(BuildContext context, ProjectModel project) {
    return _buildResultTile(
      context,
      icon: project.isTeamProject
          ? Icons.groups_2_outlined
          : Icons.folder_outlined,
      title: project.title,
      subtitle: '${project.projectTypeLabel} • ${project.statusLabel}',
      badge: project.deadlineLabel,
      onTap: () => openProject(project),
    );
  }

  Widget _buildTaskResult(BuildContext context, TaskListItem item) {
    return _buildResultTile(
      context,
      icon: Icons.check_box_outlined,
      title: item.task.title,
      subtitle: item.project.title,
      badge: item.task.dueDateLabel,
      onTap: () => openTask(item),
    );
  }

  Widget _buildResultTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    required VoidCallback onTap,
  }) {
    final isDark = PlanoraTheme.isDark(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isDark ? PlanoraTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
              ),
              boxShadow: PlanoraTheme.cardShadowFor(context),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
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
                Text(
                  badge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySection(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PlanoraTheme.isDark(context)
            ? PlanoraTheme.darkSurface
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: PlanoraTheme.isDark(context)
              ? PlanoraTheme.darkBorder
              : PlanoraTheme.border,
        ),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: mutedColor(context),
          fontWeight: FontWeight.w800,
        ),
      ),
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
}
