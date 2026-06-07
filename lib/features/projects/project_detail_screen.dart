import 'package:flutter/material.dart';

import '../../core/theme/planora_theme.dart';
import '../ai/data/ai_plan_api.dart';
import '../auth/data/project_api.dart';
import '../auth/models/project_models.dart';
import '../tasks/data/tasks_api.dart';
import '../tasks/models/task_models.dart';

class ProjectDetailScreen extends StatefulWidget {
  final ProjectModel project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final ProjectsApi _projectsApi = const ProjectsApi();
  final TasksApi _tasksApi = const TasksApi();
  final AiPlanApi _aiPlanApi = const AiPlanApi();

  late ProjectModel project = widget.project;
  bool isLoadingProject = false;
  bool isLoadingMembers = false;
  bool isLoadingTasks = false;
  bool isGeneratingAiPlan = false;
  String? errorMessage;
  String? membersErrorMessage;
  String? tasksErrorMessage;
  List<ProjectMemberModel> members = [];
  List<TaskListItem> projectTasks = [];

  @override
  void initState() {
    super.initState();
    loadProjectDetails();
  }

  Future<void> loadProjectDetails() async {
    setState(() {
      isLoadingProject = true;
      isLoadingMembers = project.isTeamProject;
      isLoadingTasks = true;
      errorMessage = null;
      membersErrorMessage = null;
      tasksErrorMessage = null;
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
      ]);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isLoadingProject = false;
        isLoadingMembers = false;
        isLoadingTasks = false;
        errorMessage = 'Could not refresh project details.';
        membersErrorMessage = project.isTeamProject
            ? 'Could not load project members.'
            : null;
        tasksErrorMessage = 'Could not load project tasks.';
      });
    }
  }

  Future<void> loadProjectMembers([ProjectModel? source]) async {
    final targetProject = source ?? project;

    if (!targetProject.isTeamProject) {
      if (!mounted) return;

      setState(() {
        members = [];
        isLoadingMembers = false;
        membersErrorMessage = null;
      });
      return;
    }

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
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isLoadingMembers = false;
        membersErrorMessage = 'Could not load project members.';
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
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isLoadingTasks = false;
        tasksErrorMessage = 'Could not load project tasks.';
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
                  'AI Project Plan',
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
                ? 'Generate a structured plan and create tasks for this project.'
                : 'Generate more tasks or replace the current task list.',
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
                    ? 'Generating Tasks...'
                    : 'Generate AI Tasks',
              ),
            ),
          ),
        ],
      ),
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
                              'Generate AI Tasks',
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
    } catch (_) {
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
                    buildAiPlanCard(context),
                    const SizedBox(height: 16),
                    buildTasksCard(context),
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
