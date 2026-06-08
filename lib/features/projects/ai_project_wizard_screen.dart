import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/planora_theme.dart';
import '../ai/data/ai_plan_api.dart';
import '../auth/data/project_api.dart';
import '../auth/models/project_models.dart';
import 'project_detail_screen.dart';

class AiProjectWizardScreen extends StatefulWidget {
  final VoidCallback? onPlanCreated;

  const AiProjectWizardScreen({super.key, this.onPlanCreated});

  @override
  State<AiProjectWizardScreen> createState() => _AiProjectWizardScreenState();
}

class _AiProjectWizardScreenState extends State<AiProjectWizardScreen> {
  final ProjectsApi _projectsApi = const ProjectsApi();
  final AiPlanApi _aiPlanApi = const AiPlanApi();
  final TextEditingController ideaController = TextEditingController();
  final TextEditingController requirementsController = TextEditingController();

  int currentStep = 0;
  int availableHoursPerWeek = 8;
  int preferredTaskCount = 8;
  int? selectedTeamId;
  String selectedProjectType = 'personal';

  bool isLoadingTeams = false;
  bool isGeneratingPlan = false;
  DateTime? selectedDeadline;
  ProjectModel? createdProject;
  AiPlanGenerateResponse? generatedPlan;
  String? generationError;

  List<TeamModel> teams = [];

  @override
  void initState() {
    super.initState();
    loadTeams();
  }

  @override
  void dispose() {
    ideaController.dispose();
    requirementsController.dispose();
    super.dispose();
  }

