import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/planora_theme.dart';
import '../auth/data/project_api.dart';
import '../auth/models/project_models.dart';
import '../projects/ai_project_wizard_screen.dart';
import '../tasks/models/task_models.dart';
import 'data/ai_chat_api.dart';
import 'data/ai_plan_api.dart';

class AiChatScreen extends StatefulWidget {
  final VoidCallback? onOpenProjects;
  final ProjectsApi projectsApi;
  final AiChatApi aiChatApi;
  final AiPlanApi aiPlanApi;

  const AiChatScreen({
    super.key,
    this.onOpenProjects,
    this.projectsApi = const ProjectsApi(),
    this.aiChatApi = const AiChatApi(),
    this.aiPlanApi = const AiPlanApi(),
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final ProjectsApi _projectsApi = widget.projectsApi;
  late final AiChatApi _aiChatApi = widget.aiChatApi;
  late final AiPlanApi _aiPlanApi = widget.aiPlanApi;

  final TextEditingController messageController = TextEditingController();
  final ScrollController messagesScrollController = ScrollController();

  bool isLoadingProjects = true;
  bool isLoadingMessages = false;
  bool isSending = false;
  bool isGeneratingPlan = false;

  String? errorMessage;
  TaskProjectSummary? selectedProject;

  List<ProjectModel> projectModels = [];
  List<TaskProjectSummary> projects = [];
  List<AiChatMessageModel> messages = [];

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

      setState(() {
        projectModels = loadedProjects;
        projects = summaries;
        selectedProject = summaries.isEmpty ? null : summaries.first;
        messages = summaries.isEmpty
            ? []
            : [buildLocalWelcomeMessage(summaries.first)];
        isLoadingProjects = false;
      });

      if (summaries.isNotEmpty) {
        await loadMessages(summaries.first);
      }
    } catch (error, stackTrace) {
      logAiChatError('load projects', error, stackTrace);

      if (!mounted) return;

      setState(() {
        projectModels = [];
        projects = [];
        selectedProject = null;
        messages = [];
        errorMessage = friendlyAiChatError(
          error,
          fallback: 'Could not load projects for AI chat.',
        );
        isLoadingProjects = false;
      });

      showFriendlySnackBar(errorMessage!);
    }
  }

  Future<void> loadMessages(TaskProjectSummary project) async {
    if (!mounted) return;

    setState(() {
      isLoadingMessages = true;
      errorMessage = null;
      messages = messages.isEmpty
          ? [buildLocalWelcomeMessage(project)]
          : messages;
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

      scrollMessagesToBottom();
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

  Future<void> changeProject(TaskProjectSummary? project) async {
    if (project == null) return;

    if (!mounted) return;

    setState(() {
      selectedProject = project;
      messages = [buildLocalWelcomeMessage(project)];
    });

    scrollMessagesToBottom();
    await loadMessages(project);
  }

  ProjectModel? get selectedProjectModel {
    final selected = selectedProject;

    if (selected == null) {
      return null;
    }

    for (final project in projectModels) {
      final sameProject = project.projectId == selected.projectId;
      final sameTeam = project.teamId == selected.teamId;

      if (sameProject && sameTeam) {
        return project;
      }
    }

    return null;
  }

  Future<void> generatePlanForSelectedProject() async {
    final project = selectedProjectModel;

    if (project == null || isGeneratingPlan) {
      return;
    }

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

      setState(() {
        isGeneratingPlan = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI created ${response.tasksCreated} project tasks.'),
        ),
      );
    } catch (error, stackTrace) {
      logAiChatError('generate plan', error, stackTrace);

      if (!mounted) return;

      setState(() {
        isGeneratingPlan = false;
      });

      showFriendlySnackBar(
        friendlyAiChatError(
          error,
          fallback: 'Could not generate AI tasks. Please try again.',
        ),
      );
    }
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

    if (message.isEmpty || isSending) {
      return;
    }

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
      messages = [...messages, optimisticMessage];
    });

    scrollMessagesToBottom();

    messageController.clear();

    try {
      final aiMessage = await _aiChatApi.sendMessage(
        project: project,
        message: message,
      );

      if (!mounted) return;

      setState(() {
        messages = [...messages, aiMessage];
        isSending = false;
      });

      scrollMessagesToBottom();
    } catch (error, stackTrace) {
      logAiChatError('send message', error, stackTrace);

      if (!mounted) return;

      setState(() {
        isSending = false;
        errorMessage = friendlyAiChatError(
          error,
          fallback: 'Could not send your message. Please try again.',
        );
      });

      showFriendlySnackBar(errorMessage!);
    }
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
    return AiChatMessageModel.localAssistant(
      projectId: project?.projectId,
      message:
          'Hi, I’m Planora AI. Ask me to explain tasks, break work into smaller steps, help when you’re stuck, or suggest what to do next.',
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

      if (error.message.trim().isNotEmpty) {
        return error.message;
      }
    }

    return fallback;
  }

