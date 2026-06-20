import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/local_cache_store.dart';
import '../../auth/data/project_api.dart';
import '../models/task_models.dart';

class TasksApi {
  final ProjectsApi _projectsApi;
  static const String _taskBoardCacheKey = 'task_board';

  const TasksApi([this._projectsApi = const ProjectsApi()]);

  String _tasksPath(TaskProjectSummary project) {
    if (project.isTeamProject && project.teamId != null) {
      return '/teams/${project.teamId}/projects/${project.projectId}/tasks';
    }

    return '/projects/${project.projectId}/tasks';
  }

  Future<TaskBoardData> getTasks({TaskStatus? status}) async {
    try {
      final projects = await _projectsApi.getProjects();
      final projectSummaries = projects
          .map(TaskProjectSummary.fromProject)
          .toList();

      final taskGroups = await Future.wait(
        projectSummaries.map((project) async {
          try {
            return await getProjectTasks(project: project, status: status);
          } catch (error, stackTrace) {
            debugPrint(
              'Task load failed for project ${project.projectId}: $error',
            );
            debugPrintStack(stackTrace: stackTrace);
            return <TaskListItem>[];
          }
        }),
      );

      final tasks = taskGroups.expand((group) => group).toList()
        ..sort(compareTaskItemsByDueDate);
      final data = TaskBoardData(
        projects: projectSummaries,
        tasks: tasks,
        lastSyncedAt: DateTime.now(),
      );

      await LocalCacheStore.writeJson(_taskBoardCacheKey, data.toJson());

      return data;
    } catch (_) {
      final cached = await getCachedTasks();

      if (cached != null) {
        return cached;
      }

      rethrow;
    }
  }

  Future<TaskBoardData?> getCachedTasks() async {
    final cached = await LocalCacheStore.readJson(_taskBoardCacheKey);

    if (cached?.data is! Map<String, dynamic>) {
      return null;
    }

    return TaskBoardData.fromJson(
      cached!.data as Map<String, dynamic>,
      lastSyncedAt: cached.syncedAt,
      isFromCache: true,
    );
  }

  Future<List<TaskListItem>> getProjectTasks({
    required TaskProjectSummary project,
    TaskStatus? status,
  }) async {
    try {
      final response = await ApiClient.get(
        _tasksPath(project),
        queryParameters: {if (status != null) 'status': status.value},
      );

      if (response is! List) {
        return [];
      }

      await LocalCacheStore.writeJson(_projectTasksCacheKey(project), response);

      return _parseProjectTasks(response, project);
    } catch (_) {
      final cached = await getCachedProjectTasks(project);

      if (cached != null) {
        return cached;
      }

      rethrow;
    }
  }

  Future<List<TaskListItem>?> getCachedProjectTasks(
    TaskProjectSummary project,
  ) async {
    final cached = await LocalCacheStore.readJson(
      _projectTasksCacheKey(project),
    );

    if (cached?.data is! List) {
      return null;
    }

    return _parseProjectTasks(cached!.data as List, project);
  }

  List<TaskListItem> _parseProjectTasks(
    List response,
    TaskProjectSummary project,
  ) {
    return response
        .map(
          (item) => TaskListItem(
            task: TaskModel.fromJson(item as Map<String, dynamic>),
            project: project,
          ),
        )
        .toList();
  }

  String _projectTasksCacheKey(TaskProjectSummary project) {
    return 'project_tasks_${project.projectType}_${project.teamId ?? 0}_${project.projectId}';
  }

  Future<TaskListItem> getTask({
    required TaskProjectSummary project,
    required int taskId,
  }) async {
    final response = await ApiClient.get('${_tasksPath(project)}/$taskId');

    return TaskListItem(
      task: TaskModel.fromJson(response as Map<String, dynamic>),
      project: project,
    );
  }

  Future<TaskListItem> createTask({
    required TaskCreateRequest request,
    required TaskProjectSummary project,
  }) async {
    final response = await ApiClient.postJson(
      _tasksPath(project),
      data: request.toJson(),
    );

    return TaskListItem(
      task: TaskModel.fromJson(response as Map<String, dynamic>),
      project: project,
    );
  }

  Future<TaskListItem> updateTask({
    required TaskProjectSummary project,
    required int taskId,
    required TaskUpdateRequest request,
  }) async {
    final response = await ApiClient.patchJson(
      '${_tasksPath(project)}/$taskId',
      data: request.toJson(),
    );

    return TaskListItem(
      task: TaskModel.fromJson(response as Map<String, dynamic>),
      project: project,
    );
  }

