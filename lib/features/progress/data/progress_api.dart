import '../../../core/network/api_client.dart';

class ProgressApi {
  const ProgressApi();

  Future<ProjectProgressModel> getProjectProgress(int projectId) async {
    final response = await ApiClient.get('/projects/$projectId/progress');
    return ProjectProgressModel.fromJson(response as Map<String, dynamic>);
  }
}

class ProjectProgressModel {
  final int projectId;
  final int tasksCompleted;
  final int tasksTotal;
  final double completionPercentage;
  final DateTime? updated