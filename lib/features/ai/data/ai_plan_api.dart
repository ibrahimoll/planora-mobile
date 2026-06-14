import '../../../core/network/api_client.dart';
import '../../auth/models/project_models.dart';

class AiPlanApi {
  const AiPlanApi();

  String _path(ProjectModel project) {
    if (project.isTeamProject && project.teamId != null) {
      return '/teams/${project.teamId}/projects/${project.projectId}/ai-plan/generate';
    }

    return '/projects/${project.projectId}/ai-plan/generate';
  }

  Future<AiPlanGenerateResponse> generatePlan({
    required ProjectModel project,
    required String prompt,
    bool generateTasks = true,
    bool overwriteExistingTasks = false,
    int preferredTaskCount = 8,
    bool includeMilestones = true,
  }) async {
    final response = await ApiClient.postJson(
      _path(project),
      data: {
        'prompt': prompt,
        'generate_tasks': generateTasks,
        'overwrite_existing_tasks': overwriteExistingTasks,
        'preferred_task_count': preferredTaskCount,
        'include_milestones': includeMilestones,
      },
    );

    return AiPlanGenerateResponse.fromJson(response as Map<String, dynamic>);
  }

  Future<AiPlanPreviewResponse> previewFromIdea({
    required String projectIdea,
    required DateTime deadline,
    required String projectType,
    int? teamId,
    int availableHoursPerWeek = 8,
    int preferredTaskCount = 8,
    String? requirements,
    bool includeMilestones = true,
  }) async {
    final trimmedRequirements = requirements?.trim();
    final data = <String, dynamic>{
      'project_idea': projectIdea,
      'deadline': deadline.toIso8601String(),
      'project_type': projectType,
      'available_hours_per_week': availableHoursPerWeek,
      'preferred_task_count': preferredTaskCount,
      'include_milestones': includeMilestones,
    };

    if (teamId != null) {
      data['team_id'] = teamId;
    }

    if (trimmedRequirements != null && trimmedRequirements.isNotEmpty) {
      data['requirements'] = trimmedRequirements;
    }

    final response = await ApiClient.postJson(
      '/ai-plans/preview-from-idea',
      data: data,
    );

    return AiPlanPreviewResponse.fromJson(response as Map<String, dynamic>);
  }

  Future<AiPlanAcceptPreviewResponse> acceptPreview(
    AiPlanPreviewResponse preview,
  ) async {
    final response = await ApiClient.postJson(
      '/ai-plans/accept-preview',
      data: {'preview': preview.toJson()},
    );

    return AiPlanAcceptPreviewResponse.fromJson(
      response as Map<String, dynamic>,
    );
  }
}

class AiPlanGenerateResponse {
  final int projectId;
  final int planId;
  final bool success;
  final String message;
  final String summary;
  final int tasksCreated;
  final int tasksSkippedAsDuplicates;
  final int rejectedGenericCount;
  final int rejectedUnrelatedCount;
  final String aiGenerationStatus;
  final String? improvementSummary;
  final List<AiGeneratedTask> tasks;

  const AiPlanGenerateResponse({
    required this.projectId,
    required this.planId,
    required this.success,
    required this.message,
    required this.summary,
    required this.tasksCreated,
    required this.tasksSkippedAsDuplicates,
    required this.rejectedGenericCount,
    required this.rejectedUnrelatedCount,
    required this.aiGenerationStatus,
    required this.improvementSummary,
    required this.tasks,
  });

