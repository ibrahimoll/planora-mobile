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

      return messages
          .map(
            (item) => AiChatMessageModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }

    return [];
  }

  Future<AiChatMessageModel> sendMessage({
    required TaskProjectSummary project,
    required String message,
  }) async {
    final response = await ApiClient.postJson(
      _chatPath(project),
      data: {'message': message},
    );

    final data = response as Map<String, dynamic>;

    return AiChatMessageModel.fromJson(
      data['ai_message'] as Map<String, dynamic>,
    );
  }
}

class AiChatMessageModel {
  final int messageId;
  final int? senderId;
  final int projectId;
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
      messageId: json['message_id'] as int,
      senderId: json['sender_id'] as int?,
      projectId: json['project_id'] as int,
      message: json['message'] as String,
      senderType: json['sender_type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  bool get isAssistant {
    return senderType == 'assistant' || senderType == 'ai';
  }
}
