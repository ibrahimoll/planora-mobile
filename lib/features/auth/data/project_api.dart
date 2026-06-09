import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/local_cache_store.dart';
import '../models/project_models.dart';

class ProjectsApi {
  static const String _projectsCacheKey = 'projects';
  static const String _teamsCacheKey = 'teams';

  const ProjectsApi();

  Future<List<ProjectModel>> getProjects() async {
    try {
      final personalProjects = await _parseProjectListResponse(
        ApiClient.get('/projects'),
      );
      List<TeamModel> teams = [];

      try {
        teams = await getTeams();
      } catch (error, stackTrace) {
        debugPrint('Team list load failed while loading projects: $error');
        debugPrintStack(stackTrace: stackTrace);
      }

      final teamProjectGroups = await Future.wait(
        teams.map((team) async {
          try {
            return await getTeamProjects(team.teamId);
          } catch (error, stackTrace) {
            debugPrint(
              'Team project load failed for team ${team.teamId}: $error',
            );
            debugPrintStack(stackTrace: stackTrace);
            return <ProjectModel>[];
          }
        }),
      );
      final teamProjects = teamProjectGroups.expand((group) => group).toList();
      final projects = [...personalProjects, ...teamProjects]
        ..sort((first, second) => second.createdAt.compareTo(first.createdAt));

      await LocalCacheStore.writeJson(
        _projectsCacheKey,
        projects.map((project) => project.toJson()).toList(),
      );

      return projects;
    } catch (_) {
      final cached = await getCachedProjects();

      if (cached.isNotEmpty) {
        return cached;
      }

      rethrow;
    }
  }

  Future<List<ProjectModel>> getCachedProjects() async {
    final cached = await LocalCacheStore.readJson(_projectsCacheKey);

    if (cached?.data is! List) {
      return [];
    }

    return (cached!.data as List)
        .whereType<Map<String, dynamic>>()
        .map(ProjectModel.fromJson)
        .toList();
  }

  Future<List<TeamModel>> getTeams() async {
    try {
      final response = await ApiClient.get('/teams');

      if (response is! List) {
        return [];
      }

      final teams = response
          .map((item) => TeamModel.fromJson(item as Map<String, dynamic>))
          .toList();

      await LocalCacheStore.writeJson(
        _teamsCacheKey,
        teams.map((team) => team.toJson()).toList(),
      );

      return teams;
    } catch (_) {
      final cached = await getCachedTeams();

      if (cached.isNotEmpty) {
        return cached;
      }

      rethrow;
    }
  }

  Future<List<TeamModel>> getCachedTeams() async {
    final cached = await LocalCacheStore.readJson(_teamsCacheKey);

    if (cached?.data is! List) {
      return [];
    }

    return (cached!.data as List)
        .whereType<Map<String, dynamic>>()
        .map(TeamModel.fromJson)
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
    final response = await ApiClient.get(_projectMembersPath(project));

    if (response is! List) {
      return [];
    }

    return response
        .map(
          (item) => ProjectMemberModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<ProjectMemberModel>> getProjectMembersByIds({
    required int teamId,
    required int projectId,
  }) async {
    final response = await ApiClient.get(
      '/teams/$teamId/projects/$projectId/members',
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
    final response = await ApiClient.postJson(
      '${_projectMembersPath(project)}/invite',
      data: {'email_or_username': emailOrUsername, 'role': role},
    );

    return ProjectMemberModel.fromJson(response as Map<String, dynamic>);
  }

  String _projectMembersPath(ProjectModel project) {
    if (project.isTeamProject && project.teamId != null) {
      return '/teams/${project.teamId}/projects/${project.projectId}/members';
    }

    return '/projects/${project.projectId}/members';
  }

  Future<ProjectModel> createProject(ProjectCreateRequest request) async {
    final response = await ApiClient.postJson(
      '/projects',
      data: request.toJson(),
    );

    return ProjectModel.fromJson(response as Map<String, dynamic>);
  }

  Future<ProjectModel> createTeamProject({
    required int teamId,
    required ProjectCreateRequest request,
  }) async {
    final response = await ApiClient.postJson(
      '/teams/$teamId/projects',
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

  Future<void> deleteProject(ProjectModel project) async {
    final path = project.isTeamProject && project.teamId != null
        ? '/teams/${project.teamId}/projects/${project.projectId}'
        : '/projects/${project.projectId}';

    await ApiClient.delete(path);
  }
}
