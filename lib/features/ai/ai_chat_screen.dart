import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/planora_theme.dart';
import '../auth/data/project_api.dart';
import '../auth/models/project_models.dart';
import '../projects/ai_project_wizard_screen.dart';
import '../projects/data/project_insights_api.dart';
import '../tasks/data/tasks_api.dart';
import '../tasks/models/task_models.dart';
import 'data/ai_chat_api.dart';
import 'data/ai_plan_api.dart';

class AiChatScreen extends StatefulWidget {
  final VoidCallback? onOpenProjects;
  final ProjectsApi projectsApi;
  final AiChatApi aiChatApi;
  final AiPlanApi aiPlanApi;
  final TasksApi tasksApi;
  final ProjectInsightsApi insightsApi;

  const AiChatScreen({
    super.key,
    this.onOpenProjects,
    this.projectsApi = const ProjectsApi(),
    this.aiChatApi = const AiChatApi(),
    this.aiPlanApi = const AiPlanApi(),
    this.tasksApi = const TasksApi(),
    this.insightsApi = const ProjectInsightsApi(),
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController messageController = TextEditingController();
  final ScrollController messagesScrollController = ScrollController();

  late final ProjectsApi _projectsApi = widget.projectsApi;
  late final AiChatApi _aiChatApi = widget.aiChatApi;
  late final AiPlanApi _aiPlanApi = widget.aiPlanApi;
  late final TasksApi _tasksApi = widget.tasksApi;
  late final ProjectInsightsApi _insightsApi = widget.insightsApi;

  int workspaceTab = 0;

  bool isLoadingProjects = true;
  bool isLoadingMessages = false;
  bool isSending = false;
  bool isGeneratingPlan = false;
  bool isMutatingChat = false;
  bool isLoadingWorkspace = false;
  bool isAnalyzingRisk = false;
  bool isPreviewingSchedule = false;
  bool isApplyingSchedule = false;

  String? errorMessage;
  TaskProjectSummary? selectedProject;
  ProjectProgressModel? projectProgress;
  RiskAnalysisPreviewModel? projectRisk;
  SmartSchedulePreviewModel? schedulePreview;
  String? lastFailedMessage;

  List<String> smartSuggestions = [];
  List<ProjectModel> projectModels = [];
  List<TaskProjectSummary> projects = [];
  List<AiChatMessageModel> messages = [];
  List<TaskListItem> workspaceTasks = [];
  List<AiPlanHistoryModel> planHistory = [];

  @override
  void initState() {
    super.initState();
    loadProjects();
  }

  @override
  void dispose() {
    messageController.dispose();
    messagesScrollController.dispose();
    super.dispose();
  }

  Color mutedColor(BuildContext context) {
    return PlanoraTheme.isDark(context)
        ? PlanoraTheme.darkTextMuted
        : PlanoraTheme.textSecondary;
  }

  BoxDecoration glassCardDecoration(
    BuildContext context, {
    double radius = 28,
  }) {
    final isDark = PlanoraTheme.isDark(context);
    final primary = Theme.of(context).colorScheme.primary;

    return BoxDecoration(
      color: isDark
          ? PlanoraTheme.darkSurface.withValues(alpha: 0.90)
          : Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : primary.withValues(alpha: 0.08),
      ),
      boxShadow: [
        BoxShadow(
          color: primary.withValues(alpha: isDark ? 0.18 : 0.10),
          blurRadius: 28,
          offset: const Offset(0, 18),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  String cleanChatText(String value) {
    return value
        .replaceAllMapped(
          RegExp(r'\*\*(.*?)\*\*'),
          (match) => match.group(1) ?? '',
        )
        .replaceAllMapped(RegExp(r'__(.*?)__'), (match) => match.group(1) ?? '')
        .replaceAllMapped(RegExp(r'`([^`]*)`'), (match) => match.group(1) ?? '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  ProjectModel? get selectedProjectModel {
    final selected = selectedProject;
    if (selected == null) return null;

    for (final project in projectModels) {
      if (project.projectId == selected.projectId &&
          project.teamId == selected.teamId) {
        return project;
      }
    }

    return null;
  }

  bool get canUseChatActions {
    return selectedProject != null &&
        !isLoadingMessages &&
        !isSending &&
        !isMutatingChat;
  }

  ProjectModel? projectModelFor(TaskProjectSummary summary) {
    for (final project in projectModels) {
      if (project.projectId == summary.projectId &&
          project.teamId == summary.teamId) {
        return project;
      }
    }

    return null;
  }

  Future<T?> safeWorkspaceLoad<T>(
    Future<T> Function() loader,
    String label,
  ) async {
    try {
      return await loader();
    } catch (error, stackTrace) {
      debugPrint('$label failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> loadWorkspace(ProjectModel project) async {
    if (!mounted) return;

    setState(() {
      isLoadingWorkspace = true;
      schedulePreview = null;
    });

    final loadedProgress = await safeWorkspaceLoad<ProjectProgressModel>(
      () => _insightsApi.getProjectProgress(project.projectId),
      'AI workspace progress',
    );

    final loadedRisk = await safeWorkspaceLoad<RiskAnalysisPreviewModel>(
      () => _insightsApi.previewRisk(project.projectId),
      'AI workspace risk',
    );

    final loadedTasks = await safeWorkspaceLoad<List<TaskListItem>>(
      () => _tasksApi.getProjectTasks(
        project: TaskProjectSummary.fromProject(project),
      ),
      'AI workspace tasks',
    );

    final loadedHistory = await safeWorkspaceLoad<List<AiPlanHistoryModel>>(
      () => _insightsApi.getAiPlanHistory(project),
      'AI plan history',
    );

    if (!mounted) return;

    setState(() {
      projectProgress = loadedProgress;
      projectRisk = loadedRisk;
      workspaceTasks = loadedTasks ?? <TaskListItem>[];
      planHistory = loadedHistory ?? <AiPlanHistoryModel>[];
      isLoadingWorkspace = false;
    });
  }

  Future<void> analyzeSelectedProject() async {
    final project = selectedProjectModel;

    if (project == null || isAnalyzingRisk) return;

    setState(() => isAnalyzingRisk = true);

    try {
      final result = await _insightsApi.previewRisk(project.projectId);

      if (!mounted) return;

      setState(() {
        projectRisk = result;
        isAnalyzingRisk = false;
        workspaceTab = 1;
      });
    } catch (error, stackTrace) {
      logAiChatError('analyze project risk', error, stackTrace);

      if (!mounted) return;

      setState(() => isAnalyzingRisk = false);

      showFriendlySnackBar(
        friendlyAiChatError(error, fallback: 'Could not analyze this project.'),
      );
    }
  }

  Future<void> previewSelectedSchedule() async {
    final project = selectedProjectModel;

    if (project == null || isPreviewingSchedule) return;

    setState(() {
      isPreviewingSchedule = true;
      workspaceTab = 1;
    });

    try {
      final result = await _insightsApi.previewSmartSchedule(project: project);

      if (!mounted) return;

      setState(() {
        schedulePreview = result;
        isPreviewingSchedule = false;
      });
    } catch (error, stackTrace) {
      logAiChatError('preview smart schedule', error, stackTrace);

      if (!mounted) return;

      setState(() => isPreviewingSchedule = false);

      showFriendlySnackBar(
        friendlyAiChatError(
          error,
          fallback: 'Could not preview the smart schedule.',
        ),
      );
    }
  }

  Future<void> applySelectedSchedule() async {
    final project = selectedProjectModel;

    if (project == null || schedulePreview == null || isApplyingSchedule) {
      return;
    }

    setState(() => isApplyingSchedule = true);

    try {
      await _insightsApi.applySmartSchedule(project: project);
      await loadWorkspace(project);

      if (!mounted) return;

      setState(() => isApplyingSchedule = false);

      showFriendlySnackBar('Smart schedule applied successfully.');
    } catch (error, stackTrace) {
      logAiChatError('apply smart schedule', error, stackTrace);

      if (!mounted) return;

      setState(() => isApplyingSchedule = false);

      showFriendlySnackBar(
        friendlyAiChatError(
          error,
          fallback: 'Could not apply the smart schedule.',
        ),
      );
    }
  }

  TaskModel? get focusTask {
    final tasks = workspaceTasks
        .map((item) => item.task)
        .where((task) => !task.isCompleted && !task.isBlocked)
        .toList();

    if (tasks.isEmpty) return null;

    tasks.sort((first, second) {
      return focusScore(second).compareTo(focusScore(first));
    });

    return tasks.first;
  }

  int focusScore(TaskModel task) {
    var score = 0;

    if (task.isOverdue) score += 100;
    if (task.status == TaskStatus.inProgress) score += 50;

    switch (task.priority) {
      case TaskPriority.high:
        score += 35;
      case TaskPriority.medium:
        score += 20;
      case TaskPriority.low:
        score += 10;
    }

    final dueDate = task.dueDate;

    if (dueDate != null) {
      final days = dueDate.difference(DateTime.now()).inDays;

      if (days <= 1) {
        score += 30;
      } else if (days <= 3) {
        score += 20;
      } else if (days <= 7) {
        score += 10;
      }
    }

    return score;
  }

  Color riskTone(BuildContext context) {
    switch (projectRisk?.riskLevel.toLowerCase()) {
      case 'high':
        return Theme.of(context).colorScheme.error;
      case 'medium':
        return Colors.orange;
      case 'low':
        return PlanoraTheme.success;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String workspaceDate(DateTime? date) {
    if (date == null) return 'No date';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  Future<void> loadProjects() async {
    if (!mounted) return;

    setState(() {
      isLoadingProjects = true;
      errorMessage = null;
    });

    try {
      final loadedProjects = await _projectsApi.getProjects();

      final summaries = loadedProjects
          .map(TaskProjectSummary.fromProject)
          .toList();

      if (!mounted) return;

      final firstSummary = summaries.isEmpty ? null : summaries.first;
      final firstModel = loadedProjects.isEmpty ? null : loadedProjects.first;

      setState(() {
        projectModels = loadedProjects;
        projects = summaries;
        selectedProject = firstSummary;

        messages = firstSummary == null
            ? []
            : [buildLocalWelcomeMessage(firstSummary)];

        projectProgress = null;
        projectRisk = null;
        schedulePreview = null;
        workspaceTasks = [];
        planHistory = [];

        isLoadingProjects = false;
      });

      if (firstSummary != null && firstModel != null) {
        await Future.wait<void>([
          loadMessages(firstSummary),
          loadWorkspace(firstModel),
        ]);
      }
    } catch (error, stackTrace) {
      logAiChatError('load projects', error, stackTrace);

      if (!mounted) return;

      setState(() {
        projectModels = [];
        projects = [];
        selectedProject = null;
        messages = [];
        workspaceTasks = [];
        planHistory = [];
        projectProgress = null;
        projectRisk = null;

        errorMessage = friendlyAiChatError(
          error,
          fallback: 'Could not load projects for AI planning.',
        );

        isLoadingProjects = false;
        isLoadingWorkspace = false;
      });

      showFriendlySnackBar(errorMessage!);
    }
  }

  Future<void> loadMessages(TaskProjectSummary project) async {
    if (!mounted) return;

    setState(() {
      isLoadingMessages = true;
      errorMessage = null;
    });

    try {
      final loadedMessages = await _aiChatApi.getHistory(project: project);

      if (!mounted) return;

      setState(() {
        messages = loadedMessages.isEmpty
            ? [buildLocalWelcomeMessage(project)]
            : loadedMessages;
        isLoadingMessages = false;
      });

      scrollMessagesToBottom(animated: false);
    } catch (error, stackTrace) {
      logAiChatError('load chat history', error, stackTrace);
      if (!mounted) return;

      setState(() {
        messages = [buildLocalWelcomeMessage(project)];
        errorMessage = null;
        isLoadingMessages = false;
      });

      showFriendlySnackBar(
        friendlyAiChatError(error, fallback: 'Could not load AI chat history.'),
      );
    }
  }

  Future<void> changeProject(TaskProjectSummary project) async {
    if (!mounted) return;

    final model = projectModelFor(project);

    setState(() {
      selectedProject = project;
      messages = [buildLocalWelcomeMessage(project)];

      projectProgress = null;
      projectRisk = null;
      schedulePreview = null;
      workspaceTasks = [];
      planHistory = [];

      smartSuggestions = [];
      lastFailedMessage = null;
      errorMessage = null;
      workspaceTab = 0;
    });

    scrollMessagesToBottom(animated: false);

    if (model == null) {
      await loadMessages(project);
      return;
    }

    await Future.wait<void>([loadMessages(project), loadWorkspace(model)]);
  }

  Future<void> startNewChatForSelectedProject() async {
    final project = selectedProject;
    if (project == null || isMutatingChat) return;

    await clearProjectChat(
      project,
      requireConfirmation: false,
      successMessage: 'New chat started for ${project.title}.',
    );
  }

  Future<void> deleteSelectedChat() async {
    final project = selectedProject;
    if (project == null || isMutatingChat) return;

    await clearProjectChat(
      project,
      requireConfirmation: true,
      successMessage: 'Chat deleted for ${project.title}.',
    );
  }

  Future<void> deleteDrawerProjectChat(TaskProjectSummary project) async {
    if (isMutatingChat) return;

    await clearProjectChat(
      project,
      requireConfirmation: true,
      successMessage: 'Chat deleted for ${project.title}.',
    );
  }

  Future<void> clearProjectChat(
    TaskProjectSummary project, {
    required bool requireConfirmation,
    required String successMessage,
  }) async {
    if (requireConfirmation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Delete this chat?'),
            content: Text(
              'This will remove the AI chat history for "${project.title}". The project and tasks will stay safe.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );

      if (!mounted || confirmed != true) return;
    }

    setState(() {
      isMutatingChat = true;
      errorMessage = null;
    });

    try {
      await _aiChatApi.deleteHistory(project: project);

      if (!mounted) return;

      final isSelected =
          selectedProject?.projectId == project.projectId &&
          selectedProject?.teamId == project.teamId;

      setState(() {
        isMutatingChat = false;
        if (isSelected) {
          messages = [buildLocalWelcomeMessage(project)];
          smartSuggestions = [];
          lastFailedMessage = null;
          errorMessage = null;
        }
      });

      showFriendlySnackBar(successMessage);
      scrollMessagesToBottom(animated: false);
    } catch (error, stackTrace) {
      logAiChatError('delete chat', error, stackTrace);
      if (!mounted) return;

      setState(() {
        isMutatingChat = false;
        errorMessage = friendlyAiChatError(
          error,
          fallback: 'Could not delete this chat. Please try again.',
        );
      });

      showFriendlySnackBar(errorMessage!);
    }
  }

  Future<void> generatePlanForSelectedProject() async {
    final project = selectedProjectModel;
    if (project == null || isGeneratingPlan) return;

    final typedPrompt = messageController.text.trim();
    final prompt = typedPrompt.isEmpty
        ? defaultPlanPrompt(project)
        : 'Create a project task plan for ${project.title}. Context: $typedPrompt';

    if (!mounted) return;

    setState(() {
      isGeneratingPlan = true;
      errorMessage = null;
    });

    try {
      final response = await _aiPlanApi.generatePlan(
        project: project,
        prompt: prompt,
        generateTasks: true,
        overwriteExistingTasks: false,
        preferredTaskCount: 8,
      );

      if (!mounted) return;

      await loadWorkspace(project);

      if (!mounted) return;

      setState(() {
        isGeneratingPlan = false;
        workspaceTab = 0;
      });

      showGeneratedPlanResult(response);
    } catch (error, stackTrace) {
      logAiChatError('generate plan', error, stackTrace);
      if (!mounted) return;

      setState(() => isGeneratingPlan = false);
      showFriendlySnackBar(
        friendlyAiChatError(
          error,
          fallback: 'Could not generate AI tasks. Please try again.',
        ),
      );
    }
  }

  void showGeneratedPlanResult(AiPlanGenerateResponse response) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: PlanoraTheme.primaryGradientFor(context),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Plan generated',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            '${response.tasksCreated} tasks added',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: mutedColor(context),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (response.summary.trim().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: glassCardDecoration(context, radius: 20),
                    child: Text(
                      response.summary,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.task_alt_rounded, size: 17),
                      label: Text('${response.tasksCreated} created'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.content_copy_rounded, size: 17),
                      label: Text(
                        '${response.tasksSkippedAsDuplicates} duplicates skipped',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Generated work',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                for (final task in response.tasks)
                  Container(
                    margin: const EdgeInsets.only(bottom: 9),
                    padding: const EdgeInsets.all(14),
                    decoration: glassCardDecoration(context, radius: 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${task.priority} priority'
                                '${task.estimatedHours == null ? '' : ' • ${task.estimatedHours!.toStringAsFixed(1)}h'}'
                                '${task.dueDate == null ? '' : ' • ${workspaceDate(task.dueDate)}'}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: mutedColor(context),
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
            );
          },
        );
      },
    );
  }

  String defaultPlanPrompt(ProjectModel project) {
    final description = project.description?.trim();
    if (description != null && description.isNotEmpty) {
      return 'Create a practical task plan for ${project.title}. Context: $description';
    }
    return 'Create a practical task plan for ${project.title}.';
  }

  Future<void> sendMessage() async {
    final project = selectedProject;
    final message = messageController.text.trim();

    if (project == null) {
      showFriendlySnackBar('Choose a project before sending a message.');
      return;
    }

    if (message.isEmpty || isSending) return;

    final optimisticMessage = AiChatMessageModel(
      messageId: DateTime.now().microsecondsSinceEpoch,
      senderId: null,
      projectId: project.projectId,
      message: message,
      senderType: 'user',
      createdAt: DateTime.now(),
    );

    if (!mounted) return;

    setState(() {
      isSending = true;
      errorMessage = null;
      lastFailedMessage = null;
      smartSuggestions = [];
      messages = [...messages, optimisticMessage];
    });

    messageController.clear();
    scrollMessagesToBottom();

    try {
      final result = await _aiChatApi.sendMessage(
        project: project,
        message: message,
      );

      if (!mounted) return;

      setState(() {
        messages = [...messages, result.message];
        smartSuggestions = result.suggestions;
        lastFailedMessage = null;
        errorMessage = null;
        isSending = false;
      });

      scrollMessagesToBottom();
    } catch (error, stackTrace) {
      logAiChatError('send message', error, stackTrace);

      if (!mounted) return;

      setState(() {
        messages = messages
            .where((item) => item.messageId != optimisticMessage.messageId)
            .toList();

        isSending = false;
        lastFailedMessage = message;

        errorMessage = friendlyAiChatError(
          error,
          fallback: 'Could not send your message. Please try again.',
        );
      });

      scrollMessagesToBottom();
    }
  }

  Future<void> retryLastMessage() async {
    final message = lastFailedMessage;

    if (message == null || message.trim().isEmpty || isSending) {
      return;
    }

    messageController.text = message;

    setState(() {
      errorMessage = null;
      lastFailedMessage = null;
    });

    await sendMessage();
  }

  Future<void> openAiProjectWizard() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AiProjectWizardScreen(onPlanCreated: loadProjects),
      ),
    );

    if (!mounted) return;
    await loadProjects();
  }

  AiChatMessageModel buildLocalWelcomeMessage(TaskProjectSummary? project) {
    final projectText = project == null ? 'this project' : "'${project.title}'";

    return AiChatMessageModel.localAssistant(
      projectId: project?.projectId,
      message:
          'New Planora AI chat ready for $projectText. Ask me about next tasks, risks, schedule, blockers, or how to break work into smaller steps.',
    );
  }

  void logAiChatError(String action, Object error, StackTrace stackTrace) {
    debugPrint('AI Chat $action failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  String friendlyAiChatError(Object error, {required String fallback}) {
    if (error is ApiException) {
      final statusCode = error.statusCode;
      if (statusCode == 404) {
        return 'Planora AI chat is not available for this project yet.';
      }
      if (statusCode != null && statusCode >= 500) {
        return 'Planora AI is temporarily unavailable. Please try again later.';
      }
      if (error.message.trim().isNotEmpty) return error.message;
    }
    return fallback;
  }

  void showFriendlySnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String formatChatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  Future<void> copyChatMessage(String message) async {
    await Clipboard.setData(ClipboardData(text: cleanChatText(message)));

    if (!mounted) return;

    showFriendlySnackBar('Message copied.');
  }

  void scrollMessagesToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !messagesScrollController.hasClients) return;

      final position = messagesScrollController.position.maxScrollExtent;
      if (animated) {
        messagesScrollController.animateTo(
          position,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      } else {
        messagesScrollController.jumpTo(position);
      }
    });
  }

  List<String> chatSuggestions() {
    if (smartSuggestions.isNotEmpty) {
      return smartSuggestions.take(4).toList();
    }

    final suggestions = <String>[];
    final risk = projectRisk;
    final progress = projectProgress;

    if ((risk?.blockedTasks ?? 0) > 0) {
      suggestions.add('How can I unblock the blocked tasks?');
    } else if ((risk?.overdueTasks ?? 0) > 0) {
      suggestions.add('Which overdue task should I do first?');
    } else {
      suggestions.add('What should I focus on next?');
    }

    if (risk != null) {
      suggestions.add('Explain why this project is ${risk.riskLevel} risk');
    } else {
      suggestions.add('Am I likely to miss the deadline?');
    }

    if ((progress?.taskStatusCounts.inProgress ?? 0) > 0) {
      suggestions.add('Help me finish my active tasks');
    } else {
      suggestions.add('Break my next task into small steps');
    }

    suggestions.add(
      selectedProject?.isTeamProject == true
          ? 'How is the team workload?'
          : 'Make me a realistic plan for this week',
    );

    return suggestions.take(4).toList();
  }

  Future<void> sendSuggestion(String suggestion) async {
    if (isSending || messageController.text.trim().isNotEmpty) return;
    messageController.text = suggestion;
    await sendMessage();
  }

  Widget animatedEntrance(int index, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (index * 45)),
      curve: Curves.easeOutCubic,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: Transform.scale(
              scale: 0.98 + (value * 0.02),
              child: animatedChild,
            ),
          ),
        );
      },
      child: child,
    );
  }

  Widget buildWorkspaceTabs(BuildContext context) {
    const tabs = [
      ('Chat', Icons.forum_rounded),
      ('Insights', Icons.insights_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: glassCardDecoration(context, radius: 20),
      child: Row(
        children: [
          for (var index = 0; index < tabs.length; index++)
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() => workspaceTab = index);

                  if (index == 0) {
                    scrollMessagesToBottom(animated: false);
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    gradient: workspaceTab == index
                        ? PlanoraTheme.primaryGradientFor(context)
                        : null,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tabs[index].$2,
                        size: 17,
                        color: workspaceTab == index
                            ? Colors.white
                            : mutedColor(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tabs[index].$1,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: workspaceTab == index
                                  ? Colors.white
                                  : mutedColor(context),
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildWorkspaceContent(BuildContext context) {
    if (isLoadingProjects) {
      return buildStateCard(
        context,
        icon: Icons.auto_awesome_rounded,
        title: 'Preparing Planora AI...',
        message: 'Loading your projects and AI chat history.',
        showSpinner: true,
      );
    }

    if (projects.isEmpty) {
      return buildStateCard(
        context,
        icon: Icons.rocket_launch_rounded,
        title: 'Build your first AI project',
        message:
            'Describe your idea and Planora will create the project, tasks, deadlines, risks, and milestones.',
        buttonText: 'Start AI planning',
        onPressed: openAiProjectWizard,
      );
    }

    if (selectedProject == null) {
      return buildStateCard(
        context,
        icon: Icons.folder_open_rounded,
        title: 'Choose a project',
        message: 'Open the project menu to begin chatting with Planora AI.',
      );
    }

    if (workspaceTab == 1 && isLoadingWorkspace) {
      return buildStateCard(
        context,
        icon: Icons.sync_rounded,
        title: 'Analyzing project...',
        message: 'Preparing progress, risks, recommendations, and schedule.',
        showSpinner: true,
      );
    }

    if (workspaceTab == 1) {
      return buildInsightsWorkspace(context);
    }

    return buildMessages(context);
  }

  Widget buildInsightsWorkspace(BuildContext context) {
    final risk = projectRisk;
    final progress = projectProgress;
    final preview = schedulePreview;
    final tone = riskTone(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: glassCardDecoration(context, radius: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(Icons.health_and_safety_rounded, color: tone),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Project risk',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          risk == null
                              ? 'Not analyzed'
                              : '${risk.riskLevel.toUpperCase()} RISK',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: tone,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: isAnalyzingRisk ? null : analyzeSelectedProject,
                    icon: isAnalyzingRisk
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (risk == null)
                Text(
                  'Run the risk analysis to find delays, blocked tasks, overdue work, and deadline pressure.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mutedColor(context),
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else ...[
                Text(
                  risk.reason,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mutedColor(context),
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('${risk.predictedDelayDays} delay days')),
                    Chip(label: Text('${risk.overdueTasks} overdue')),
                    Chip(label: Text('${risk.blockedTasks} blocked')),
                    Chip(
                      label: Text(
                        '${risk.remainingEstimatedHours.toStringAsFixed(1)}h left',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  risk.recommendation,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tone,
                    height: 1.45,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: glassCardDecoration(context, radius: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Smart schedule',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                preview == null
                    ? 'Preview an optimized project schedule before applying deadline changes.'
                    : '${preview.schedulableTaskCount} tasks can be scheduled across ${preview.estimatedTotalHours.toStringAsFixed(1)} estimated hours.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: mutedColor(context),
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (preview != null && preview.warnings.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final warning in preview.warnings.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Text(
                      '• $warning',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: isPreviewingSchedule
                        ? null
                        : previewSelectedSchedule,
                    icon: isPreviewingSchedule
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.preview_rounded),
                    label: const Text('Preview'),
                  ),
                  FilledButton.icon(
                    onPressed: preview == null || isApplyingSchedule
                        ? null
                        : applySelectedSchedule,
                    icon: isApplyingSchedule
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text('Apply schedule'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: glassCardDecoration(context, radius: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Project health',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              if (progress == null)
                Text(
                  'Project health information is unavailable.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: mutedColor(context)),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(
                        '${progress.project.completionPercentage.round()}% complete',
                      ),
                    ),
                    Chip(
                      label: Text(
                        '${progress.taskStatusCounts.inProgress} active',
                      ),
                    ),
                    Chip(
                      label: Text(
                        '${progress.taskStatusCounts.blocked} blocked',
                      ),
                    ),
                    Chip(
                      label: Text(
                        '${progress.hours.remainingEstimatedHours.toStringAsFixed(1)}h remaining',
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: glassCardDecoration(context, radius: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI plan history',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              if (planHistory.isEmpty)
                Text(
                  'Generated AI plans will appear here.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mutedColor(context),
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                for (final plan in planHistory.take(5))
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.summary,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${plan.generatedTaskCount} tasks • '
                          '${workspaceDate(plan.createdAt)}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: mutedColor(context),
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
    );
  }

  Widget buildHeader(BuildContext context) {
    final project = selectedProject;
    final primary = Theme.of(context).colorScheme.primary;
    final hasProjects = projects.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: glassCardDecoration(context, radius: 26),
      child: Row(
        children: [
          _PulseIconButton(
            icon: hasProjects ? Icons.menu_rounded : Icons.auto_awesome_rounded,
            onTap: hasProjects
                ? () => _scaffoldKey.currentState?.openDrawer()
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  project?.title ?? 'Planora AI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  project == null
                      ? 'Create a project to unlock AI planning chat.'
                      : 'Focused AI chat for tasks, risks, schedule, and next steps.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mutedColor(context),
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Generate tasks',
            child: InkWell(
              onTap: selectedProjectModel == null || isGeneratingPlan
                  ? null
                  : generatePlanForSelectedProject,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: primary.withValues(alpha: 0.12)),
                ),
                child: isGeneratingPlan
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : Icon(Icons.auto_awesome_rounded, color: primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildProjectDrawer(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Drawer(
      backgroundColor: isDark
          ? PlanoraTheme.darkBackground
          : PlanoraTheme.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: PlanoraTheme.primaryGradientFor(context),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: PlanoraTheme.floatingShadowFor(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Project Chats',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Pick a project, start a fresh chat, or delete a project chat history.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: buildDrawerAction(
                      context,
                      icon: Icons.add_comment_rounded,
                      label: 'New chat',
                      onTap: canUseChatActions
                          ? () {
                              Navigator.of(context).pop();
                              startNewChatForSelectedProject();
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: buildDrawerAction(
                      context,
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                      danger: true,
                      onTap: canUseChatActions
                          ? () {
                              Navigator.of(context).pop();
                              deleteSelectedChat();
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                'Projects',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: mutedColor(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: projects.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No projects yet. Create one with AI first.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: mutedColor(context),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                      itemCount: projects.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final project = projects[index];
                        final isSelected =
                            selectedProject?.projectId == project.projectId &&
                            selectedProject?.teamId == project.teamId;

                        return animatedEntrance(
                          index,
                          buildProjectDrawerTile(
                            context,
                            project: project,
                            isSelected: isSelected,
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: OutlinedButton.icon(
                onPressed: openAiProjectWizard,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Plan new project with AI'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDrawerAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool danger = false,
  }) {
    final primary = danger
        ? PlanoraTheme.error
        : Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: primary.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: onTap == null ? mutedColor(context) : primary,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: onTap == null ? mutedColor(context) : primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildProjectDrawerTile(
    BuildContext context, {
    required TaskProjectSummary project,
    required bool isSelected,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = PlanoraTheme.isDark(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: isLoadingMessages
            ? null
            : () async {
                Navigator.of(context).pop();
                await changeProject(project);
              },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? primary.withValues(alpha: isDark ? 0.22 : 0.12)
                : isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.white.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? primary.withValues(alpha: 0.42)
                  : primary.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? PlanoraTheme.primaryGradientFor(context)
                      : null,
                  color: isSelected ? null : primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  project.isTeamProject
                      ? Icons.groups_2_rounded
                      : Icons.folder_rounded,
                  color: isSelected ? Colors.white : primary,
                  size: 20,
                ),
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
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      project.isTeamProject
                          ? 'Team AI chat'
                          : 'Personal AI chat',
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
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: primary, size: 20)
              else
                IconButton(
                  tooltip: 'Delete chat',
                  onPressed: isMutatingChat
                      ? null
                      : () => deleteDrawerProjectChat(project),
                  icon: const Icon(Icons.delete_outline_rounded, size: 19),
                  color: PlanoraTheme.error,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildProjectHero(BuildContext context) {
    final project = selectedProject;
    if (project == null || isLoadingProjects || isLoadingMessages) {
      return const SizedBox.shrink();
    }

    final primary = Theme.of(context).colorScheme.primary;

    return animatedEntrance(
      0,
      Container(
        padding: const EdgeInsets.all(16),
        decoration: glassCardDecoration(context, radius: 24),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: PlanoraTheme.primaryGradientFor(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.psychology_alt_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Focused project assistant',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'This chat only uses ${project.title} context, tasks, deadlines, risk, and team workload.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: mutedColor(context),
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMessages(BuildContext context) {
    if (isLoadingProjects || isLoadingMessages) {
      return buildStateCard(
        context,
        icon: Icons.sync_rounded,
        title: 'Loading AI workspace...',
        message: 'Preparing project context and chat history.',
        showSpinner: true,
      );
    }

    if (projects.isEmpty) {
      return buildStateCard(
        context,
        icon: Icons.folder_open_rounded,
        title: 'No project chats yet',
        message:
            'Create your first project with AI, then chat about its tasks, risks, and next steps.',
        buttonText: 'Plan with AI',
        onPressed: openAiProjectWizard,
      );
    }

    if (selectedProject == null) {
      return buildStateCard(
        context,
        icon: Icons.menu_open_rounded,
        title: 'Choose a project chat',
        message: 'Open the menu and choose a project before sending messages.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (messages.length <= 1) ...[
          buildProjectHero(context),
          const SizedBox(height: 14),
        ],

        for (var index = 0; index < messages.length; index++) ...[
          buildMessageBubble(context, messages[index], index: index),
          const SizedBox(height: 12),
        ],

        if (errorMessage != null && !isSending) ...[
          buildInlineError(context, errorMessage!),
          const SizedBox(height: 12),
        ],

        if (isSending)
          buildTypingIndicator(context)
        else if (errorMessage == null) ...[
          const SizedBox(height: 2),
          buildSuggestionChips(context),
        ],
      ],
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
    return animatedEntrance(
      0,
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: glassCardDecoration(context),
        child: Column(
          children: [
            if (showSpinner)
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 2.7),
              )
            else
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  gradient: PlanoraTheme.primaryGradientFor(context),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            if (message != null) ...[
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
            if (buttonText != null && onPressed != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(buttonText),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildSuggestionChips(BuildContext context) {
    final suggestions = chatSuggestions();
    final primary = Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return animatedEntrance(
            index + 1,
            ActionChip(
              onPressed: isSending ? null : () => sendSuggestion(suggestion),
              avatar: Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: primary,
              ),
              label: Text(suggestion, overflow: TextOverflow.ellipsis),
              backgroundColor: primary.withValues(alpha: 0.08),
              side: BorderSide(color: primary.withValues(alpha: 0.16)),
              labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: primary,
                fontWeight: FontWeight.w900,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildMessageBubble(
    BuildContext context,
    AiChatMessageModel message, {
    required int index,
  }) {
    final isAssistant = message.isAssistant;
    final isDark = PlanoraTheme.isDark(context);
    final primary = Theme.of(context).colorScheme.primary;
    final bubbleText = cleanChatText(message.message);

    return _AnimatedChatMessageEntry(
      key: ValueKey(
        '${message.messageId}-${message.createdAt.microsecondsSinceEpoch}',
      ),
      index: index,
      isAssistant: isAssistant,
      child: Align(
        alignment: isAssistant ? Alignment.centerLeft : Alignment.centerRight,
        child: Row(
          mainAxisAlignment: isAssistant
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isAssistant) ...[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: PlanoraTheme.primaryGradientFor(context),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: PlanoraTheme.cardShadowFor(context),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 335),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    gradient: isAssistant
                        ? null
                        : PlanoraTheme.primaryGradientFor(context),
                    color: isAssistant
                        ? isDark
                              ? PlanoraTheme.darkSurface.withValues(alpha: 0.96)
                              : Colors.white
                        : null,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(22),
                      topRight: const Radius.circular(22),
                      bottomLeft: Radius.circular(isAssistant ? 7 : 22),
                      bottomRight: Radius.circular(isAssistant ? 22 : 7),
                    ),
                    border: isAssistant
                        ? Border.all(
                            color: isDark
                                ? PlanoraTheme.darkBorder
                                : primary.withValues(alpha: 0.08),
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: isAssistant
                            ? Colors.black.withValues(
                                alpha: isDark ? 0.18 : 0.06,
                              )
                            : primary.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        bubbleText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isAssistant ? null : Colors.white,
                          height: 1.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatChatTime(message.createdAt),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: isAssistant
                                      ? mutedColor(context)
                                      : Colors.white.withValues(alpha: 0.72),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          if (isAssistant) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => copyChatMessage(message.message),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: Icon(
                                  Icons.copy_rounded,
                                  size: 14,
                                  color: mutedColor(context),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTypingIndicator(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: glassCardDecoration(context, radius: 18),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Planora AI is thinking',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: mutedColor(context),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            _AiTypingDots(color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget buildInlineError(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PlanoraTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PlanoraTheme.error.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: PlanoraTheme.error,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: PlanoraTheme.error,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (lastFailedMessage != null) ...[
            const SizedBox(width: 6),
            TextButton.icon(
              onPressed: isSending ? null : retryLastMessage,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildComposer(BuildContext context) {
    final canSend = selectedProject != null && !isSending && !isMutatingChat;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: glassCardDecoration(context, radius: 26),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: PlanoraTheme.isDark(context)
                    ? PlanoraTheme.darkSurfaceVariant
                    : PlanoraTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: primary.withValues(alpha: 0.08)),
              ),
              child: TextField(
                controller: messageController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => sendMessage(),
                decoration: InputDecoration(
                  hintText: selectedProject == null
                      ? 'Choose a project first...'
                      : 'Ask about this plan...',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 50,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: canSend
                    ? PlanoraTheme.primaryGradientFor(context)
                    : null,
                color: canSend
                    ? null
                    : mutedColor(context).withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(19),
                boxShadow: canSend
                    ? PlanoraTheme.floatingShadowFor(context)
                    : null,
              ),
              child: ElevatedButton(
                onPressed: canSend ? sendMessage : null,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(19),
                  ),
                ),
                child: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_upward_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRefreshableChat(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        final projectSummary = selectedProject;
        final projectModel = selectedProjectModel;

        if (projectSummary == null || projectModel == null) {
          await loadProjects();
          return;
        }

        if (workspaceTab == 0) {
          await loadMessages(projectSummary);
        } else {
          await loadWorkspace(projectModel);
        }
      },
      child: ListView(
        controller: messagesScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(2, 2, 2, workspaceTab == 0 ? 118 : 28),
        children: [buildWorkspaceContent(context)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      drawer: buildProjectDrawer(context),
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                animatedEntrance(0, buildHeader(context)),
                if (!isLoadingProjects && projects.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  buildWorkspaceTabs(context),
                ],
                const SizedBox(height: 12),
                Expanded(child: buildRefreshableChat(context)),
              ],
            ),
          ),
          if (!isLoadingProjects && projects.isNotEmpty && workspaceTab == 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 14,
              child: buildComposer(context),
            ),
          if (isMutatingChat)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.04),
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PulseIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _PulseIconButton({required this.icon, this.onTap});

  @override
  State<_PulseIconButton> createState() => _PulseIconButtonState();
}

class _PulseIconButtonState extends State<_PulseIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 1,
        end: 1.035,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: PlanoraTheme.primaryGradientFor(context),
            borderRadius: BorderRadius.circular(20),
            boxShadow: PlanoraTheme.floatingShadowFor(context),
          ),
          child: Icon(widget.icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

class _AnimatedChatMessageEntry extends StatefulWidget {
  final Widget child;
  final int index;
  final bool isAssistant;

  const _AnimatedChatMessageEntry({
    super.key,
    required this.child,
    required this.index,
    required this.isAssistant,
  });

  @override
  State<_AnimatedChatMessageEntry> createState() =>
      _AnimatedChatMessageEntryState();
}

class _AnimatedChatMessageEntryState extends State<_AnimatedChatMessageEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 250 + (widget.index % 5) * 35),
    );

    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _offset = Tween<Offset>(
      begin: Offset(widget.isAssistant ? -0.06 : 0.06, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _scale = Tween<double>(
      begin: 0.97,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}

class _AiTypingDots extends StatefulWidget {
  final Color color;

  const _AiTypingDots({required this.color});

  @override
  State<_AiTypingDots> createState() => _AiTypingDotsState();
}

class _AiTypingDotsState extends State<_AiTypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < 3; index++) ...[
          buildDot(index),
          if (index != 2) const SizedBox(width: 4),
        ],
      ],
    );
  }

  Widget buildDot(int index) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        index * 0.18,
        0.64 + index * 0.18,
        curve: Curves.easeInOut,
      ),
    );

    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(animation),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.75, end: 1).animate(animation),
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
