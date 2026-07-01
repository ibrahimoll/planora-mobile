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

  Future<ProjectProgressModel> getProjectProgress(int projectId) async {
    final response = await ApiClient.get('/projects/$projectId/progress');

    return ProjectProgressModel.fromJson(response as Map<String, dynamic>);
  }

  Future<List<ProjectActivityModel>> getProjectActivity({
    required int projectId,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await ApiClient.get(
      '/projects/$projectId/activity',
      queryParameters: {'limit': limit, 'offset': offset},
    );

    if (response is! List) {
      return [];
    }

    return response
        .whereType<Map<String, dynamic>>()
        .map(ProjectActivityModel.fromJson)
        .toList();
  }

  Future<ProjectReportModel> generateProjectReport(int projectId) async {
    final response = await ApiClient.get('/reports/projects/$projectId');

    return ProjectReportModel.fromJson(response as Map<String, dynamic>);
  }

  Future<ReportExportHistoryPage> getMyReportExports({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await ApiClient.get(
      '/reports/exports',
      queryParameters: {'limit': limit, 'offset': offset},
    );

    return ReportExportHistoryPage.fromJson(response as Map<String, dynamic>);
  }

  Future<ReportExportHistoryPage> getProjectReportExports({
    required int projectId,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await ApiClient.get(
      '/reports/projects/$projectId/exports',
      queryParameters: {'limit': limit, 'offset': offset},
    );

    return ReportExportHistoryPage.fromJson(response as Map<String, dynamic>);
  }

  Future<List<AiPlanHistoryModel>> getAiPlanHistory(ProjectModel project) async {
    final path = project.isTeamProject && project.teamId != null
        ? '/teams/${project.teamId}/projects/${project.projectId}/ai-plans'
        : '/projects/${project.projectId}/ai-plans';
    final response = await ApiClient.get(path);

    if (response is! List) {
      return [];
    }

    return response
        .whereType<Map<String, dynamic>>()
        .map(AiPlanHistoryModel.fromJson)
        .toList();
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

class ProjectProgressModel {
  final ProjectProgressSummaryModel project;
  final ProgressTaskStatusCountsModel taskStatusCounts;
  final ProgressHoursSummaryModel hours;
  final UserProgressItemModel currentUserProgress;
  final List<UserProgressItemModel> members;
  final List<String> recommendations;
  final DateTime generatedAt;

  const ProjectProgressModel({
    required this.project,
    required this.taskStatusCounts,
    required this.hours,
    required this.currentUserProgress,
    required this.members,
    required this.recommendations,
    required this.generatedAt,
  });

  factory ProjectProgressModel.fromJson(Map<String, dynamic> json) {
    final members = json['members'] as List? ?? const [];
    final recommendations = json['recommendations'] as List? ?? const [];

    return ProjectProgressModel(
      project: ProjectProgressSummaryModel.fromJson(
        _map(json['project']),
      ),
      taskStatusCounts: ProgressTaskStatusCountsModel.fromJson(
        _map(json['task_status_counts']),
      ),
      hours: ProgressHoursSummaryModel.fromJson(_map(json['hours'])),
      currentUserProgress: UserProgressItemModel.fromJson(
        _map(json['current_user_progress']),
      ),
      members: members
          .whereType<Map<String, dynamic>>()
          .map(UserProgressItemModel.fromJson)
          .toList(),
      recommendations: recommendations.map((item) => item.toString()).toList(),
      generatedAt: _parseDateTime(json['generated_at']),
    );
  }
}

class ProjectProgressSummaryModel {
  final int projectId;
  final String title;
  final String projectType;
  final String status;
  final DateTime deadline;
  final int totalTasks;
  final int completedTasks;
  final int pendingTasks;
  final int overdueTasks;
  final double completionPercentage;
  final String productivityStatus;

  const ProjectProgressSummaryModel({
    required this.projectId,
    required this.title,
    required this.projectType,
    required this.status,
    required this.deadline,
    required this.totalTasks,
    required this.completedTasks,
    required this.pendingTasks,
    required this.overdueTasks,
    required this.completionPercentage,
    required this.productivityStatus,
  });

  factory ProjectProgressSummaryModel.fromJson(Map<String, dynamic> json) {
    return ProjectProgressSummaryModel(
      projectId: _parseInt(json['project_id']),
      title: json['title'] as String? ?? 'Untitled project',
      projectType: json['project_type'] as String? ?? 'personal',
      status: json['status'] as String? ?? 'not_started',
      deadline: _parseDateTime(json['deadline']),
      totalTasks: _parseInt(json['total_tasks']),
      completedTasks: _parseInt(json['completed_tasks']),
      pendingTasks: _parseInt(json['pending_tasks']),
      overdueTasks: _parseInt(json['overdue_tasks']),
      completionPercentage: _parseDouble(json['completion_percentage']),
      productivityStatus:
          json['productivity_status'] as String? ?? 'needs_attention',
    );
  }
}

class ProgressTaskStatusCountsModel {
  final int todo;
  final int inProgress;
  final int completed;
  final int blocked;

  const ProgressTaskStatusCountsModel({
    required this.todo,
    required this.inProgress,
    required this.completed,
    required this.blocked,
  });

  factory ProgressTaskStatusCountsModel.fromJson(Map<String, dynamic> json) {
    return ProgressTaskStatusCountsModel(
      todo: _parseInt(json['todo']),
      inProgress: _parseInt(json['in_progress']),
      completed: _parseInt(json['completed']),
      blocked: _parseInt(json['blocked']),
    );
  }
}

class ProgressHoursSummaryModel {
  final double estimatedHoursTotal;
  final double actualHoursTotal;
  final double remainingEstimatedHours;

  const ProgressHoursSummaryModel({
    required this.estimatedHoursTotal,
    required this.actualHoursTotal,
    required this.remainingEstimatedHours,
  });

  factory ProgressHoursSummaryModel.fromJson(Map<String, dynamic> json) {
    return ProgressHoursSummaryModel(
      estimatedHoursTotal: _parseDouble(json['estimated_hours_total']),
      actualHoursTotal: _parseDouble(json['actual_hours_total']),
      remainingEstimatedHours: _parseDouble(json['remaining_estimated_hours']),
    );
  }
}

class UserProgressItemModel {
  final int userId;
  final String username;
  final String fullName;
  final String role;
  final int tasksCompleted;
  final int tasksTotal;
  final double completionPercentage;

  const UserProgressItemModel({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.role,
    required this.tasksCompleted,
    required this.tasksTotal,
    required this.completionPercentage,
  });

  factory UserProgressItemModel.fromJson(Map<String, dynamic> json) {
    return UserProgressItemModel(
      userId: _parseInt(json['user_id']),
      username: json['username'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
      tasksCompleted: _parseInt(json['tasks_completed']),
      tasksTotal: _parseInt(json['tasks_total']),
      completionPercentage: _parseDouble(json['completion_percentage']),
    );
  }

  String get displayName {
    final name = fullName.trim();
    if (name.isNotEmpty) return name;
    final user = username.trim();
    return user.isEmpty ? 'Unknown user' : user;
  }
}

class ProjectActivityModel {
  final int activityId;
  final int projectId;
  final int? taskId;
  final int? actorId;
  final String eventType;
  final String? actorUsernameSnapshot;
  final String? actorFullNameSnapshot;
  final String? taskTitleSnapshot;
  final String message;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const ProjectActivityModel({
    required this.activityId,
    required this.projectId,
    required this.taskId,
    required this.actorId,
    required this.eventType,
    required this.actorUsernameSnapshot,
    required this.actorFullNameSnapshot,
    required this.taskTitleSnapshot,
    required this.message,
    required this.metadata,
    required this.createdAt,
  });

  factory ProjectActivityModel.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'];

    return ProjectActivityModel(
      activityId: _parseInt(json['activity_id']),
      projectId: _parseInt(json['project_id']),
      taskId: _parseOptionalInt(json['task_id']),
      actorId: _parseOptionalInt(json['actor_id']),
      eventType: json['event_type'] as String? ?? 'activity',
      actorUsernameSnapshot: json['actor_username_snapshot'] as String?,
      actorFullNameSnapshot: json['actor_full_name_snapshot'] as String?,
      taskTitleSnapshot: json['task_title_snapshot'] as String?,
      message: json['message'] as String? ?? '',
      metadata: metadata is Map<String, dynamic> ? metadata : null,
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  String get actorLabel {
    final name = actorFullNameSnapshot?.trim();
    if (name != null && name.isNotEmpty) return name;
    final username = actorUsernameSnapshot?.trim();
    if (username != null && username.isNotEmpty) return username;
    return 'Planora';
  }
}

class ProjectReportModel {
  final DateTime generatedAt;
  final ReportProjectSummaryModel project;
  final ReportProgressSummaryModel progress;
  final ProgressTaskStatusCountsModel taskStatusCounts;
  final ReportTaskPriorityCountsModel taskPriorityCounts;
  final ReportHoursSummaryModel hours;
  final ReportActivitySummaryModel activity;
  final List<ReportMemberItemModel> members;
  final List<ReportTaskItemModel> tasks;
  final int? exportId;

  const ProjectReportModel({
    required this.generatedAt,
    required this.project,
    required this.progress,
    required this.taskStatusCounts,
    required this.taskPriorityCounts,
    required this.hours,
    required this.activity,
    required this.members,
    required this.tasks,
    required this.exportId,
  });

  factory ProjectReportModel.fromJson(Map<String, dynamic> json) {
    final members = json['members'] as List? ?? const [];
    final tasks = json['tasks'] as List? ?? const [];

    return ProjectReportModel(
      generatedAt: _parseDateTime(json['generated_at']),
      project: ReportProjectSummaryModel.fromJson(_map(json['project'])),
      progress: ReportProgressSummaryModel.fromJson(_map(json['progress'])),
      taskStatusCounts: ProgressTaskStatusCountsModel.fromJson(
        _map(json['task_status_counts']),
      ),
      taskPriorityCounts: ReportTaskPriorityCountsModel.fromJson(
        _map(json['task_priority_counts']),
      ),
      hours: ReportHoursSummaryModel.fromJson(_map(json['hours'])),
      activity: ReportActivitySummaryModel.fromJson(_map(json['activity'])),
      members: members
          .whereType<Map<String, dynamic>>()
          .map(ReportMemberItemModel.fromJson)
          .toList(),
      tasks: tasks
          .whereType<Map<String, dynamic>>()
          .map(ReportTaskItemModel.fromJson)
          .toList(),
      exportId: _parseOptionalInt(json['export_id']),
    );
  }
}

class ReportProjectSummaryModel {
  final int projectId;
  final String title;
  final String? description;
  final String status;
  final String projectType;
  final DateTime deadline;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ReportProjectSummaryModel({
    required this.projectId,
    required this.title,
    required this.description,
    required this.status,
    required this.projectType,
    required this.deadline,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReportProjectSummaryModel.fromJson(Map<String, dynamic> json) {
    return ReportProjectSummaryModel(
      projectId: _parseInt(json['project_id']),
      title: json['title'] as String? ?? 'Untitled project',
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'not_started',
      projectType: json['project_type'] as String? ?? 'personal',
      deadline: _parseDateTime(json['deadline']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseOptionalDateTime(json['updated_at']),
    );
  }
}

class ReportProgressSummaryModel {
  final int totalTasks;
  final int completedTasks;
  final int pendingTasks;
  final int overdueTasks;
  final double completionPercentage;

  const ReportProgressSummaryModel({
    required this.totalTasks,
    required this.completedTasks,
    required this.pendingTasks,
    required this.overdueTasks,
    required this.completionPercentage,
  });

  factory ReportProgressSummaryModel.fromJson(Map<String, dynamic> json) {
    return ReportProgressSummaryModel(
      totalTasks: _parseInt(json['total_tasks']),
      completedTasks: _parseInt(json['completed_tasks']),
      pendingTasks: _parseInt(json['pending_tasks']),
      overdueTasks: _parseInt(json['overdue_tasks']),
      completionPercentage: _parseDouble(json['completion_percentage']),
    );
  }
}

class ReportTaskPriorityCountsModel {
  final int low;
  final int medium;
  final int high;

  const ReportTaskPriorityCountsModel({
    required this.low,
    required this.medium,
    required this.high,
  });

  factory ReportTaskPriorityCountsModel.fromJson(Map<String, dynamic> json) {
    return ReportTaskPriorityCountsModel(
      low: _parseInt(json['low']),
      medium: _parseInt(json['medium']),
      high: _parseInt(json['high']),
    );
  }
}

class ReportHoursSummaryModel {
  final double estimatedHoursTotal;
  final double actualHoursTotal;

  const ReportHoursSummaryModel({
    required this.estimatedHoursTotal,
    required this.actualHoursTotal,
  });

  factory ReportHoursSummaryModel.fromJson(Map<String, dynamic> json) {
    return ReportHoursSummaryModel(
      estimatedHoursTotal: _parseDouble(json['estimated_hours_total']),
      actualHoursTotal: _parseDouble(json['actual_hours_total']),
    );
  }
}

class ReportActivitySummaryModel {
  final int commentsCount;
  final int attachmentsCount;
  final int deadlineRemindersCount;

  const ReportActivitySummaryModel({
    required this.commentsCount,
    required this.attachmentsCount,
    required this.deadlineRemindersCount,
  });

  factory ReportActivitySummaryModel.fromJson(Map<String, dynamic> json) {
    return ReportActivitySummaryModel(
      commentsCount: _parseInt(json['comments_count']),
      attachmentsCount: _parseInt(json['attachments_count']),
      deadlineRemindersCount: _parseInt(json['deadline_reminders_count']),
    );
  }
}

class ReportMemberItemModel {
  final int userId;
  final String username;
  final String email;
  final String fullName;
  final String role;

  const ReportMemberItemModel({
    required this.userId,
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
  });

  factory ReportMemberItemModel.fromJson(Map<String, dynamic> json) {
    return ReportMemberItemModel(
      userId: _parseInt(json['user_id']),
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
    );
  }
}

class ReportTaskItemModel {
  final int taskId;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final int? assignedTo;
  final double? estimatedHours;
  final double? actualHours;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final DateTime createdAt;

  const ReportTaskItemModel({
    required this.taskId,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.assignedTo,
    required this.estimatedHours,
    required this.actualHours,
    required this.dueDate,
    required this.completedAt,
    required this.createdAt,
  });

  factory ReportTaskItemModel.fromJson(Map<String, dynamic> json) {
    return ReportTaskItemModel(
      taskId: _parseInt(json['task_id']),
      title: json['title'] as String? ?? 'Untitled task',
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'todo',
      priority: json['priority'] as String? ?? 'medium',
      assignedTo: _parseOptionalInt(json['assigned_to']),
      estimatedHours: _parseOptionalDouble(json['estimated_hours']),
      actualHours: _parseOptionalDouble(json['actual_hours']),
      dueDate: _parseOptionalDateTime(json['due_date']),
      completedAt: _parseOptionalDateTime(json['completed_at']),
      createdAt: _parseDateTime(json['created_at']),
    );
  }
}

class ReportExportHistoryPage {
  final List<ReportExportHistoryItemModel> items;
  final int total;
  final int limit;
  final int offset;

  const ReportExportHistoryPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory ReportExportHistoryPage.fromJson(Map<String, dynamic> json) {
    final items = json['items'] as List? ?? const [];

    return ReportExportHistoryPage(
      items: items
          .whereType<Map<String, dynamic>>()
          .map(ReportExportHistoryItemModel.fromJson)
          .toList(),
      total: _parseInt(json['total']),
      limit: _parseInt(json['limit']),
      offset: _parseInt(json['offset']),
    );
  }
}

class ReportExportHistoryItemModel {
  final int reportExportId;
  final int projectId;
  final int? exportedBy;
  final String reportType;
  final String exportFormat;
  final String projectTitleSnapshot;
  final String projectStatusSnapshot;
  final String projectTypeSnapshot;
  final int taskCountSnapshot;
  final double completionPercentageSnapshot;
  final String? exportedByUsernameSnapshot;
  final String? exportedByFullNameSnapshot;
  final DateTime createdAt;

  const ReportExportHistoryItemModel({
    required this.reportExportId,
    required this.projectId,
    required this.exportedBy,
    required this.reportType,
    required this.exportFormat,
    required this.projectTitleSnapshot,
    required this.projectStatusSnapshot,
    required this.projectTypeSnapshot,
    required this.taskCountSnapshot,
    required this.completionPercentageSnapshot,
    required this.exportedByUsernameSnapshot,
    required this.exportedByFullNameSnapshot,
    required this.createdAt,
  });

  factory ReportExportHistoryItemModel.fromJson(Map<String, dynamic> json) {
    return ReportExportHistoryItemModel(
      reportExportId: _parseInt(json['report_export_id']),
      projectId: _parseInt(json['project_id']),
      exportedBy: _parseOptionalInt(json['exported_by']),
      reportType: json['report_type'] as String? ?? 'project',
      exportFormat: json['export_format'] as String? ?? 'json',
      projectTitleSnapshot: json['project_title_snapshot'] as String? ?? '',
      projectStatusSnapshot: json['project_status_snapshot'] as String? ?? '',
      projectTypeSnapshot: json['project_type_snapshot'] as String? ?? '',
      taskCountSnapshot: _parseInt(json['task_count_snapshot']),
      completionPercentageSnapshot:
          _parseDouble(json['completion_percentage_snapshot']),
      exportedByUsernameSnapshot:
          json['exported_by_username_snapshot'] as String?,
      exportedByFullNameSnapshot:
          json['exported_by_full_name_snapshot'] as String?,
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  String get exportedByLabel {
    final name = exportedByFullNameSnapshot?.trim();
    if (name != null && name.isNotEmpty) return name;
    final username = exportedByUsernameSnapshot?.trim();
    if (username != null && username.isNotEmpty) return username;
    return 'Unknown user';
  }
}

class AiPlanHistoryModel {
  final int planId;
  final int projectId;
  final int? generatedBy;
  final String inputPrompt;
  final Map<String, dynamic> generatedPlan;
  final DateTime createdAt;

  const AiPlanHistoryModel({
    required this.planId,
    required this.projectId,
    required this.generatedBy,
    required this.inputPrompt,
    required this.generatedPlan,
    required this.createdAt,
  });

  factory AiPlanHistoryModel.fromJson(Map<String, dynamic> json) {
    final generatedPlan = json['generated_plan'];

    return AiPlanHistoryModel(
      planId: _parseInt(json['plan_id']),
      projectId: _parseInt(json['project_id']),
      generatedBy: _parseOptionalInt(json['generated_by']),
      inputPrompt: json['input_prompt'] as String? ?? '',
      generatedPlan:
          generatedPlan is Map<String, dynamic> ? generatedPlan : const {},
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  String get summary {
    final candidates = [
      generatedPlan['summary'],
      generatedPlan['overview'],
      generatedPlan['description'],
    ];

    for (final item in candidates) {
      if (item is String && item.trim().isNotEmpty) {
        return item.trim();
      }
    }

    return inputPrompt.trim().isEmpty
        ? 'AI plan generated for this project.'
        : inputPrompt.trim();
  }

  int get generatedTaskCount {
    final tasks = generatedPlan['tasks'];
    return tasks is List ? tasks.length : 0;
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

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
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

int? _parseOptionalInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value.toString());
}

double _parseDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _parseOptionalDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
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
