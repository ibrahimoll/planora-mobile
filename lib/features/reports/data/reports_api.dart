import '../../../core/network/api_client.dart';

class ReportsApi {
  const ReportsApi();

  Future<ProjectReportModel> getProjectReport(int projectId) async {
    final response = await ApiClient.get('/reports/projects/$projectId');

    if (response is Map<String, dynamic>) {
      return ProjectReportModel.fromJson(response);
    }

    return const ProjectReportModel.empty();
  }

  Future<List<ReportExportModel>> getExportHistory({int? projectId}) async {
    final path = projectId == null
        ? '/reports/exports'
        : '/reports/projects/$projectId/exports';
    final response = await ApiClient.get(path);
    final items = response is Map<String, dynamic> && response['items'] is List
        ? response['items'] as List
        : response is List
        ? response
        : const [];

    return items
        .whereType<Map<String, dynamic>>()
        .map(ReportExportModel.fromJson)
        .toList();
  }
}

class ProjectReportModel {
  final DateTime? generatedAt;
  final int totalTasks;
  final int completedTasks;
  final int pendingTasks;
  final int overdueTasks;
  final double completionPercentage;
  final Map<String, int> statusCounts;
  final Map<String, int> priorityCounts;
  final int? exportId;

  const ProjectReportModel({
    required this.generatedAt,
    required this.totalTasks,
    required this.completedTasks,
    required this.pendingTasks,
    required this.overdueTasks,
    required this.completionPercentage,
    required this.statusCounts,
    required this.priorityCounts,
    required this.exportId,
  });

  const ProjectReportModel.empty()
    : generatedAt = null,
      totalTasks = 0,
      completedTasks = 0,
      pendingTasks = 0,
      overdueTasks = 0,
      completionPercentage = 0,
      statusCounts = const {},
      priorityCounts = const {},
      exportId = null;

  factory ProjectReportModel.fromJson(Map<String, dynamic> json) {
    final progress = json['progress'];
    final progressMap = progress is Map<String, dynamic> ? progress : json;

    return ProjectReportModel(
      generatedAt: _parseOptionalDateTime(json['generated_at']),
      totalTasks: _parseInt(progressMap['total_tasks']),
      completedTasks: _parseInt(progressMap['completed_tasks']),
      pendingTasks: _parseInt(progressMap['pending_tasks']),
      overdueTasks: _parseInt(progressMap['overdue_tasks']),
      completionPercentage: _parseDouble(progressMap['completion_percentage']),
      statusCounts: _parseIntMap(json['task_status_counts']),
      priorityCounts: _parseIntMap(json['task_priority_counts']),
      exportId: _parseOptionalInt(json['export_id']),
    );
  }
}

class ReportExportModel {
  final int exportId;
  final int? projectId;
  final String reportType;
  final String exportFormat;
  final DateTime createdAt;

  const ReportExportModel({
    required this.exportId,
    required this.projectId,
    required this.reportType,
    required this.exportFormat,
    required this.createdAt,
  });

  factory ReportExportModel.fromJson(Map<String, dynamic> json) {
    return ReportExportModel(
      exportId: _parseInt(json['report_export_id'] ?? json['export_id']),
      projectId: _parseOptionalInt(json['project_id']),
      reportType: json['report_type'] as String? ?? 'project',
      exportFormat: json['export_format'] as String? ?? 'json',
      createdAt: _parseOptionalDateTime(json['created_at']) ?? DateTime.now(),
    );
  }
}

Map<String, int> _parseIntMap(dynamic value) {
  if (value is! Map<String, dynamic>) {
    return const {};
  }

  return value.map((key, item) => MapEntry(key, _parseInt(item)));
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
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  return int.tryParse(value.toString());
}

double _parseDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _parseOptionalDateTime(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal();
  }

  return null;
}