  void showFriendlySnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void scrollMessagesToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !messagesScrollController.hasClients) {
        return;
      }

      messagesScrollController.jumpTo(
        messagesScrollController.position.maxScrollExtent,
      );
    });
  }

  String cleanChatText(String value) {
    return value
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1')
        .replaceAll(RegExp(r'__(.*?)__'), r'$1')
        .replaceAll(RegExp(r'`([^`]*)`'), r'$1')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  bool get selectedProjectLooksBusiness {
    final title = selectedProject?.title.toLowerCase() ?? '';
    final modelDescription =
        selectedProjectModel?.description?.toLowerCase() ?? '';
    final text = '$title $modelDescription';

    return text.contains('business') ||
        text.contains('store') ||
        text.contains('shop') ||
        text.contains('brand') ||
        text.contains('sell') ||
        text.contains('selling') ||
        text.contains('online');
  }

  List<String> chatSuggestions() {
    final baseSuggestions = <String>[
      'What should I do first?',
      'Explain this task',
      'Break it down',
      'I’m stuck',
      'What is team workload?',
      'Why is this project risky?',
    ];

    if (selectedProjectLooksBusiness) {
      return <String>[
        'What should I sell first?',
        'How do I find suppliers?',
        'How should I price it?',
        'What should I post first?',
        ...baseSuggestions.take(4),
      ];
    }

    return baseSuggestions;
  }

  Future<void> sendSuggestion(String suggestion) async {
    if (isSending) {
      return;
    }

    messageController.text = suggestion;
    await sendMessage();
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

  Widget buildHeader(BuildContext context) {
    final project = selectedProject;
    final hasProjects = projects.isNotEmpty;

    return Row(
      children: [
        InkWell(
          onTap: hasProjects
              ? () => _scaffoldKey.currentState?.openDrawer()
              : null,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: PlanoraTheme.primaryGradientFor(context),
              borderRadius: BorderRadius.circular(18),
              boxShadow: PlanoraTheme.floatingShadowFor(context),
            ),
            child: Icon(
              hasProjects ? Icons.menu_rounded : Icons.auto_awesome_rounded,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                project?.title ?? 'Planora AI',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                project == null
                    ? 'Plan new ideas or improve an existing project.'
                    : 'Project planning chat for tasks, risks, and next steps.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: mutedColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (hasProjects) ...[
          const SizedBox(width: 10),
          InkWell(
            onTap:
                isLoadingMessages || isGeneratingPlan || selectedProject == null
                ? null
                : generatePlanForSelectedProject,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 46,
              height: 46,
              decoration: cardDecoration(context),
              child: isGeneratingPlan
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.auto_awesome_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
            ),
          ),
        ],
      ],
    );
  }

  Widget buildProjectDrawer(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Drawer(
      backgroundColor: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
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
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Project Chats',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Choose a project. Each project keeps its own AI chat history.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: mutedColor(context),
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Divider(
              color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
            ),
            Expanded(
              child: projects.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No projects yet.',
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
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                      itemCount: projects.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final project = projects[index];
                        final isSelected =
                            selectedProject?.projectId == project.projectId &&
                            selectedProject?.teamId == project.teamId;

                        return buildProjectDrawerTile(
                          context,
                          project: project,
                          isSelected: isSelected,
                        );
                      },
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

    return InkWell(
      onTap: isLoadingMessages
          ? null
          : () async {
              Navigator.of(context).pop();
              await changeProject(project);
            },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: isDark ? 0.22 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? primary.withValues(alpha: 0.45)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? primary
                    : primary.withValues(alpha: isDark ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(13),
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
                        ? 'Team project chat'
                        : 'Personal project chat',
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
              Icon(Icons.check_circle_rounded, color: primary, size: 22),
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
        title: 'Loading AI chat...',
        showSpinner: true,
      );
    }

    if (projects.isEmpty) {
      return buildStateCard(
        context,
        icon: Icons.folder_open_rounded,
        title: 'Plan a project with AI first.',
        message:
            'Describe an idea so Planora can create a project plan and tasks.',
        buttonText: 'Plan with AI',
        onPressed: openAiProjectWizard,
      );
    }

    if (selectedProject == null) {
      return buildStateCard(
        context,
        icon: Icons.folder_open_rounded,
        title: 'Choose a project to start chatting with Planora AI.',
        message: 'Tap the menu button and choose a project before sending.',
      );
    }

    if (errorMessage != null && messages.isEmpty) {
      return buildStateCard(
        context,
        icon: Icons.wifi_off_rounded,
        title: errorMessage!,
        buttonText: 'Try Again',
        onPressed: () {
          final project = selectedProject;
          if (project != null) {
            loadMessages(project);
          }
        },
      );
    }

    if (messages.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildChatIntroCard(context),
          const SizedBox(height: 14),
          buildSuggestionChips(context),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildSuggestionChips(context),
        const SizedBox(height: 14),
        for (var index = 0; index < messages.length; index++) ...[
          buildMessageBubble(context, messages[index], index: index),
          const SizedBox(height: 10),
        ],
        if (errorMessage != null) buildInlineError(context, errorMessage!),
        if (isSending) ...[
          const SizedBox(height: 8),
          buildTypingIndicator(context),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: cardDecoration(context),
      child: Column(
        children: [
          if (showSpinner)
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            )
          else
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 42),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
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

  Widget buildChatIntroCard(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: cardDecoration(context),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              gradient: PlanoraTheme.primaryGradientFor(context),
              borderRadius: BorderRadius.circular(22),
              boxShadow: PlanoraTheme.floatingShadowFor(context),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Ask Planora anything about this project.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'I can explain tasks, break work into steps, help when you’re stuck, and suggest what to do next.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark
                  ? PlanoraTheme.darkTextMuted
                  : PlanoraTheme.textSecondary,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSuggestionChips(BuildContext context) {
    final suggestions = chatSuggestions();
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = PlanoraTheme.isDark(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: suggestions.map((suggestion) {
        return ActionChip(
          onPressed: isSending ? null : () => sendSuggestion(suggestion),
          label: Text(suggestion),
          avatar: Icon(Icons.auto_awesome_rounded, size: 16, color: primary),
          backgroundColor: isDark
              ? primary.withValues(alpha: 0.14)
              : primary.withValues(alpha: 0.08),
          side: BorderSide(color: primary.withValues(alpha: 0.18)),
          labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: isDark ? PlanoraTheme.darkTextPrimary : primary,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }).toList(),
    );
  }

  Widget buildMessageBubble(
    BuildContext context,
    AiChatMessageModel message, {
    int index = 0,
  }) {
    final isAssistant = message.isAssistant;
    final isDark = PlanoraTheme.isDark(context);
    final bubbleText = cleanChatText(message.message);

    final bubble = Align(
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
              constraints: const BoxConstraints(maxWidth: 330),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  gradient: isAssistant
                      ? null
                      : PlanoraTheme.primaryGradientFor(context),
                  color: isAssistant
                      ? isDark
                            ? PlanoraTheme.darkSurface
                            : PlanoraTheme.surface
                      : null,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isAssistant ? 6 : 20),
                    bottomRight: Radius.circular(isAssistant ? 20 : 6),
                  ),
                  border: isAssistant
                      ? Border.all(
                          color: isDark
                              ? PlanoraTheme.darkBorder
                              : PlanoraTheme.border,
                        )
                      : null,
                  boxShadow: PlanoraTheme.cardShadowFor(context),
                ),
                child: Text(
                  bubbleText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isAssistant ? null : Colors.white,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return _AnimatedChatMessageEntry(
      key: ValueKey(
        '${message.messageId}-${message.createdAt.toIso8601String()}',
      ),
      index: index,
      isAssistant: isAssistant,
      child: bubble,
    );
  }

  Widget buildTypingIndicator(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
            ),
            boxShadow: PlanoraTheme.cardShadowFor(context),
          ),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  'Planora AI is typing',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mutedColor(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _AiTypingDots(color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildInlineError(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PlanoraTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: PlanoraTheme.error,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget buildComposer(BuildContext context) {
    final canSend = selectedProject != null && !isSending;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: cardDecoration(context),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: messageController,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => sendMessage(),
              decoration: const InputDecoration(
                hintText: 'Ask about this plan...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 46,
            height: 46,
            child: ElevatedButton(
              onPressed: canSend ? sendMessage : null,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
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
                  : const Icon(Icons.send_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRefreshableChat(BuildContext context) {
    final showComposer = projects.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () async {
        final project = selectedProject;
        if (project == null) {
          await loadProjects();
        } else {
          await loadMessages(project);
        }
      },
      child: ListView(
        controller: messagesScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: showComposer ? 106 : 12),
        children: [buildMessages(context)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      drawer: buildProjectDrawer(context),
      body: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  buildHeader(context),
                  const SizedBox(height: 16),
                  Expanded(child: buildRefreshableChat(context)),
                ],
              ),
            ),
            if (!isLoadingProjects && projects.isNotEmpty && isSending)
              Positioned(
                left: 0,
                right: 0,
                bottom: 92,
                child: buildTypingIndicator(context),
              ),
            if (!isLoadingProjects && projects.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 14,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: PlanoraTheme.floatingShadowFor(context),
                  ),
                  child: buildComposer(context),
                ),
              ),
          ],
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
      duration: Duration(milliseconds: 220 + (widget.index % 4) * 35),
    );

    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

    _offset = Tween<Offset>(
      begin: Offset(widget.isAssistant ? -0.05 : 0.05, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _scale = Tween<double>(
      begin: 0.98,
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
