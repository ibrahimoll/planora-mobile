import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/planora_theme.dart';
import '../../core/ui/planora_ui.dart';
import '../auth/data/project_api.dart';
import '../auth/models/project_models.dart';
import 'ai_project_wizard_screen.dart';
import 'project_detail_screen.dart';

enum ProjectCreateStartMode { modeChoice, manual, ai }

class ProjectsScreen extends StatefulWidget {
  final VoidCallback onBack;
  final int createRequestId;
  final bool openCreateOnStart;
  final ProjectCreateStartMode createStartMode;
  final VoidCallback? onCreateRequestConsumed;

  const ProjectsScreen({
    super.key,
    required this.onBack,
    this.createRequestId = 0,
    this.openCreateOnStart = false,
    this.createStartMode = ProjectCreateStartMode.modeChoice,
    this.onCreateRequestConsumed,
  });

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final ProjectsApi _projectsApi = const ProjectsApi();
  final TextEditingController searchController = TextEditingController();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  int selectedFilterIndex = 0;
  int handledCreateRequestId = 0;
  DateTime? selectedDeadline;

  bool isLoading = true;
  bool isSearchVisible = false;
  bool isCreatingProject = false;
  String? errorMessage;
  List<ProjectModel> projects = [];

  @override
  void initState() {
    super.initState();
    loadProjects();
    scheduleCreateProjectSheet();
  }

  @override
  void didUpdateWidget(covariant ProjectsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    scheduleCreateProjectSheet();
  }