  Future<TaskListItem> markTaskCompleted({
    required TaskProjectSummary project,
    required int taskId,
  }) {
    return updateTask(
      project: project,
      taskId: taskId,
      request: const TaskUpdateRequest(status: TaskStatus.completed),
    );
  }

  Future<void> deleteTask({
    required TaskProjectSummary project,
    required int taskId,
  }) async {
    await ApiClient.delete('${_tasksPath(project)}/$taskId');
  }

  String _subtasksPath(TaskProjectSummary project, int taskId) {
    return '${_tasksPath(project)}/$taskId/subtasks';
  }

  Future<List<TaskSubtaskPreview>> getSubtasks({
    required TaskProjectSummary project,
    required int taskId,
  }) async {
    final response = await ApiClient.get(_subtasksPath(project, taskId));

    if (response is! List) {
      return [];
    }

    return response
        .map(TaskSubtaskPreview.fromJson)
        .whereType<TaskSubtaskPreview>()
        .toList();
  }

  Future<TaskSubtaskPreview> createSubtask({
    required TaskProjectSummary project,
    required int taskId,
    required String title,
  }) async {
    final response = await ApiClient.postJson(
      _subtasksPath(project, taskId),
      data: {'title': title},
    );
    return TaskSubtaskPreview.fromJson(response) ??
        (throw const FormatException('Invalid subtask response.'));
  }

  Future<TaskSubtaskPreview> updateSubtask({
    required TaskProjectSummary project,
    required int taskId,
    required int subtaskId,
    required String title,
  }) async {
    final response = await ApiClient.patchJson(
      '${_subtasksPath(project, taskId)}/$subtaskId',
      data: {'title': title},
    );
    return TaskSubtaskPreview.fromJson(response) ??
        (throw const FormatException('Invalid subtask response.'));
  }

  Future<TaskSubtaskPreview> setSubtaskCompleted({
    required TaskProjectSummary project,
    required int taskId,
    required int subtaskId,
    required bool isCompleted,
  }) async {
    final response = await ApiClient.patchJson(
      '${_subtasksPath(project, taskId)}/$subtaskId/complete',
      data: {'is_completed': isCompleted},
    );
    return TaskSubtaskPreview.fromJson(response) ??
        (throw const FormatException('Invalid subtask response.'));
  }

  Future<void> deleteSubtask({
    required TaskProjectSummary project,
    required int taskId,
    required int subtaskId,
  }) async {
    await ApiClient.delete('${_subtasksPath(project, taskId)}/$subtaskId');
  }

  Future<List<TaskAttachmentModel>> getTaskAttachments({
    required TaskProjectSummary project,
    required int taskId,
  }) async {
    final response = await ApiClient.get(
      '${_tasksPath(project)}/$taskId/attachments',
    );

    if (response is! List) {
      return [];
    }

    return response
        .map(
          (item) => TaskAttachmentModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<TaskAttachmentModel> uploadTaskAttachment({
    required TaskProjectSummary project,
    required int taskId,
    required String filePath,
    required String fileName,
  }) async {
    final response = await ApiClient.postMultipart(
      '${_tasksPath(project)}/$taskId/attachments',
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      }),
    );

    return TaskAttachmentModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteTaskAttachment({
    required TaskProjectSummary project,
    required int taskId,
    required int attachmentId,
  }) async {
    await ApiClient.delete(
      '${_tasksPath(project)}/$taskId/attachments/$attachmentId',
    );
  }

  Future<List<TaskCommentModel>> getTaskComments({
    required TaskProjectSummary project,
    required int taskId,
  }) async {
    final response = await ApiClient.get(
      '${_tasksPath(project)}/$taskId/comments',
    );

    if (response is! List) {
      return [];
    }

    return response
        .map((item) => TaskCommentModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<TaskCommentModel> createTaskComment({
    required TaskProjectSummary project,
    required int taskId,
    required String commentText,
  }) async {
    final response = await ApiClient.postJson(
      '${_tasksPath(project)}/$taskId/comments',
      data: {'comment_text': commentText},
    );

    return TaskCommentModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteTaskComment({
    required TaskProjectSummary project,
    required int taskId,
    required int commentId,
  }) async {
    await ApiClient.delete(
      '${_tasksPath(project)}/$taskId/comments/$commentId',
    );
  }
}
