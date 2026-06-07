import 'package:flutter/material.dart';

import '../../core/theme/planora_theme.dart';
import '../auth/data/project_api.dart';
import '../tasks/models/task_models.dart';
import 'data/ai_chat_api.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final ProjectsApi _projectsApi = const ProjectsApi();
  final AiChatApi _aiChatApi = const AiChatApi();
  final TextEditingController messageController = TextEditingController();

  bool isLoadingProjects = true;
  bool isLoadingMessages = false;
  bool isSending = false;
  String? errorMessage;
  TaskProjectSummary? selectedProject;
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
    super.dispose();
  }

  Future<void> loadProjects() async {
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
        projects = summaries;
        selectedProject = summaries.isEmpty ? null : summaries.first;
        isLoadingProjects = false;
      });

      if (summaries.isNotEmpty) {
        await loadMessages(summaries.first);
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Could not load projects for AI chat.';
        isLoadingProjects = false;
      });
    }
  }

  Future<void> loadMessages(TaskProjectSummary project) async {
    setState(() {
      isLoadingMessages = true;
      errorMessage = null;
    });

    try {
      final loadedMessages = await _aiChatApi.getHistory(project: project);

      if (!mounted) return;

      setState(() {
        messages = loadedMessages;
        isLoadingMessages = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        messages = [];
        errorMessage = 'Could not load AI chat history.';
        isLoadingMessages = false;
      });
    }
  }

  Future<void> changeProject(TaskProjectSummary? project) async {
    if (project == null) return;

    setState(() {
      selectedProject = project;
      messages = [];
    });

    await loadMessages(project);
  }

  Future<void> sendMessage() async {
    final project = selectedProject;
    final message = messageController.text.trim();

    if (project == null || message.isEmpty || isSending) {
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

    setState(() {
      isSending = true;
      errorMessage = null;
      messages = [...messages, optimisticMessage];
    });

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
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isSending = false;
        errorMessage = 'Could not send your message. Please try again.';
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

  Widget buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: PlanoraTheme.primaryGradientFor(context),
            borderRadius: BorderRadius.circular(18),
            boxShadow: PlanoraTheme.floatingShadowFor(context),
          ),
          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Planora AI',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                'Ask about project planning, risks, and next steps.',
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
      ],
    );
  }

  Widget buildProjectPicker(BuildContext context) {
    if (projects.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: cardDecoration(context),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TaskProjectSummary>(
          value: selectedProject,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          onChanged: isLoadingMessages ? null : changeProject,
          items: projects.map((project) {
            return DropdownMenuItem<TaskProjectSummary>(
              value: project,
              child: Text(
                project.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
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
        title: 'Create a project first',
        message:
            'Planora AI chats are scoped to a project so advice stays useful.',
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
      return buildStateCard(
        context,
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Start a planning chat',
        message:
            'Ask Planora AI to summarize risk, suggest tasks, or clarify priorities.',
      );
    }

    return Column(
      children: [
        for (final message in messages) ...[
          buildMessageBubble(context, message),
          const SizedBox(height: 10),
        ],
        if (errorMessage != null) buildInlineError(context, errorMessage!),
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

  Widget buildMessageBubble(BuildContext context, AiChatMessageModel message) {
    final isAssistant = message.isAssistant;
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = PlanoraTheme.isDark(context);

    return Align(
      alignment: isAssistant ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isAssistant
                ? isDark
                      ? PlanoraTheme.darkSurface
                      : PlanoraTheme.surface
                : primary,
            borderRadius: BorderRadius.circular(18),
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
            message.message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isAssistant ? null : Colors.white,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
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
                hintText: 'Ask Planora AI...',
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        buildHeader(context),
        const SizedBox(height: 16),
        buildProjectPicker(context),
        const SizedBox(height: 14),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              final project = selectedProject;
              if (project == null) {
                await loadProjects();
              } else {
                await loadMessages(project);
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 12),
              children: [buildMessages(context)],
            ),
          ),
        ),
        const SizedBox(height: 10),
        buildComposer(context),
        const SizedBox(height: 14),
      ],
    );
  }
}
