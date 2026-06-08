import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../models/project_models.dart';

class ProjectsApi {
  const ProjectsApi();

  Future<List<ProjectModel>> getProjects() async {
    final personalProjects = await _parseProjectListResponse(
      ApiClient.get('/projects'),
    );

    final teams = await _safeGetTeams();

    final teamProjectGroups = await Future.wait(
      teams.map((team) async {
        try {
          return await getTeamProjects(team.teamId);
        } catch (error, stackTrace) {
          debugPrint(
            'Team projects load failed for team ${team.teamId}: $error',
          );
          debugPrintStack(stackTrace: stackTrace);
          return <ProjectModel>[];
        }
      }),
    );

    final teamProjects = teamProjectGroups.expand((group) => group).toList();

    return [...personalProjects, ...teamProjects]
      ..sort((first, second) => second.createdAt.compareTo(first.createdAt));
  }

  Future<List<TeamModel>> _safeGetTeams() async {
    try {
      return await getTeams();
    } catch (error, stackTrace) {
      debugPrint('Teams load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return <TeamModel>[];
    }
  }

  Future<List<TeamModel>> getTeams() async {
    final response = await ApiClient.get('/teams');

    if (response is! List) {
      return [];
    }

    return response
        .map((item) => TeamModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ProjectModel>> getTeamProjects(int teamId) async {
    return _parseProjectListResponse(ApiClient.get('/teams/$teamId/projects'));
  }

  Future<List<ProjectModel>> _parseProjectListResponse(
    Future<dynamic> request,
  ) async {
    final response = await request;

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

  Future<ProjectModel> getProject(ProjectModel project) async {
    final path = project.isTeamProject && project.teamId != null
        ? '/teams/${project.teamId}/projects/${project.projectId}'
        : '/projects/${project.projectId}';
    final response = await ApiClient.get(path);

    return ProjectModel.fromJson(response as Map<String, dynamic>);
  }

  Future<ProjectModel> getProjectById(int projectId) async {
    final response = await ApiClient.get('/projects/$projectId');

    return ProjectModel.fromJson(response as Map<String, dynamic>);
  }

  Future<List<ProjectMemberModel>> getProjectMembers(
    ProjectModel project,
  ) async {
    if (!project.isTeamProject || project.teamId == null) {
      return [];
    }

    final response = await ApiClient.get(
      '/teams/${project.teamId}/projects/${project.projectId}/members',
    );

    if (response is! List) {
      return [];
    }

    return response
        .map(
          (item) => ProjectMemberModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<ProjectMemberModel> inviteProjectMember({
    required ProjectModel project,
    required String emailOrUsername,
    String role = 'member',
  }) async {
    if (!project.isTeamProject || project.teamId == null) {
      throw StateError('Project member invites require a team project.');
    }

    final response = await ApiClient.postJson(
      '/teams/${project.teamId}/projects/${project.projectId}/members/invite',
      data: {'email_or_username': emailOrUsername, 'role': role},
    );

    return ProjectMemberModel.fromJson(response as Map<String, dynamic>);
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
