import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/ai/data/ai_plan_api.dart';
import 'package:mobile/features/auth/data/project_api.dart';
import 'package:mobile/features/auth/models/auth_models.dart';
import 'package:mobile/features/auth/models/project_models.dart';
import 'package:mobile/features/home/home_screen.dart';
import 'package:mobile/features/notifications/data/notifications_api.dart';
import 'package:mobile/features/notifications/notifications_screen.dart';
import 'package:mobile/features/projects/ai_project_wizard_screen.dart';
import 'package:mobile/features/projects/data/project_insights_api.dart';
import 'package:mobile/features/projects/project_detail_screen.dart';
import 'package:mobile/features/reports/data/reports_api.dart';
import 'package:mobile/features/reports/reports_screen.dart';
import 'package:mobile/features/tasks/data/tasks_api.dart';
import 'package:mobile/features/tasks/models/task_models.dart';
import 'package:mobile/features/tasks/tasks_screen.dart';
import 'package:mobile/features/teams/data/teams_api.dart';
import 'package:mobile/features/teams/teams_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('AI preview screen renders generated tasks', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiPlanPreviewContent(
              project: _project(7, 'Clothing Business'),
              plan: _aiPlan([
                const AiGeneratedTask(
                  taskId: 1,
                  title: 'Research suppliers',
                  description: 'Compare manufacturers and sample costs.',
                  priority: 'high',
                  estimatedHours: 3,
                  status: 'todo',
                  dueDate: null,
                ),
              ]),
              onAccept: () {},
              onRegenerate: () {},
              onEditManually: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('AI Plan Preview'), findsOneWidget);
    expect(find.text('Research suppliers'), findsOneWidget);
    expect(find.text('Accept plan'), findsOneWidget);
  });

  testWidgets('Clothing business preview avoids software prompt leakage', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiPlanPreviewContent(
              project: _project(7, 'Clothing Business Online'),
              plan: _aiPlan([
                const AiGeneratedTask(
                  taskId: 1,
                  title: 'Define clothing niche and target customer',
                  description:
                      'Identify the clothing category, customer profile, style, price range, and reason buyers would choose the brand.',
                  priority: 'high',
                  estimatedHours: 2,
                  status: 'todo',
                  dueDate: null,
                ),
                const AiGeneratedTask(
                  taskId: 2,
                  title: 'Create social media content plan',
                  description:
                      'Plan Instagram/TikTok posts, product photos, launch messages, offers, and how customers will contact or order.',
                  priority: 'medium',
                  estimatedHours: 3,
                  status: 'todo',
                  dueDate: null,
                ),
              ]),
              onAccept: () {},
              onRegenerate: () {},
              onEditManually: () {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.text('Define clothing niche and target customer'),
      findsOneWidget,
    );
    expect(find.text('Create social media content plan'), findsOneWidget);
    expect(find.textContaining('Design the app architecture'), findsNothing);
    expect(
      find.textContaining('Create a complete Planora project plan'),
      findsNothing,
    );
    expect(find.textContaining('Available hours per week'), findsNothing);
  });

  testWidgets('Accepting a preview calls the accept action', (tester) async {
    var accepted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiPlanPreviewContent(
            project: _project(8, 'Launch Plan'),
            plan: _aiPlan(const []),
            onAccept: () {
              accepted = true;
            },
            onRegenerate: () {},
            onEditManually: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Accept plan'));

    expect(accepted, isTrue);
  });

  testWidgets('Project detail shows computed progress from tasks', (
    tester,
  ) async {
    final project = _project(11, 'Progress Plan');
    final tasks = [
      _taskItem(project, 1, 'Finished task', TaskStatus.completed),
      _taskItem(project, 2, 'Open task', TaskStatus.todo),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: ProjectDetailScreen(
          project: project,
          projectsApi: _ProjectDetailProjectsApi(project),
          tasksApi: _ProjectTasksApi(tasks),
          insightsApi: const _RiskPreviewApi(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Project Control Center'), findsOneWidget);
    expect(find.text('50%'), findsWidgets);
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('Project delete confirmation cancel does not call API', (
    tester,
  ) async {
    final project = _project(12, 'Delete Cancel Plan');
    final projectsApi = _MutableProjectDetailProjectsApi(project);

    await tester.pumpWidget(
      MaterialApp(
        home: ProjectDetailScreen(
          project: project,
          projectsApi: projectsApi,
          tasksApi: const _ProjectTasksApi([]),
          insightsApi: const _RiskPreviewApi(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.scrollUntilVisible(
      find.text('Danger Zone'),
      700,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Danger Zone'), findsOneWidget);
    await tester.tap(find.text('Delete project').last);
    await tester.pumpAndSettle();

    expect(find.text('Delete project?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(projectsApi.deleteCalls, 0);
  });

  testWidgets('Project delete success calls API', (tester) async {
    final project = _project(13, 'Delete Success Plan');
    final projectsApi = _MutableProjectDetailProjectsApi(project);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProjectDetailScreen(
                          project: project,
                          projectsApi: projectsApi,
                          tasksApi: const _ProjectTasksApi([]),
                          insightsApi: const _RiskPreviewApi(),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open project'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open project'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Danger Zone'),
      700,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete project').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(projectsApi.deleteCalls, 1);
    expect(find.text('Open project'), findsOneWidget);
  });

  testWidgets(
    'Personal project invite collaborator dialog validates and sends',
    (tester) async {
      final project = _project(14, 'Shared Personal Plan');
      final projectsApi = _MutableProjectDetailProjectsApi(project);

      await tester.pumpWidget(
        MaterialApp(
          home: ProjectDetailScreen(
            project: project,
            projectsApi: projectsApi,
            tasksApi: const _ProjectTasksApi([]),
            insightsApi: const _RiskPreviewApi(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.scrollUntilVisible(
        find.text('Collaborators'),
        700,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Collaborators'), findsOneWidget);
      await tester.tap(find.text('Invite collaborator').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invite collaborator').last);
      await tester.pump();

      expect(find.text('Enter an email or username.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'friend@example.com');
      await tester.tap(find.text('Invite collaborator').last);
      await tester.pumpAndSettle();

      expect(projectsApi.inviteCalls, 1);
      expect(projectsApi.lastInvite, 'friend@example.com');
    },
  );

  testWidgets('Notification tap resolves task route from type and IDs', (
    tester,
  ) async {
    NotificationNavigationTarget? target;
    final project = _project(21, 'Notification Plan');
    final notification = NotificationModel(
      notificationId: 1,
      userId: 1,
      title: 'Task updated',
      message: 'Open the task',
      isRead: false,
      type: 'task',
      createdAt: DateTime(2026, 6, 1),
      projectId: project.projectId,
      taskId: 91,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsScreen(
          notificationsApi: _SingleNotificationApi(notification),
          projectsApi: _ProjectListApi([project]),
          tasksApi: _ProjectTasksApi([
            _taskItem(project, 91, 'Open notification task', TaskStatus.todo),
          ]),
          onNavigateForTest: (value) {
            target = value;
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Task updated'));
    await tester.pumpAndSettle();

    expect(target?.kind, NotificationRouteKind.task);
    expect(target?.projectId, project.projectId);
    expect(target?.taskId, 91);

    expect(
      NotificationModel(
        notificationId: 2,
        userId: 1,
        title: 'Invite',
        message: 'Team invite',
        isRead: false,
        type: 'invite',
        createdAt: DateTime(2026, 6, 1),
        teamId: 4,
      ).navigationTarget.kind,
      NotificationRouteKind.team,
    );
  });

  testWidgets('Team screen shows role badges and workload summary', (
    tester,
  ) async {
    final project = _teamProject(31, 'Team Plan', teamId: 3);
    final member = TeamMemberModel(
      teamMemberId: 1,
      teamId: 3,
      userId: 7,
      role: 'admin',
      joinedAt: DateTime(2026, 6, 1),
      user: const UserSummaryModel(
        userId: 7,
        username: 'sara',
        email: 'sara@example.com',
        fullName: 'Sara Admin',
        profilePic: null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TeamsScreen(
          teamsApi: _TeamsFixtureApi(member),
          projectsApi: _TeamProjectsApi([project]),
          tasksApi: _ProjectTasksApi([
            _assignedTaskItem(project, 1, 7, TaskStatus.completed),
            _assignedTaskItem(project, 2, 7, TaskStatus.todo),
          ]),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Assigned'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('Home Teams quick action opens Teams screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          user: _user(),
          onThemeToggle: () {},
          onLoggedOut: () {},
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Teams'), findsWidgets);
    await tester.ensureVisible(find.text('Teams').first);
    await tester.tap(find.text('Teams').first);
    await tester.pumpAndSettle();

    expect(find.text('Teams'), findsWidgets);
    expect(find.byType(TeamsScreen), findsOneWidget);
  });

  testWidgets('Reports screen shows task and project summary', (tester) async {
    final project = _project(41, 'Report Plan');

    await tester.pumpWidget(
      MaterialApp(
        home: ReportsScreen(
          projectsApi: _ProjectListApi([project]),
          tasksApi: _TaskBoardApi([
            _taskItem(project, 1, 'Done report task', TaskStatus.completed),
            _taskItem(project, 2, 'Open report task', TaskStatus.todo),
          ]),
          reportsApi: _ReportFixtureApi(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Planora Insights'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Task Status'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -520));
    await tester.pumpAndSettle();
    expect(find.text('Project Report'), findsOneWidget);
  });

  testWidgets('Cached task data is shown when API load fails', (tester) async {
    final project = _project(51, 'Cached Plan');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TasksScreen(
            onBack: () {},
            tasksApi: _FailingCachedTasksApi(
              TaskBoardData(
                projects: [TaskProjectSummary.fromProject(project)],
                tasks: [
                  _taskItem(
                    project,
                    1,
                    'Cached supplier task',
                    TaskStatus.todo,
                  ),
                ],
                isFromCache: true,
                lastSyncedAt: DateTime(2026, 6, 1),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.textContaining('Could not connect. Showing last saved data.'),
      findsOneWidget,
    );
    expect(find.text('Cached supplier task'), findsOneWidget);
  });
}

AiPlanGenerateResponse _aiPlan(List<AiGeneratedTask> tasks) {
  return AiPlanGenerateResponse(
    projectId: 7,
    planId: 77,
    summary: 'Generated a practical plan.',
    tasksCreated: tasks.length,
    tasks: tasks,
  );
}

ProjectModel _project(int id, String title) {
  return ProjectModel(
    projectId: id,
    createdBy: 1,
    teamId: null,
    title: title,
    description: 'Demo project',
    deadline: DateTime(2026, 7, 1),
    status: 'in_progress',
    projectType: 'personal',
    createdAt: DateTime(2026, 6, 1),
    updatedAt: null,
  );
}

UserResponse _user() {
  return UserResponse(
    userId: 1,
    username: 'planora_user',
    email: 'planora@example.com',
    fullName: 'Planora User',
    role: 'user',
    isActive: true,
    isEmailVerified: true,
    profilePic: null,
    createdAt: DateTime(2026, 6, 1),
  );
}

ProjectModel _teamProject(int id, String title, {required int teamId}) {
  return ProjectModel(
    projectId: id,
    createdBy: 1,
    teamId: teamId,
    title: title,
    description: 'Team demo project',
    deadline: DateTime(2026, 7, 1),
    status: 'in_progress',
    projectType: 'team',
    createdAt: DateTime(2026, 6, 1),
    updatedAt: null,
  );
}

TaskListItem _taskItem(
  ProjectModel project,
  int taskId,
  String title,
  TaskStatus status,
) {
  return _taskFromSummary(
    TaskProjectSummary.fromProject(project),
    taskId,
    title,
    status,
    assignedTo: 1,
  );
}

TaskListItem _assignedTaskItem(
  ProjectModel project,
  int taskId,
  int userId,
  TaskStatus status,
) {
  return _taskFromSummary(
    TaskProjectSummary.fromProject(project),
    taskId,
    'Assigned task $taskId',
    status,
    assignedTo: userId,
  );
}

TaskListItem _taskFromSummary(
  TaskProjectSummary project,
  int taskId,
  String title,
  TaskStatus status, {
  required int assignedTo,
}) {
  return TaskListItem(
    project: project,
    task: TaskModel(
      taskId: taskId,
      projectId: project.projectId,
      assignedTo: assignedTo,
      assignedToName: 'Planora Tester',
      assignedToEmail: 'tester@example.com',
      assignedToAvatarUrl: null,
      members: const [],
      followers: const [],
      subtasks: const [],
      tags: const [],
      createdBy: 1,
      title: title,
      description: null,
      sectionName: null,
      priority: TaskPriority.medium,
      estimatedHours: 2,
      actualHours: null,
      status: status,
      startDate: null,
      dueDate: DateTime(2026, 6, 20),
      completedAt: status == TaskStatus.completed
          ? DateTime(2026, 6, 18)
          : null,
      createdAt: DateTime(2026, 6, 1, 12, taskId),
    ),
  );
}

class _ProjectDetailProjectsApi extends ProjectsApi {
  final ProjectModel project;

  const _ProjectDetailProjectsApi(this.project);

  @override
  Future<ProjectModel> getProject(ProjectModel project) async {
    return this.project;
  }

  @override
  Future<List<ProjectMemberModel>> getProjectMembers(
    ProjectModel project,
  ) async {
    return [];
  }
}

class _MutableProjectDetailProjectsApi extends ProjectsApi {
  final ProjectModel project;
  final List<ProjectMemberModel> members = [];
  int deleteCalls = 0;
  int inviteCalls = 0;
  String? lastInvite;

  _MutableProjectDetailProjectsApi(this.project);

  @override
  Future<ProjectModel> getProject(ProjectModel project) async {
    return this.project;
  }

  @override
  Future<List<ProjectMemberModel>> getProjectMembers(
    ProjectModel project,
  ) async {
    return members;
  }

  @override
  Future<ProjectMemberModel> inviteProjectMember({
    required ProjectModel project,
    required String emailOrUsername,
    String role = 'member',
  }) async {
    inviteCalls += 1;
    lastInvite = emailOrUsername;
    final member = ProjectMemberModel(
      memberId: inviteCalls,
      projectId: project.projectId,
      userId: 100 + inviteCalls,
      role: role,
      joinedAt: DateTime(2026, 6, 1),
      user: UserSummaryModel(
        userId: 100 + inviteCalls,
        username: emailOrUsername.split('@').first,
        email: emailOrUsername,
        fullName: 'Invited Collaborator',
        profilePic: null,
      ),
    );
    members.add(member);
    return member;
  }

  @override
  Future<void> deleteProject(ProjectModel project) async {
    deleteCalls += 1;
  }
}

class _ProjectListApi extends ProjectsApi {
  final List<ProjectModel> projects;

  const _ProjectListApi(this.projects);

  @override
  Future<List<ProjectModel>> getProjects() async {
    return projects;
  }

  @override
  Future<ProjectModel> getProjectById(int projectId) async {
    return projects.firstWhere((project) => project.projectId == projectId);
  }
}

class _TeamProjectsApi extends _ProjectListApi {
  const _TeamProjectsApi(super.projects);

  @override
  Future<List<ProjectModel>> getTeamProjects(int teamId) async {
    return projects.where((project) => project.teamId == teamId).toList();
  }
}

class _ProjectTasksApi extends TasksApi {
  final List<TaskListItem> tasks;

  const _ProjectTasksApi(this.tasks);

  @override
  Future<List<TaskListItem>> getProjectTasks({
    required TaskProjectSummary project,
    TaskStatus? status,
  }) async {
    return tasks
        .where((item) => item.project.projectId == project.projectId)
        .where((item) => status == null || item.task.status == status)
        .toList();
  }

  @override
  Future<TaskListItem> getTask({
    required TaskProjectSummary project,
    required int taskId,
  }) async {
    return tasks.firstWhere(
      (item) =>
          item.project.projectId == project.projectId &&
          item.task.taskId == taskId,
    );
  }
}

class _TaskBoardApi extends _ProjectTasksApi {
  const _TaskBoardApi(super.tasks);

  @override
  Future<TaskBoardData> getTasks({TaskStatus? status}) async {
    final filteredTasks = status == null
        ? tasks
        : tasks.where((item) => item.task.status == status).toList();
    final projects = {
      for (final item in tasks) item.project.projectId: item.project,
    }.values.toList();

    return TaskBoardData(projects: projects, tasks: filteredTasks);
  }
}

class _FailingCachedTasksApi extends TasksApi {
  final TaskBoardData cachedData;

  const _FailingCachedTasksApi(this.cachedData);

  @override
  Future<TaskBoardData> getTasks({TaskStatus? status}) async {
    throw const ApiException(message: 'Offline', statusCode: 503);
  }

  @override
  Future<TaskBoardData?> getCachedTasks() async {
    return cachedData;
  }
}

class _RiskPreviewApi extends ProjectInsightsApi {
  const _RiskPreviewApi();

  @override
  Future<RiskAnalysisPreviewModel> previewRisk(int projectId) async {
    return RiskAnalysisPreviewModel(
      projectId: projectId,
      riskLevel: 'low',
      predictedDelayDays: 0,
      reason: 'On track.',
      recommendation: 'Keep the current pace.',
      totalTasks: 2,
      completedTasks: 1,
      overdueTasks: 0,
      blockedTasks: 0,
      remainingEstimatedHours: 2,
      daysUntilDeadline: 20,
    );
  }
}

class _SingleNotificationApi extends NotificationsApi {
  final NotificationModel notification;

  const _SingleNotificationApi(this.notification);

  @override
  Future<List<NotificationModel>> getNotifications({
    bool unreadOnly = false,
  }) async {
    return [notification];
  }

  @override
  Future<NotificationModel> markAsRead(int notificationId) async {
    return NotificationModel(
      notificationId: notification.notificationId,
      userId: notification.userId,
      title: notification.title,
      message: notification.message,
      isRead: true,
      type: notification.type,
      createdAt: notification.createdAt,
      projectId: notification.projectId,
      taskId: notification.taskId,
      teamId: notification.teamId,
    );
  }
}

class _TeamsFixtureApi extends TeamsApi {
  final TeamMemberModel member;

  const _TeamsFixtureApi(this.member);

  @override
  Future<List<TeamModel>> getTeams() async {
    return [
      TeamModel(
        teamId: member.teamId,
        name: 'Demo Team',
        createdBy: 1,
        createdAt: DateTime(2026, 6, 1),
      ),
    ];
  }

  @override
  Future<List<TeamInvitationModel>> getMyInvitations() async {
    return [];
  }

  @override
  Future<List<TeamMemberModel>> getTeamMembers(int teamId) async {
    return [member];
  }
}

class _ReportFixtureApi extends ReportsApi {
  @override
  Future<ProjectReportModel> getProjectReport(int projectId) async {
    return const ProjectReportModel(
      generatedAt: null,
      totalTasks: 2,
      completedTasks: 1,
      pendingTasks: 1,
      overdueTasks: 0,
      completionPercentage: 50,
      statusCounts: {'todo': 1, 'completed': 1},
      priorityCounts: {'medium': 2},
      exportId: 1,
    );
  }

  @override
  Future<List<ReportExportModel>> getExportHistory({int? projectId}) async {
    return [];
  }
}
