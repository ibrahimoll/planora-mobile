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
}

class AiPlanGenerateResponse {
  final int projectId;
  final int planId;
  final String summary;
  final int tasksCreated;
  final List<AiGeneratedTask> tasks;

  const AiPlanGenerateResponse({
    required this.projectId,
    required this.planId,
    required this.summary,
    required this.tasksCreated,
    required this.tasks,
  });

  factory AiPlanGenerateResponse.fromJson(Map<String, dynamic> json) {
    final tasks = json['tasks'] as List? ?? [];

    return AiPlanGenerateResponse(
      projectId: json['project_id'] as int,
      planId: json['plan_id'] as int,
      summary: json['summary'] as String? ?? '',
      tasksCreated: json['tasks_created'] as int? ?? 0,
      tasks: tasks
          .map((item) => AiGeneratedTask.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
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
      taskId: json['task_id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      priority: json['priority'] as String,
      estimatedHours: _parseOptionalDouble(json['estimated_hours']),
      status: json['status'] as String,
      dueDate: _parseOptionalDate(json['due_date']),
    );
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
