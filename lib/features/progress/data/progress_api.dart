import '../../../core/network/api_client.dart';

class ProgressApi {
  const ProgressApi();

  Future<ProjectProgressModel> getProjectProgress(int projectId) async {
    final data = await ApiClient.get('/projects/$projectId/progress');
    return ProjectProgressModel.fromJson(data as Map<String, dynamic>);
  }
}

class ProjectProgressModel {
  final int projectId;
  final int tasksCompleted;
  final int tasksTotal;
  final double completionPercentage;

