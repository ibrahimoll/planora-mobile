class ProductivityInsightsModel {
  final ProductivitySummaryModel summary;
  final WorkloadInsightModel workload;
  final List<ProjectInsightModel> projects;
  final List<String> recommendations;
  final DateTime? generatedAt;

  const ProductivityInsightsModel({
    required this.summary,
    required this.workload,
    required this.projects,
    required this.recommendations,
    required this.generatedAt,
  });

  factory ProductivityInsightsModel.fromJson(Map<String, dynamic> json) {
    return ProductivityInsightsModel(
      summary: ProductivitySummaryModel.fromJson(
        _asMap(json['summary']),
      ),
      workload: WorkloadInsightModel.fromJson(
        _asMap(json['workload']),
      ),
      projects: _asList(json['projects'])
          .whereType<Map>()
          .map((item) => ProjectInsightModel.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
      recommendations: _asList(json['recommendations'])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      generatedAt: _parseDate(json['generated_at']),
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  static List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    return const [];
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }
}

class ProductivitySummaryModel {
  final int totalProjects;
  final int activeProjects;
  final int completedProjects;
  final int totalTasks;
  final int assignedTasks;
  final int completedAssignedTasks;
  final int overdueAssignedTasks;
  final int blockedAssignedTasks;
  final double completionPercentage;

  const ProductivitySummaryModel({
    required this.totalProjects,
    required this.activeProjects,
    required this.completedProjects,
    required this.totalTasks,
    required this.assignedTasks,
    required this.completedAssignedTasks,
    required this.overdueAssignedTasks,
    required this.blockedAssignedTasks,
    required this.completionPercentage,
  });

  factory ProductivitySummaryModel.fromJson(Map<String, dynamic> json) {
    return ProductivitySummaryModel(
      totalProjects: _parseInt(json['total_projects']),
      activeProjects: _parseInt(json['active_projects']),
      completedProjects: _parseInt(json['completed_projects']),
      totalTasks: _parseInt(json['total_tasks']),
      assignedTasks: _parseInt(json['assigned_tasks']),
      completedAssignedTasks: _parseInt(json['completed_assigned_tasks']),
      overdueAssignedTasks: _parseInt(json['overdue_assigned_tasks']),
      blockedAssignedTasks: _parseInt(json['blocked_assigned_tasks']),
      completionPercentage: _parseDouble(json['completion_percentage']),
    );
  }
}

class WorkloadInsightModel {
  final int assignedIncompleteTasks;
  final double estimatedHoursRemaining;
  final int highPriorityOpenTasks;
  final bool overloaded;

  const WorkloadInsightModel({
    required this.assignedIncompleteTasks,
    required this.estimatedHoursRemaining,
    required this.highPriorityOpenTasks,
    required this.overloaded,
  });

  factory WorkloadInsightModel.fromJson(Map<String, dynamic> json) {
    return WorkloadInsightModel(
      assignedIncompleteTasks: _parseInt(json['assigned_incomplete_tasks']),
      estimatedHoursRemaining: _parseDouble(json['estimated_hours_remaining']),
      highPriorityOpenTasks: _parseInt(json['high_priority_open_tasks']),
      overloaded: json['overloaded'] == true,
    );
  }
}

class ProjectInsightModel {
  final int projectId;
  final String title;
  final String projectType;
  final String status;
  final DateTime? deadline;
  final int totalTasks;
  final int completedTasks;
  final int assignedTasks;
  final int overdueTasks;
  final int blockedTasks;
  final double completionPercentage;
  final String healthStatus;

  const ProjectInsightModel({
    required this.projectId,
    required this.title,
    required this.projectType,
    required this.status,
    required this.deadline,
    required this.totalTasks,
    required this.completedTasks,
    required this.assignedTasks,
    required this.overdueTasks,
    required this.blockedTasks,
    required this.completionPercentage,
    required this.healthStatus,
  });

  factory ProjectInsightModel.fromJson(Map<String, dynamic> json) {
    return ProjectInsightModel(
      projectId: _parseInt(json['project_id']),
      title: _parseString(json['title'], fallback: 'Untitled project'),
      projectType: _parseString(json['project_type']),
      status: _parseString(json['status']),
      deadline: _parseDate(json['deadline']),
      totalTasks: _parseInt(json['total_tasks']),
      completedTasks: _parseInt(json['completed_tasks']),
      assignedTasks: _parseInt(json['assigned_tasks']),
      overdueTasks: _parseInt(json['overdue_tasks']),
      blockedTasks: _parseInt(json['blocked_tasks']),
      completionPercentage: _parseDouble(json['completion_percentage']),
      healthStatus: _parseString(json['health_status']),
    );
  }
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _parseDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _parseString(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}