  factory AiPlanGenerateResponse.fromJson(Map<String, dynamic> json) {
    final tasks = json['tasks'] as List? ?? [];

    return AiPlanGenerateResponse(
      projectId: _parseInt(json['project_id']),
      planId: _parseInt(json['plan_id']),
      success: _parseBool(json['success'], fallback: true),
      message: json['message'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      tasksCreated: _parseInt(json['tasks_created'], fallback: 0),
      tasksSkippedAsDuplicates: _parseInt(
        json['tasks_skipped_as_duplicates'],
        fallback: 0,
      ),
      rejectedGenericCount: _parseInt(
        json['rejected_generic_count'],
        fallback: 0,
      ),
      rejectedUnrelatedCount: _parseInt(
        json['rejected_unrelated_count'],
        fallback: 0,
      ),
      aiGenerationStatus:
          json['ai_generation_status'] as String? ?? 'generated',
      improvementSummary: json['improvement_summary'] as String?,
      tasks: tasks
          .map((item) => AiGeneratedTask.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static bool _parseBool(dynamic value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }

    final normalized = value?.toString().toLowerCase().trim();

    if (normalized == 'true') {
      return true;
    }

    if (normalized == 'false') {
      return false;
    }

    return fallback;
  }
}

class AiGeneratedTask {
  final int taskId;
  final String title;
  final String? description;
  final String priority;
  final double? estimatedHours;
  final String status;
  final DateTime? dueDate;

  const AiGeneratedTask({
    required this.taskId,
    required this.title,
    required this.description,
    required this.priority,
    required this.estimatedHours,
    required this.status,
    required this.dueDate,
  });

  factory AiGeneratedTask.fromJson(Map<String, dynamic> json) {
    return AiGeneratedTask(
      taskId: _parseInt(json['task_id']),
      title: json['title'] as String? ?? 'Untitled task',
      description: json['description'] as String?,
      priority: json['priority'] as String? ?? 'medium',
      estimatedHours: _parseOptionalDouble(json['estimated_hours']),
      status: json['status'] as String? ?? 'todo',
      dueDate: _parseOptionalDate(json['due_date']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'suggested_order': taskId == 0 ? null : taskId,
      'task_id': taskId,
      'title': title,
      'description': description,
      'priority': priority,
      'estimated_hours': estimatedHours,
      'status': status,
      'due_date': dueDate?.toIso8601String(),
    };
  }

  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double? _parseOptionalDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  static DateTime? _parseOptionalDate(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.parse(value).toLocal();
    }

    return null;
  }
}

class AiPlanPreviewResponse {
  final bool success;
  final String message;
  final String aiGenerationStatus;
  final String source;
  final String domain;
  final String projectTitle;
  final String? description;
  final String projectType;
  final int? teamId;
  final DateTime deadline;
  final String summary;
  final List<AiGeneratedTask> tasks;
  final List<Map<String, dynamic>> milestones;
  final List<Map<String, String>> risks;
  final List<String> recommendations;
  final String projectIdea;
  final String? requirements;
  final int availableHoursPerWeek;
  final int preferredTaskCount;
  final int rejectedGenericCount;
  final int rejectedUnrelatedCount;

  const AiPlanPreviewResponse({
    required this.success,
    required this.message,
    required this.aiGenerationStatus,
    required this.source,
    required this.domain,
    required this.projectTitle,
    required this.description,
    required this.projectType,
    required this.teamId,
    required this.deadline,
    required this.summary,
    required this.tasks,
    required this.milestones,
    required this.risks,
    required this.recommendations,
    required this.projectIdea,
    required this.requirements,
    required this.availableHoursPerWeek,
    required this.preferredTaskCount,
    required this.rejectedGenericCount,
    required this.rejectedUnrelatedCount,
  });

  factory AiPlanPreviewResponse.fromJson(Map<String, dynamic> json) {
    final tasks = json['tasks'] as List? ?? [];
    final milestones = json['milestones'] as List? ?? [];
    final risks = json['risks'] as List? ?? [];
    final recommendations = json['recommendations'] as List? ?? [];

    return AiPlanPreviewResponse(
      success: _parseBool(json['success'], fallback: true),
      message: json['message'] as String? ?? '',
      aiGenerationStatus:
          json['ai_generation_status'] as String? ?? 'generated',
      source: json['source'] as String? ?? 'ai_provider',
      domain: json['domain'] as String? ?? 'general',
      projectTitle: json['project_title'] as String? ?? 'AI Generated Plan',
      description: json['description'] as String?,
      projectType: json['project_type'] as String? ?? 'personal',
      teamId: _parseOptionalInt(json['team_id']),
      deadline: DateTime.parse(json['deadline'] as String).toLocal(),
      summary: json['summary'] as String? ?? '',
      tasks: tasks
          .map((item) => AiGeneratedTask.fromJson(item as Map<String, dynamic>))
          .toList(),
      milestones: milestones
          .whereType<Map<String, dynamic>>()
          .map(Map<String, dynamic>.from)
          .toList(),
      risks: risks
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => item.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ),
          )
          .toList(),
      recommendations: recommendations
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      projectIdea: json['project_idea'] as String? ?? '',
      requirements: json['requirements'] as String?,
      availableHoursPerWeek: _parseInt(
        json['available_hours_per_week'],
        fallback: 8,
      ),
      preferredTaskCount: _parseInt(
        json['preferred_task_count'],
        fallback: tasks.length,
      ),
      rejectedGenericCount: _parseInt(
        json['rejected_generic_count'],
        fallback: 0,
      ),
      rejectedUnrelatedCount: _parseInt(
        json['rejected_unrelated_count'],
        fallback: 0,
      ),
    );
  }

  ProjectModel toPreviewProject() {
    final now = DateTime.now();

    return ProjectModel(
      projectId: 0,
      createdBy: 0,
      teamId: teamId,
      title: projectTitle,
      description: description,
      deadline: deadline,
      status: 'not_started',
      projectType: projectType,
      createdAt: now,
      updatedAt: now,
    );
  }

  AiPlanGenerateResponse toGenerateResponse() {
    return AiPlanGenerateResponse(
      projectId: 0,
      planId: 0,
      success: success,
      message: message,
      summary: summary,
      tasksCreated: tasks.length,
      tasksSkippedAsDuplicates: 0,
      rejectedGenericCount: rejectedGenericCount,
      rejectedUnrelatedCount: rejectedUnrelatedCount,
      aiGenerationStatus: aiGenerationStatus,
      improvementSummary: summary,
      tasks: tasks,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'ai_generation_status': aiGenerationStatus,
      'source': source,
      'domain': domain,
      'project_title': projectTitle,
      'description': description,
      'project_type': projectType,
      'team_id': teamId,
      'deadline': deadline.toIso8601String(),
      'summary': summary,
      'tasks': [
        for (var index = 0; index < tasks.length; index++)
          {
            'suggested_order': index + 1,
            'title': tasks[index].title,
            'description': tasks[index].description,
            'priority': tasks[index].priority,
            'estimated_hours': tasks[index].estimatedHours,
            'status': tasks[index].status,
            'due_date': tasks[index].dueDate?.toIso8601String(),
          },
      ],
      'milestones': milestones,
      'risks': risks,
      'recommendations': recommendations,
      'project_idea': projectIdea,
      'requirements': requirements,
      'available_hours_per_week': availableHoursPerWeek,
      'preferred_task_count': preferredTaskCount,
      'rejected_generic_count': rejectedGenericCount,
      'rejected_unrelated_count': rejectedUnrelatedCount,
    };
  }

  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static bool _parseBool(dynamic value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }

    final normalized = value?.toString().toLowerCase().trim();

    if (normalized == 'true') {
      return true;
    }

    if (normalized == 'false') {
      return false;
    }

    return fallback;
  }

  static int? _parseOptionalInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }
}

class AiPlanAcceptPreviewResponse {
  final ProjectModel project;
  final AiPlanGenerateResponse plan;

  const AiPlanAcceptPreviewResponse({
    required this.project,
    required this.plan,
  });

  factory AiPlanAcceptPreviewResponse.fromJson(Map<String, dynamic> json) {
    return AiPlanAcceptPreviewResponse(
      project: ProjectModel.fromJson(json['project'] as Map<String, dynamic>),
      plan: AiPlanGenerateResponse.fromJson(json),
    );
  }
}