  @override
  void dispose() {
    searchController.dispose();
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void scheduleCreateProjectSheet() {
    if (!widget.openCreateOnStart || widget.createRequestId == 0) return;
    if (handledCreateRequestId == widget.createRequestId) return;

    handledCreateRequestId = widget.createRequestId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onCreateRequestConsumed?.call();

      switch (widget.createStartMode) {
        case ProjectCreateStartMode.manual:
          showManualCreateProjectSheet();
        case ProjectCreateStartMode.ai:
          openAiProjectWizard();
        case ProjectCreateStartMode.modeChoice:
          showCreateProjectSheet();
      }
    });
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
    } catch (error, stackTrace) {
      debugPrint('Project list load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        errorMessage = error is ApiException
            ? 'Could not load plans: ${error.message}'
            : 'Could not load plans. Please try again.';
        isLoading = false;
      });
    }
  }

  bool get hasActiveSearch => searchController.text.trim().isNotEmpty;

  List<ProjectModel> get filteredProjects {
    final query = searchController.text.trim().toLowerCase();

    return projects.where((project) {
      final matchesFilter = switch (selectedFilterIndex) {
        1 => project.isActive,
        2 => project.isCompleted,
        _ => true,
      };

      if (!matchesFilter) return false;
      if (query.isEmpty) return true;

      final searchable = [
        project.title,
        project.description ?? '',
        project.statusLabel,
        project.projectTypeLabel,
        project.deadlineLabel,
      ].join(' ').toLowerCase();

      return searchable.contains(query);
    }).toList();
  }

  double getProjectProgress(ProjectModel project) {
    if (project.isCompleted) return 1;
    if (project.status == 'in_progress') return 0.55;
    if (project.status == 'on_hold') return 0.35;
    if (project.status == 'cancelled') return 0;
    return 0.12;
  }

  Color getStatusColor(ProjectModel project) {
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

  Color getProjectIconColor(ProjectModel project) {
    switch (project.status) {
      case 'completed':
        return PlanoraTheme.primaryPurple;
      case 'in_progress':
        return PlanoraTheme.secondaryPurple;
      case 'on_hold':
        return PlanoraTheme.warning;
      case 'cancelled':
        return PlanoraTheme.error;
      case 'not_started':
        return PlanoraTheme.info;
      default:
        return PlanoraTheme.secondaryPurple;
    }
  }

  void setProjectFilter(int index) {
    setState(() => selectedFilterIndex = index);
  }

  void toggleSearch() {
    setState(() {
      isSearchVisible = !isSearchVisible;
      if (!isSearchVisible) searchController.clear();
    });
  }

  void clearSearch() {
    setState(() {
      searchController.clear();
      isSearchVisible = false;
      selectedFilterIndex = 0;
    });
  }

  Future<void> openAiProjectWizard() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AiProjectWizardScreen(onPlanCreated: loadProjects),
      ),
    );

    if (!mounted) return;
    loadProjects();
  }

  Future<void> showProjectFilterSheet() async {
    final tabs = ['All plans', 'Active plans', 'Completed plans'];

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: PlanoraSpacing.sheetPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Filter plans',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                for (var index = 0; index < tabs.length; index++) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      selectedFilterIndex == index
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selectedFilterIndex == index
                          ? Theme.of(context).colorScheme.primary
                          : mutedColor(context),
                    ),
                    title: Text(
                      tabs[index],
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      setProjectFilter(index);
                    },
                  ),
                  if (index != tabs.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> showCreateProjectSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: PlanoraSpacing.sheetPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Start a Plan',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                buildCreateModeTile(
                  sheetContext,
                  icon: Icons.edit_note_rounded,
                  title: 'Create Manually',
                  subtitle: 'Create a simple project shell yourself.',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    showManualCreateProjectSheet();
                  },
                ),
                const SizedBox(height: 10),
                buildCreateModeTile(
                  sheetContext,
                  icon: Icons.auto_awesome_rounded,
                  title: 'Generate with AI',
                  subtitle: 'Describe an idea and Planora creates the plan.',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    openAiProjectWizard();
                  },
                  primary: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildCreateModeTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    final color = Theme.of(context).colorScheme.primary;

    return PlanoraCard(
      onTap: onTap,
      radius: 18,
      padding: const EdgeInsets.all(16),
      color: primary ? color.withValues(alpha: 0.10) : null,
      border: Border.all(
        color: primary ? color.withValues(alpha: 0.35) : borderColor(context),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: mutedColor(context))),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: color),
        ],
      ),
    );
  }

  Future<void> showManualCreateProjectSheet() async {
    titleController.clear();
    descriptionController.clear();
    selectedDeadline = null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SingleChildScrollView(
                padding: PlanoraSpacing.sheetPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create Plan',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        prefixIcon: Icon(Icons.folder_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Description optional',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    PlanoraSecondaryButton(
                      icon: Icons.calendar_month_rounded,
                      label: selectedDeadline == null
                          ? 'Choose deadline'
                          : formatInputDate(selectedDeadline!),
                      onPressed: () async {
                        final picked = await pickDeadlineDate();
                        if (picked == null) return;
                        setSheetState(() => selectedDeadline = picked);
                      },
                    ),
                    const SizedBox(height: 18),
                    PlanoraGradientButton(
                      label: 'Create Plan',
                      icon: Icons.add_rounded,
                      isLoading: isCreatingProject,
                      onTap: () => createProjectFromSheet(sheetContext),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String formatInputDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  Future<DateTime?> pickDeadlineDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDeadline ?? now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );

    if (pickedDate == null) return null;
    return DateTime(pickedDate.year, pickedDate.month, pickedDate.day, 12);
  }

  Future<void> createProjectFromSheet(BuildContext sheetContext) async {
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();

    if (title.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Project title must be at least 2 letters.'),
        ),
      );
      return;
    }

    if (selectedDeadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project deadline is required.')),
      );
      return;
    }

    setState(() => isCreatingProject = true);

    try {
      await _projectsApi.createProject(
        ProjectCreateRequest(
          title: title,
          description: description.isEmpty ? null : description,
          deadline: selectedDeadline!,
        ),
      );

      if (!mounted) return;
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();

      setState(() => isCreatingProject = false);
      await loadProjects();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Plan created.')));
    } catch (error, stackTrace) {
      debugPrint('Project creation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => isCreatingProject = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException ? error.message : 'Could not create plan.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlanoraPage(
      title: 'Plans',
      subtitle: 'Organize ideas, tasks, deadlines, and risks',
      onBack: widget.onBack,
      onRefresh: loadProjects,
      actions: [
        PlanoraIconButton(
          icon: isSearchVisible ? Icons.close_rounded : Icons.search_rounded,
          tooltip: isSearchVisible ? 'Close search' : 'Search plans',
          onTap: toggleSearch,
        ),
        const SizedBox(width: 10),
        PlanoraIconButton(
          icon: Icons.tune_rounded,
          tooltip: 'Filter plans',
          onTap: showProjectFilterSheet,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isSearchVisible) ...[
            PlanoraAnimatedIn(
              index: 0,
              child: buildProjectSearchField(context),
            ),
            const SizedBox(height: 14),
          ],
          PlanoraAnimatedIn(
            index: 1,
            child: buildProjectTabsAndAction(context),
          ),
          const SizedBox(height: 20),
          PlanoraAnimatedIn(index: 2, child: buildProjectContent(context)),
        ],
      ),
    );
  }

  Widget buildProjectSearchField(BuildContext context) {
    return TextField(
      controller: searchController,
      autofocus: true,
      onChanged: (_) => setState(() {}),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search plans, status, deadlines, or descriptions...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: hasActiveSearch
            ? IconButton(
                onPressed: () => setState(searchController.clear),
                icon: const Icon(Icons.close_rounded),
              )
            : null,
      ),
    );
  }

  Widget buildProjectTabsAndAction(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PlanoraSegmentedTabs(
            tabs: const ['All', 'Active', 'Done'],
            selectedIndex: selectedFilterIndex,
            onChanged: setProjectFilter,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 126,
          child: PlanoraGradientButton(
            height: 48,
            radius: 16,
            icon: Icons.add_rounded,
            label: 'New',
            onTap: showCreateProjectSheet,
          ),
        ),
      ],
    );
  }

  Widget buildProjectContent(BuildContext context) {
    if (isLoading) {
      return const PlanoraLoadingState(message: 'Loading plans...');
    }

    if (errorMessage != null) {
      return PlanoraMessageState(
        icon: Icons.wifi_off_rounded,
        title: 'Could not load plans',
        message: errorMessage!,
        actionText: 'Try Again',
        onAction: loadProjects,
      );
    }

    final visibleProjects = filteredProjects;

    if (visibleProjects.isEmpty) {
      if (projects.isNotEmpty &&
          (hasActiveSearch || selectedFilterIndex != 0)) {
        return PlanoraMessageState(
          icon: Icons.search_off_rounded,
          title: 'No matching plans',
          message: 'Try another search term or clear the current filter.',
          actionText: 'Clear Search',
          onAction: clearSearch,
        );
      }

      return PlanoraMessageState(
        icon: Icons.folder_open_rounded,
        title: 'No plans yet',
        message:
            'Create a manual plan or generate one with AI to start organizing it.',
        actionText: 'Start Plan',
        onAction: showCreateProjectSheet,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Current Plans',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < visibleProjects.length; index++) ...[
          PlanoraAnimatedIn(
            index: index,
            child: buildProjectCard(context, visibleProjects[index]),
          ),
          if (index != visibleProjects.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget buildProjectCard(BuildContext context, ProjectModel project) {
    final statusColor = getStatusColor(project);
    final iconColor = getProjectIconColor(project);
    final progress = getProjectProgress(project);

    return PlanoraCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProjectDetailScreen(
              project: project,
              onProjectChanged: loadProjects,
            ),
          ),
        );

        if (!mounted) return;
        loadProjects();
      },
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  project.isTeamProject
                      ? Icons.groups_2_rounded
                      : Icons.folder_rounded,
                  color: iconColor,
                  size: 27,
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
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      (project.description?.trim().isNotEmpty ?? false)
                          ? project.description!.trim()
                          : project.projectTypeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: mutedColor(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              buildChip(context, project.statusLabel, statusColor),
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
                    minHeight: 6,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .10),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      project.isCompleted
                          ? PlanoraTheme.primaryPurple
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(progress * 100).round()}%',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: mutedColor(context),
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
                color: mutedColor(context),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  project.deadlineLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: mutedColor(context),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              buildTypeChip(context, project),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildTypeChip(BuildContext context, ProjectModel project) {
    return buildChip(
      context,
      project.isTeamProject ? 'Team' : 'Personal',
      project.isTeamProject
          ? PlanoraTheme.secondaryPurple
          : PlanoraTheme.textMuted,
      icon: project.isTeamProject
          ? Icons.groups_2_rounded
          : Icons.person_rounded,
    );
  }

  Widget buildChip(
    BuildContext context,
    String label,
    Color color, {
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Color borderColor(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    return isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border;
  }

  Color mutedColor(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    return isDark ? PlanoraTheme.darkTextSecondary : PlanoraTheme.textSecondary;
  }
}
