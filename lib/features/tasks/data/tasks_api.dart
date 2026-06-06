import '../../../core/network/api_client.dart';
import '../../auth/data/project_api.dart';
import '../models/task_models.dart';

class TasksApi {
  const TasksApi();

  Future<TaskBoardData> getTasks({TaskStatus? status}) async {
    final projects = await const ProjectsApi().getProjects();
    final projectSummaries = projects
        .map(TaskProjectSummary.fromProject)
        .toList();

    final taskGroups = await Future.wait(
      projectSummaries.map(
        (project) => getProjectTasks(project: project, status: status),
      ),
    );

    final tasks = taskGroups.expand((group) => group).toList()
      ..sort(_compareTaskListItems);

    return TaskBoardData(projects: projectSummaries, tasks: tasks);
  }

  Future<List<TaskListItem>> getProjectTasks({
    required TaskProjectSummary project,
    TaskStatus? status,
  }) async {
    final response = await ApiClient.get(
      '/projects/${project.projectId}/tasks',
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
    final response = await ApiClient.get(
      '/projects/${project.projectId}/tasks/$taskId',
    );

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
      '/projects/${request.projectId}/tasks',
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
      '/projects/${project.projectId}/tasks/$taskId',
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

  int _compareTaskListItems(TaskListItem first, TaskListItem second) {
    final firstTask = first.task;
    final secondTask = second.task;

    final firstDue = firstTask.dueDate;
    final secondDue = secondTask.dueDate;

    if (firstDue == null && secondDue != null) {
      return 1;
    }

    if (firstDue != null && secondDue == null) {
      return -1;
    }

    if (firstDue != null && secondDue != null) {
      final dueComparison = firstDue.compareTo(secondDue);

      if (dueComparison != 0) {
        return dueComparison;
      }
    }

    return secondTask.createdAt.compareTo(firstTask.createdAt);
  }
}
