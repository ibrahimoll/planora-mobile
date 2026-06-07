import '../../../core/network/api_client.dart';
import '../../auth/data/project_api.dart';
import '../models/task_models.dart';

class TasksApi {
  final ProjectsApi _projectsApi;

  const TasksApi([this._projectsApi = const ProjectsApi()]);

  String _tasksPath(TaskProjectSummary project) {
    if (project.isTeamProject && project.teamId != null) {
      return '/teams/${project.teamId}/projects/${project.projectId}/tasks';
    }

    return '/projects/${project.projectId}/tasks';
  }

  Future<TaskBoardData> getTasks({TaskStatus? status}) async {
    final projects = await _projectsApi.getProjects();
    final projectSummaries = projects
        .map(TaskProjectSummary.fromProject)
        .toList();

    final taskGroups = await Future.wait(
      projectSummaries.map(
        (project) => getProjectTasks(project: project, status: status),
      ),
    );

    final tasks = taskGroups.expand((group) => group).toList()
      ..sort(compareTaskItemsByDueDate);

    return TaskBoardData(projects: projectSummaries, tasks: tasks);
  }

  Future<List<TaskListItem>> getProjectTasks({
    required TaskProjectSummary project,
    TaskStatus? status,
  }) async {
    final response = await ApiClient.get(
      _tasksPath(project),
      queryParameters: {if (status != null) 'status': status.value},
    );

    if (response is! List) {
      return [];
    }

    return response
        .map(
          (item) => TaskListItem(
            task: TaskModel.fromJson(item as Map<String, dynamic>),
            project: project,
          ),
        )
        .toList();
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
}
