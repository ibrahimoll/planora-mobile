import '../../../core/network/api_client.dart';
import '../models/project_models.dart';

class ProjectsApi {
  const ProjectsApi();

  Future<List<ProjectModel>> getProjects() async {
    final response = await ApiClient.get('/projects');

    if (response is List) {
      return response
          .map((item) => ProjectModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (response is Map<String, dynamic> && response['items'] is List) {
      final items = response['items'] as List;

      return items
          .map((item) => ProjectModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return [];
  }

  Future<ProjectModel> getProjectById(int projectId) async {
    final response = await ApiClient.get('/projects/$projectId');

    return ProjectModel.fromJson(response as Map<String, dynamic>);
  }

  Future<ProjectModel> createProject(ProjectCreateRequest request) async {
    final response = await ApiClient.postJson(
      '/projects',
      data: request.toJson(),
    );

    return ProjectModel.fromJson(response as Map<String, dynamic>);
  }

  Future<ProjectModel> updateProject({
    required int projectId,
    required ProjectUpdateRequest request,
  }) async {
    final response = await ApiClient.patchJson(
      '/projects/$projectId',
      data: request.toJson(),
    );

    return ProjectModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteProject(int projectId) async {
    await ApiClient.delete('/projects/$projectId');
  }
}
