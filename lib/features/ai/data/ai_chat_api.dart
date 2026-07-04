import '../../../core/network/api_client.dart';
import '../../tasks/models/task_models.dart';

class AiChatApi {
  const AiChatApi();

  String _chatPath(TaskProjectSummary project) {
    if (project.isTeamProject && project.teamId != null) {
      return '/teams/${project.teamId}/projects/${project.projectId}/chat';
    }

    return '/projects/${project.projectId}/chat';
  }

  Future<List<AiChatMessageModel>> getHistory({
    required TaskProjectSummary project,
  }) async {
    final response = await ApiClient.get(
      _chatPath(project),
      queryParameters: {'limit': 50, 'offset': 0},
    );

    if (response is Map<String, dynamic> && response['messages'] is List) {
      final messages = response['messages'] as List;

      return _parseMessages(messages);
    }

    if (response is List) {
      return _parseMessages(response);
    }

    return [];
  }

  Future<AiChatSendResult> sendMessage({
    required TaskProjectSummary project,
    required String message,
  }) async {
    final response = await ApiClient.postJson(
      _chatPath(project),
      data: {'message': message},
    );

    if (response is! Map<String, dynamic>) {
      return AiChatSendResult(
        message: AiChatMessageModel.localAssistant(
          projectId: project.projectId,
          message:
              'Planora AI received your message, but the server response was incomplete.',
        ),
        suggestions: const [],
      );
    }

    final aiMessageData = response['ai_message'] ?? response['message'];

    final aiMessage = aiMessageData is Map<String, dynamic>
        ? AiChatMessageModel.fromJson(aiMessageData)
        : AiChatMessageModel.fromJson(response);

    return AiChatSendResult(
      message: aiMessage,
      suggestions: _parseSuggestions(response['assistant_context']),
    );
  }

  List<String> _parseSuggestions(dynamic context) {
    if (context is! Map<String, dynamic>) {
      return const [];
    }

    final rawSuggestions = context['suggested_prompts'];

    if (rawSuggestions is! List) {
      return const [];
    }

    return rawSuggestions
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .take(4)
        .toList();
  }

  Future<int> deleteHistory({required TaskProjectSummary project}) async {
    final response = await ApiClient.delete(_chatPath(project));

    if (response is Map<String, dynamic>) {
      final count = response['deleted_count'];

      if (count is int) return count;
      if (count is num) return count.toInt();
      if (count is String) return int.tryParse(count) ?? 0;
    }

    return 0;
  }

  List<AiChatMessageModel> _parseMessages(List<dynamic> messages) {
    return messages
        .whereType<Map<String, dynamic>>()
        .map(AiChatMessageModel.fromJson)
        .toList();
  }
}

class AiChatSendResult {
  final AiChatMessageModel message;
  final List<String> suggestions;

  const AiChatSendResult({required this.message, required this.suggestions});
}

class AiChatMessageModel {
  final int messageId;
  final int? senderId;
  final int? projectId;
  final String message;
  final String senderType;
  final DateTime createdAt;

  const AiChatMessageModel({
    required this.messageId,
    required this.senderId,
    required this.projectId,
    required this.message,
    required this.senderType,
    required this.createdAt,
  });

  factory AiChatMessageModel.fromJson(Map<String, dynamic> json) {
    return AiChatMessageModel(
      messageId: _parseInt(json['message_id'] ?? json['id']) ?? 0,
      senderId: _parseInt(json['sender_id'] ?? json['user_id']),
      projectId: _parseInt(json['project_id']),
      message:
          _firstNonEmptyString([
            json['message'],
            json['body'],
            json['content'],
            json['text'],
          ]) ??
          '',
      senderType:
          _firstNonEmptyString([
            json['sender_type'],
            json['role'],
            json['type'],
          ]) ??
          'assistant',
      createdAt:
          _parseDateTime(json['created_at'] ?? json['timestamp']) ??
          DateTime.now(),
    );
  }

  factory AiChatMessageModel.localAssistant({
    int? projectId,
    required String message,
  }) {
    return AiChatMessageModel(
      messageId: -DateTime.now().microsecondsSinceEpoch,
      senderId: null,
      projectId: projectId,
      message: message,
      senderType: 'assistant',
      createdAt: DateTime.now(),
    );
  }

  bool get isAssistant {
    return senderType == 'assistant' || senderType == 'ai';
  }

  static int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value.trim());
    }

    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }

    return null;
  }

  static String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return null;
  }
}