  Future<void> loadTeams() async {
    setState(() {
      isLoadingTeams = true;
    });

    try {
      final loadedTeams = await _projectsApi.getTeams();

      if (!mounted) {
        return;
      }

      setState(() {
        teams = loadedTeams;
        selectedTeamId = loadedTeams.isEmpty ? null : loadedTeams.first.teamId;
        isLoadingTeams = false;
      });
    } catch (error, stackTrace) {
      debugPrint('AI project team load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        teams = [];
        selectedTeamId = null;
        isLoadingTeams = false;
      });
    }
  }

  Color mutedColor(BuildContext context) {
    return PlanoraTheme.isDark(context)
        ? PlanoraTheme.darkTextMuted
        : PlanoraTheme.textSecondary;
  }

  BoxDecoration cardDecoration(BuildContext context, {double radius = 22}) {
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

  bool get canReviewContext {
    return ideaController.text.trim().length >= 12 && selectedDeadline != null;
  }

  String get selectedTeamName {
    final teamId = selectedTeamId;

    if (teamId == null) {
      return 'No team selected';
    }

    for (final team in teams) {
      if (team.teamId == teamId) {
        return team.name;
      }
    }

    return 'Selected team';
  }

  Future<DateTime?> pickDeadlineDate() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDeadline ?? now.add(const Duration(days: 14)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );

    if (pickedDate == null) {
      return null;
    }

    return normalizeProjectDeadline(pickedDate);
  }

  DateTime normalizeProjectDeadline(DateTime pickedDate) {
    final now = DateTime.now();
    final noon = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      12,
    );

    if (noon.isAfter(now)) {
      return noon;
    }

    return DateTime(now.year, now.month, now.day + 1, 12);
  }

  String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  void showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> generatePlanFromContext() async {
    final idea = ideaController.text.trim();
    final deadline = selectedDeadline;

    if (idea.length < 12) {
      showMessage('Describe your project idea first.');
      return;
    }

    if (deadline == null) {
      showMessage('Choose a deadline before generating a plan.');
      return;
    }

    if (selectedProjectType == 'team' && selectedTeamId == null) {
      showMessage('Select or create a team before generating a team plan.');
      return;
    }

    setState(() {
      currentStep = 2;
      isGeneratingPlan = true;
      generationError = null;
      createdProject = null;
      generatedPlan = null;
    });

    try {
      // TODO: Replace this staged create-then-generate flow when the backend
      // adds POST /ai-plans/preview-from-idea and POST /ai-plans/accept-preview.
      final request = ProjectCreateRequest(
        title: deriveProjectTitle(idea),
        description: buildProjectDescription(),
        deadline: deadline,
      );

      final project = selectedProjectType == 'team'
          ? await _projectsApi.createTeamProject(
              teamId: selectedTeamId!,
              request: request,
            )
          : await _projectsApi.createProject(request);

      final plan = await _aiPlanApi.generatePlan(
        project: project,
        prompt: buildAiPlanningPrompt(project.title),
        generateTasks: true,
        overwriteExistingTasks: false,
        preferredTaskCount: preferredTaskCount,
        includeMilestones: true,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        createdProject = project;
        generatedPlan = plan;
        isGeneratingPlan = false;
      });

      widget.onPlanCreated?.call();
    } catch (error, stackTrace) {
      debugPrint('AI project generation failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        isGeneratingPlan = false;
        generationError = error is ApiException
            ? error.message
            : 'Could not generate this AI plan. Please try again.';
      });
    }
  }

  String deriveProjectTitle(String idea) {
    var title = idea
        .split(RegExp(r'[\n.!?]'))
        .first
        .replaceFirst(RegExp(r'^\s*i\s+want\s+to\s+', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^\s*build\s+', caseSensitive: false), '')
        .trim();

    if (title.length > 86) {
      title = '${title.substring(0, 83).trim()}...';
    }

    if (title.length < 2) {
      return 'AI Generated Plan';
    }

    return title[0].toUpperCase() + title.substring(1);
  }

  String buildProjectDescription() {
    final requirements = requirementsController.text.trim();
    final pieces = [
      'AI planning brief',
      '',
      'Idea: ${ideaController.text.trim()}',
      'Available hours per week: $availableHoursPerWeek',
      'Preferred task count: $preferredTaskCount',
      if (requirements.isNotEmpty)
        'Requirements and constraints: $requirements',
    ];

    final description = pieces.join('\n');

    if (description.length <= 5000) {
      return description;
    }

    return '${description.substring(0, 4997).trimRight()}...';
  }

  String buildAiPlanningPrompt(String title) {
    final deadline = selectedDeadline;
    final requirements = requirementsController.text.trim();
    final typeLabel = selectedProjectType == 'team'
        ? 'team project for $selectedTeamName'
        : 'personal project';

    return [
      'Create a complete Planora project plan and task list.',
      'Project title: $title',
      'Project type: $typeLabel',
      if (deadline != null) 'Deadline: ${deadline.toIso8601String()}',
      'Available hours per week: $availableHoursPerWeek',
      'Preferred task count: $preferredTaskCount',
      '',
      'Project idea and goal:',
      ideaController.text.trim(),
      if (requirements.isNotEmpty) ...[
        '',
        'Requirements, features, constraints, and notes:',
        requirements,
      ],
      '',
      'Return a practical plan with milestones, priorities, estimated hours, due dates, risks, and next-step recommendations when available.',
    ].join('\n');
  }

  Future<void> openCreatedProject() async {
    final project = createdProject;

    if (project == null) {
      return;
    }

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => ProjectDetailScreen(project: project),
      ),
    );
  }

  Widget buildHeader(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Row(
      children: [
        InkWell(
          onTap: isGeneratingPlan ? null : () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 44,
            height: 44,
            decoration: cardDecoration(context, radius: 16),
            child: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? Colors.white : PlanoraTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Planner',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: isDark
                      ? PlanoraTheme.darkTextPrimary
                      : PlanoraTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Turn an idea into a structured project plan.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

  Widget buildStepHeader(BuildContext context) {
    final labels = ['Idea', 'Review', 'Plan'];

    return Row(
      children: [
        for (var index = 0; index < labels.length; index++) ...[
          Expanded(
            child: buildStepPill(
              context,
              label: labels[index],
              index: index,
              isActive: currentStep == index,
              isDone: currentStep > index,
            ),
          ),
          if (index != labels.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget buildStepPill(
    BuildContext context, {
    required String label,
    required int index,
    required bool isActive,
    required bool isDone,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = PlanoraTheme.isDark(context);
    final color = isActive || isDone ? primary : mutedColor(context);

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: (isActive || isDone)
            ? primary.withValues(alpha: isDark ? 0.22 : 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isActive || isDone)
              ? primary.withValues(alpha: 0.36)
              : isDark
              ? PlanoraTheme.darkBorder
              : PlanoraTheme.border,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

  Widget buildIdeaStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildAiInputCard(
          context,
          title: 'Explain your idea',
          child: TextField(
            controller: ideaController,
            minLines: 6,
            maxLines: 8,
            maxLength: 1200,
            onChanged: (_) => setState(() {}),
            decoration: createInputDecoration(
              context,
              hintText:
                  'Describe what you want to build, the goal, and what success looks like...',
              icon: Icons.auto_awesome_rounded,
            ),
          ),
        ),
        const SizedBox(height: 14),
        buildExampleCard(context),
        const SizedBox(height: 14),
        buildAiInputCard(
          context,
          title: 'Deadline',
          child: buildSelectButton(
            context,
            icon: Icons.calendar_month_rounded,
            label: selectedDeadline == null
                ? 'Choose a deadline'
                : formatDate(selectedDeadline!),
            isPlaceholder: selectedDeadline == null,
            onTap: () async {
              final pickedDate = await pickDeadlineDate();

              if (pickedDate == null) {
                return;
              }

              setState(() {
                selectedDeadline = pickedDate;
              });
            },
          ),
        ),
        const SizedBox(height: 14),
        buildAiInputCard(
          context,
          title: 'Plan type',
          child: Column(
            children: [
              buildProjectTypeSelector(context),
              if (selectedProjectType == 'team') ...[
                const SizedBox(height: 12),
                buildTeamSelector(context),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        buildAiInputCard(
          context,
          title: 'Planning capacity',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildSliderHeader(
                context,
                icon: Icons.schedule_rounded,
                label: '$availableHoursPerWeek hours per week',
              ),
              Slider(
                value: availableHoursPerWeek.toDouble(),
                min: 1,
                max: 60,
                divisions: 59,
                label: '$availableHoursPerWeek hours',
                onChanged: (value) {
                  setState(() {
                    availableHoursPerWeek = value.round();
                  });
                },
              ),
              const SizedBox(height: 6),
              buildSliderHeader(
                context,
                icon: Icons.format_list_numbered_rounded,
                label: '$preferredTaskCount preferred tasks',
              ),
              Slider(
                value: preferredTaskCount.toDouble(),
                min: 3,
                max: 12,
                divisions: 9,
                label: '$preferredTaskCount tasks',
                onChanged: (value) {
                  setState(() {
                    preferredTaskCount = value.round();
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        buildAiInputCard(
          context,
          title: 'Requirements and constraints',
          child: TextField(
            controller: requirementsController,
            minLines: 4,
            maxLines: 6,
            maxLength: 1200,
            decoration: createInputDecoration(
              context,
              hintText:
                  'Required features, team constraints, risks, tools, notes...',
              icon: Icons.notes_rounded,
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: canReviewContext
                ? () {
                    setState(() {
                      currentStep = 1;
                    });
                  }
                : null,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Review Context'),
          ),
        ),
      ],
    );
  }

  Widget buildExampleCard(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return InkWell(
      onTap: () {
        ideaController.text =
            'I want to build a Flutter mobile app for my FYP with login, projects, tasks, teams, and AI planning.';
        setState(() {});
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.lightbulb_outline_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Example: I want to build a Flutter mobile app for my FYP with login, projects, tasks, teams, and AI planning.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? PlanoraTheme.darkTextPrimary
                      : PlanoraTheme.textPrimary,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAiInputCard(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  InputDecoration createInputDecoration(
    BuildContext context, {
    required String hintText,
    required IconData icon,
  }) {
    final isDark = PlanoraTheme.isDark(context);

    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
      alignLabelWithHint: true,
      filled: true,
      fillColor: isDark ? PlanoraTheme.darkBackground : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.4,
        ),
      ),
    );
  }

  Widget buildSelectButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isPlaceholder,
    required VoidCallback onTap,
  }) {
    final isDark = PlanoraTheme.isDark(context);
    final textColor = isPlaceholder
        ? mutedColor(context)
        : isDark
        ? PlanoraTheme.darkTextPrimary
        : PlanoraTheme.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? PlanoraTheme.darkBackground : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: mutedColor(context)),
          ],
        ),
      ),
    );
  }

  Widget buildProjectTypeSelector(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: buildTypeOption(
            context,
            label: 'Personal',
            icon: Icons.person_outline_rounded,
            value: 'personal',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: buildTypeOption(
            context,
            label: 'Team',
            icon: Icons.groups_2_outlined,
            value: 'team',
          ),
        ),
      ],
    );
  }

  Widget buildTypeOption(
    BuildContext context, {
    required String label,
    required IconData icon,
    required String value,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = PlanoraTheme.isDark(context);
    final isSelected = selectedProjectType == value;

    return InkWell(
      onTap: () {
        setState(() {
          selectedProjectType = value;
          if (value == 'team' && selectedTeamId == null && teams.isNotEmpty) {
            selectedTeamId = teams.first.teamId;
          }
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: isDark ? 0.22 : 0.12)
              : isDark
              ? PlanoraTheme.darkBackground
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? primary
                : isDark
                ? PlanoraTheme.darkBorder
                : PlanoraTheme.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 19,
              color: isSelected ? primary : mutedColor(context),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isSelected ? primary : mutedColor(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTeamSelector(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    if (isLoadingTeams) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (teams.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? PlanoraTheme.darkBackground : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.group_off_outlined, color: mutedColor(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Create or join a team before generating a team plan.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: mutedColor(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<int>(
      initialValue: selectedTeamId,
      isExpanded: true,
      decoration: createInputDecoration(
        context,
        hintText: 'Select team',
        icon: Icons.groups_2_outlined,
      ),
      items: [
        for (final team in teams)
          DropdownMenuItem<int>(
            value: team.teamId,
            child: Text(
              team.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (value) {
        setState(() {
          selectedTeamId = value;
        });
      },
    );
  }

  Widget buildSliderHeader(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 19),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget buildReviewStep(BuildContext context) {
    final deadline = selectedDeadline;
    final requirements = requirementsController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildAiInputCard(
          context,
          title: 'Review context',
          child: Column(
            children: [
              buildReviewRow(context, 'Idea', ideaController.text.trim()),
              buildReviewRow(
                context,
                'Deadline',
                deadline == null ? 'Not selected' : formatDate(deadline),
              ),
              buildReviewRow(
                context,
                'Type',
                selectedProjectType == 'team'
                    ? 'Team plan: $selectedTeamName'
                    : 'Personal plan',
              ),
              buildReviewRow(
                context,
                'Availability',
                '$availableHoursPerWeek hours per week',
              ),
              buildReviewRow(
                context,
                'Task count',
                '$preferredTaskCount preferred tasks',
              ),
              buildReviewRow(
                context,
                'Requirements',
                requirements.isEmpty ? 'No extra constraints' : requirements,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Planora will create the project now and generate tasks from this full brief.',
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
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    currentStep = 0;
                  });
                },
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Edit'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: isGeneratingPlan ? null : generatePlanFromContext,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Generate Plan'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildReviewRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: mutedColor(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildResultStep(BuildContext context) {
    final project = createdProject;
    final plan = generatedPlan;
    final error = generationError;

    if (isGeneratingPlan) {
      return buildResultState(
        context,
        icon: Icons.auto_awesome_rounded,
        title: 'Generating your plan...',
        message:
            'Planora is creating the project and turning your idea into tasks.',
        showSpinner: true,
      );
    }

    if (error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildResultState(
            context,
            icon: Icons.wifi_off_rounded,
            title: 'AI plan could not be generated',
            message: error,
          ),
          const SizedBox(height: 14),
          if (project != null)
            ElevatedButton.icon(
              onPressed: openCreatedProject,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Open Project'),
            )
          else
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  currentStep = 1;
                  generationError = null;
                });
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Review Again'),
            ),
        ],
      );
    }

    if (project == null || plan == null) {
      return buildResultState(
        context,
        icon: Icons.auto_awesome_rounded,
        title: 'Ready to generate',
        message: 'Review your context and generate a plan.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildAiInputCard(
          context,
          title: project.title,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plan.summary.isEmpty
                    ? 'Plan generated with ${plan.tasksCreated} tasks.'
                    : plan.summary,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: mutedColor(context),
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  buildResultChip(
                    context,
                    icon: Icons.checklist_rounded,
                    label: '${plan.tasksCreated} tasks',
                  ),
                  const SizedBox(width: 8),
                  buildResultChip(
                    context,
                    icon: project.isTeamProject
                        ? Icons.groups_2_rounded
                        : Icons.person_rounded,
                    label: project.projectTypeLabel,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Generated tasks',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        for (final task in plan.tasks) ...[
          buildGeneratedTaskCard(context, task),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: openCreatedProject,
          icon: const Icon(Icons.folder_open_rounded),
          label: const Text('Open Project'),
        ),
      ],
    );
  }

  Widget buildResultState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
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
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2.8),
            )
          else
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 42),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: mutedColor(context),
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildResultChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
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

  Widget buildGeneratedTaskCard(BuildContext context, AiGeneratedTask task) {
    final priorityColor = switch (task.priority) {
      'high' => Theme.of(context).colorScheme.primary,
      'low' => PlanoraTheme.success,
      _ => PlanoraTheme.info,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(context, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.radio_button_unchecked_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  task.title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  task.priority,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: priorityColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (task.description != null && task.description!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 30),
              child: Text(
                task.description!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: mutedColor(context),
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (task.estimatedHours != null)
                  buildTaskMetaChip(
                    context,
                    Icons.schedule_rounded,
                    '${task.estimatedHours!.toStringAsFixed(task.estimatedHours! >= 10 ? 0 : 1)}h',
                  ),
                if (task.dueDate != null)
                  buildTaskMetaChip(
                    context,
                    Icons.calendar_today_rounded,
                    formatDate(task.dueDate!),
                  ),
                buildTaskMetaChip(
                  context,
                  Icons.flag_rounded,
                  task.status.replaceAll('_', ' '),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTaskMetaChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: mutedColor(context).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: mutedColor(context)),
          const SizedBox(width: 5),
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

  Widget buildCurrentStep(BuildContext context) {
    switch (currentStep) {
      case 0:
        return buildIdeaStep(context);
      case 1:
        return buildReviewStep(context);
      case 2:
        return buildResultStep(context);
      default:
        return buildIdeaStep(context);
    }
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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  buildHeader(context),
                  const SizedBox(height: 18),
                  buildStepHeader(context),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: KeyedSubtree(
                      key: ValueKey<int>(currentStep),
                      child: buildCurrentStep(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
