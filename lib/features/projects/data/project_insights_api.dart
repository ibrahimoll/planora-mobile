import '../../../core/network/api_client.dart';
import '../../auth/models/project_models.dart';

class ProjectInsightsApi {
  const ProjectInsightsApi();

  Future<RiskAnalysisPreviewModel> previewRisk(int projectId) async {
    final response = await ApiClient.get(
      '/projects/$projectId/risk-analysis/preview',
    );

    return RiskAnalysisPreviewModel.fromJson(response as Map<String, dynamic>);
  }

  Future<SmartSchedulePreviewModel> previewSmartSchedule({
    required ProjectModel project,
    double dailyCapacityHours = 4,
  }) async {
    final response = await ApiClient.postJson(
      _smartSchedulePath(project, preview: true),
      data: {
        'strategy': 'balanced',
        'daily_capacity_hours': dailyCapacityHours,
        'apply_schedule': false,
      },
    );

    return SmartSchedulePreviewModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> applySmartSchedule({
    required ProjectModel project,
    double dailyCapacityHours = 4,
  }) async {
    await ApiClient.postJson(
      _smartSchedulePath(project, preview: false),
      data: {
        'strategy': 'balanced',
        'daily_capacity_hours': dailyCapacityHours,
        'apply_schedule': true,
      },
    );
  }

  String _smartSchedulePath(ProjectModel project, {required bool preview}) {
    final suffix = preview ? '/preview' : '';

    if (project.isTeamProject && project.teamId != null) {
      return '/teams/${project.teamId}/projects/${project.projectId}/smart-schedules$suffix';
    }

    return '/projects/${project.projectId}/smart-schedules$suffix';
  }
}

class RiskAnalysisPreviewModel {
  final int projectId;
  final String riskLevel;
  final int predictedDelayDays;
  final String reason;
  final String recommendation;
  final int totalTasks;
  final int completedTasks;
  final int overdueTasks;
  final int blockedTasks;
  final double remainingEstimatedHours;
  final int daysUntilDeadline;

  const RiskAnalysisPreviewModel({
    required this.projectId,
    required this.riskLevel,
    required this.predictedDelayDays,
    required this.reason,
    required this.recommendation,
    required this.totalTasks,
    required this.completedTasks,
    required this.overdueTasks,
    required this.blockedTasks,
    required this.remainingEstimatedHours,
    required this.daysUntilDeadline,
  });

  factory RiskAnalysisPreviewModel.fromJson(Map<String, dynamic> json) {
    return RiskAnalysisPreviewModel(
      projectId: _parseInt(json['project_id']),
      riskLevel: json['risk_level'] as String? ?? 'medium',
      predictedDelayDays: _parseInt(json['predicted_delay_days']),
      reason: json['reason'] as String? ?? '',
      recommendation: json['recommendation'] as String? ?? '',
      totalTasks: _parseInt(json['total_tasks']),
      completedTasks: _parseInt(json['completed_tasks']),
      overdueTasks: _parseInt(json['overdue_tasks']),
      blockedTasks: _parseInt(json['blocked_tasks']),
      remainingEstimatedHours: _parseDouble(json['remaining_estimated_hours']),
      daysUntilDeadline: _parseInt(json['days_until_deadline']),
    );
  }
}

class SmartSchedulePreviewModel {
  final int projectId;
  final double dailyCapacityHours;
  final int totalTasks;
  final int schedulableTaskCount;
  final int completedTaskCount;
  final double estimatedTotalHours;
  final DateTime projectDeadline;
  final DateTime? firstSuggestedDueDate;
  final DateTime? lastSuggestedDueDate;
  final List<SmartScheduleTaskItemModel> tasks;
  final List<String> warnings;

  const SmartSchedulePreviewModel({
    required this.projectId,
    required this.dailyCapacityHours,
    required this.totalTasks,
    required this.schedulableTaskCount,
    required this.completedTaskCount,
    required this.estimatedTotalHours,
    required this.projectDeadline,
    required this.firstSuggestedDueDate,
    required this.lastSuggestedDueDate,
    required this.tasks,
    required this.warnings,
  });

  factory SmartSchedulePreviewModel.fromJson(Map<String, dynamic> json) {
    final tasks = json['tasks'] as List? ?? const [];
    final warnings = json['warnings'] as List? ?? const [];

    return SmartSchedulePreviewModel(
      projectId: _parseInt(json['project_id']),
      dailyCapacityHours: _parseDouble(json['daily_capacity_hours']),
      totalTasks: _parseInt(json['total_tasks']),
      schedulableTaskCount: _parseInt(json['schedulable_task_count']),
      completedTaskCount: _parseInt(json['completed_task_count']),
      estimatedTotalHours: _parseDouble(json['estimated_total_hours']),
      projectDeadline: _parseDateTime(json['project_deadline']),
      firstSuggestedDueDate: _parseOptionalDateTime(
        json['first_suggested_due_date'],
      ),
      lastSuggestedDueDate: _parseOptionalDateTime(
        json['last_suggested_due_date'],
      ),
      tasks: tasks
          .whereType<Map<String, dynamic>>()
          .map(SmartScheduleTaskItemModel.fromJson)
          .toList(),
      warnings: warnings.map((item) => item.toString()).toList(),
    );
  }
}

class SmartScheduleTaskItemModel {
  final int taskId;
  final String title;
  final String priority;
  final String status;
  final double estimatedHours;
  final DateTime? oldDueDate;
  final DateTime suggestedDueDate;
  final bool isAfterProjectDeadline;

  const SmartScheduleTaskItemModel({
    required this.taskId,
    required this.title,
    required this.priority,
    required this.status,
    required this.estimatedHours,
    required this.oldDueDate,
    required this.suggestedDueDate,
    required this.isAfterProjectDeadline,
  });

  factory SmartScheduleTaskItemModel.fromJson(Map<String, dynamic> json) {
    return SmartScheduleTaskItemModel(
      taskId: _parseInt(json['task_id']),
      title: json['title'] as String? ?? 'Untitled task',
      priority: json['priority'] as String? ?? 'medium',
      status: json['status'] as String? ?? 'todo',
      estimatedHours: _parseDouble(json['estimated_hours']),
      oldDueDate: _parseOptionalDateTime(json['old_due_date']),
      suggestedDueDate: _parseDateTime(json['suggested_due_date']),
      isAfterProjectDeadline: json['is_after_project_deadline'] == true,
    );
  }
}

int _parseInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.round();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _parseDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _parseDateTime(dynamic value) {
  return _parseOptionalDateTime(value) ?? DateTime.now();
}

DateTime? _parseOptionalDateTime(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal();
  }

  return null;
}
