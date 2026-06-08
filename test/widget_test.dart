import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/ai/ai_chat_screen.dart';
import 'package:mobile/features/ai/data/ai_chat_api.dart';
import 'package:mobile/features/ai/data/ai_plan_api.dart';
import 'package:mobile/features/auth/data/project_api.dart';
import 'package:mobile/features/auth/models/project_models.dart';
import 'package:mobile/features/home/widgets/home_bottom_nav.dart';
import 'package:mobile/main.dart';
import 'package:mobile/features/tasks/data/tasks_api.dart';
import 'package:mobile/features/tasks/models/task_models.dart';
import 'package:mobile/features/tasks/tasks_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('Planora app starts on the onboarding flow', (tester) async {
    await tester.pumpWidget(const PlanoraApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('Tasks bottom nav item opens the tasks tab index', (
    tester,
  ) async {
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: HomeBottomNav(
            selectedIndex: 0,
            onTap: (index) {
              tappedIndex = index;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tasks'));

    expect(tappedIndex, 3);
  });

  testWidgets('TasksScreen filters tasks by selected project and All Plans', (
    tester,
  ) async {
    final clothing = _taskProject(7, 'Clothing Brand');
    final app = _taskProject(9, 'Mobile App');
    final tasksApi = _ProjectFirstTasksApi(
      projects: [clothing, app],
      tasks: [
        _taskItem(
          project: clothing,
          taskId: 71,
          title: 'Compare clothing suppliers',
          status: TaskStatus.todo,
        ),
        _taskItem(
          project: app,
          taskId: 91,
          title: 'Design app onboarding',
          status: TaskStatus.todo,
        ),
        _taskItem(
          project: app,
          taskId: 92,
          title: 'Prepare app release notes',
          status: TaskStatus.completed,
        ),
      ],
    );

    await _pumpTasksScreen(tester, tasksApi);

    expect(find.text('Compare clothing suppliers'), findsOneWidget);
    expect(find.text('Design app onboarding'), findsNothing);

    await tester.tap(find.text('Mobile App').first);
    await tester.pumpAndSettle();

    expect(find.text('Design app onboarding'), findsOneWidget);
    expect(find.text('Compare clothing suppliers'), findsNothing);

    await tester.tap(find.text('Done').first);
    await tester.pumpAndSettle();

    expect(find.text('Prepare app release notes'), findsOneWidget);
    expect(find.text('Design app onboarding'), findsNothing);

    await tester.tap(find.text('All Plans'));
    await tester.pumpAndSettle();

    expect(find.text('Prepare app release notes'), findsOneWidget);
    expect(find.text('Compare clothing suppliers'), findsNothing);

    await tester.tap(find.text('All Tasks'));
    await tester.pumpAndSettle();

    expect(find.text('Compare clothing suppliers'), findsOneWidget);
    expect(find.text('Design app onboarding'), findsOneWidget);
  });

  testWidgets('TasksScreen creates a task for the selected project', (
    tester,
  ) async {
    final clothing = _taskProject(17, 'Clothing Brand');
    final launch = _taskProject(19, 'Launch Plan');
    final tasksApi = _ProjectFirstTasksApi(
      projects: [clothing, launch],
      tasks: [
        _taskItem(
          project: clothing,
          taskId: 171,
          title: 'Research fashion niche',
          status: TaskStatus.todo,
        ),
      ],
    );

    await _pumpTasksScreen(tester, tasksApi);
    await tester.tap(find.text('Launch Plan').first);
    await tester.pumpAndSettle();

    expect(find.text('No tasks for this project yet.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Launch Plan'), findsWidgets);
    expect(find.text('Tags (Optional)'), findsNothing);

    await tester.enterText(
      find.byType(TextField).at(1),
      'Schedule launch content',
    );
    await tester.ensureVisible(find.text('Create Task'));
    await tester.tap(find.text('Create Task'));
    await tester.pumpAndSettle();

    expect(find.text('Schedule launch content'), findsOneWidget);
    expect(find.text('Research fashion niche'), findsNothing);

    await tester.tap(find.text('Clothing Brand').first);
    await tester.pumpAndSettle();

    expect(find.text('Research fashion niche'), findsOneWidget);
    expect(find.text('Schedule launch content'), findsNothing);

    await tester.tap(find.text('Launch Plan').first);
    await tester.pumpAndSettle();

    expect(find.text('Schedule launch content'), findsOneWidget);
  });

  testWidgets('TasksScreen searches inside the selected project scope', (
    tester,
  ) async {
    final clothing = _taskProject(27, 'Clothing Brand');
    final app = _taskProject(29, 'Mobile App');
    final tasksApi = _ProjectFirstTasksApi(
      projects: [clothing, app],
      tasks: [
        _taskItem(
          project: clothing,
          taskId: 271,
          title: 'Research clothing suppliers',
          description: 'Compare fabric vendors and sample costs.',
          status: TaskStatus.todo,
        ),
        _taskItem(
          project: clothing,
          taskId: 272,
          title: 'Plan launch campaign',
          description: 'Prepare TikTok and Instagram content.',
          status: TaskStatus.todo,
        ),
        _taskItem(
          project: app,
          taskId: 291,
          title: 'Supplier admin dashboard',
          description: 'Software task in another plan.',
          status: TaskStatus.todo,
        ),
      ],
    );

    await _pumpTasksScreen(tester, tasksApi);

    await tester.enterText(find.byType(TextField).first, 'supplier');
    await tester.pumpAndSettle();

    expect(find.text('Research clothing suppliers'), findsOneWidget);
    expect(find.text('Plan launch campaign'), findsNothing);
    expect(find.text('Supplier admin dashboard'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'instagram');
    await tester.pumpAndSettle();

    expect(find.text('Plan launch campaign'), findsOneWidget);
    expect(find.text('Research clothing suppliers'), findsNothing);
  });

  testWidgets('TasksScreen renders loading, error, and no-project states', (
    tester,
  ) async {
    final delayedApi = _DelayedTasksApi();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TasksScreen(onBack: () {}, tasksApi: delayedApi),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Tasks'), findsOneWidget);

    delayedApi.complete();
    await tester.pumpAndSettle();

    await _pumpTasksScreen(tester, _FailingTasksApi());
    await tester.pumpAndSettle();
    expect(find.text('Could not load tasks'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);

    await _pumpTasksScreen(
      tester,
      _ProjectFirstTasksApi(projects: const [], tasks: const []),
    );

    expect(find.text('No projects yet'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
  });

  test('ProjectCreateRequest only serializes backend fields', () {
    final deadline = DateTime(2026, 6, 9, 12);
    final request = ProjectCreateRequest(
      title: 'Test Project',
      description: null,
      deadline: deadline,
    );

    expect(request.toJson(), {
      'title': 'Test Project',
      'description': null,
      'deadline': deadline.toIso8601String(),
    });
    expect(request.toJson().containsKey('project_type'), isFalse);
    expect(request.toJson().containsKey('team_id'), isFalse);
    expect(request.toJson().containsKey('color'), isFalse);
    expect(request.toJson().containsKey('generateTasksWithAi'), isFalse);
  });

  test('AI plan generation response parses backend task payloads', () {
    final response = AiPlanGenerateResponse.fromJson({
      'project_id': '7',
      'plan_id': '11',
      'summary': 'Generated a structured plan.',
      'tasks_created': '1',
      'tasks': [
        {
          'task_id': '21',
          'title': 'Define scope and success criteria',
          'description': 'Clarify the project goals.',
          'priority': 'high',
          'estimated_hours': 2,
          'status': 'todo',
          'due_date': '2026-06-20T10:00:00Z',
        },
      ],
    });

    expect(response.projectId, 7);
    expect(response.planId, 11);
    expect(response.tasksCreated, 1);
    expect(response.tasks.single.taskId, 21);
    expect(response.tasks.single.priority, 'high');
    expect(response.tasks.single.dueDate, isNotNull);
  });

  test('AI chat message parser tolerates partial backend payloads', () {
    final message = AiChatMessageModel.fromJson({
      'message_id': '42',
      'sender_id': null,
      'project_id': '7',
      'body': null,
      'sender_type': 'assistant',
      'created_at': 'not-a-date',
    });

    expect(message.messageId, 42);
    expect(message.senderId, isNull);
    expect(message.projectId, 7);
    expect(message.message, '');
    expect(message.isAssistant, isTrue);
    expect(message.createdAt, isA<DateTime>());
  });

  testWidgets('AI Chat shows a friendly project empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiChatScreen(projectsApi: const _EmptyProjectsApi()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Plan a project with AI first.'), findsOneWidget);

    expect(find.text('Plan with AI'), findsOneWidget);
  });

  testWidgets('AI Chat keeps welcome message when history fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AiChatScreen(
            projectsApi: _SingleProjectApi(),
            aiChatApi: _FailingAiChatApi(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Hi, I am Planora AI.'), findsOneWidget);
    expect(
      find.text(
        'Planora AI is temporarily unavailable. Please try again later.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('AI Chat shows typing indicator while awaiting reply', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AiChatScreen(
            projectsApi: _SingleProjectApi(),
            aiChatApi: _SlowAiChatApi(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'What should I do next?');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump();

    expect(find.text('Planora AI is typing'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Planora AI is typing'), findsNothing);
    expect(find.text('Start with the highest-risk task.'), findsOneWidget);
  });
}

class _EmptyProjectsApi extends ProjectsApi {
  const _EmptyProjectsApi();

  @override
  Future<List<ProjectModel>> getProjects() async {
    return [];
  }
}

class _SingleProjectApi extends ProjectsApi {
  const _SingleProjectApi();

  @override
  Future<List<ProjectModel>> getProjects() async {
    return [
      ProjectModel(
        projectId: 7,
        createdBy: 1,
        teamId: null,
        title: 'Crash Safe Project',
        description: 'Used by AI chat tests',
        deadline: DateTime(2026, 7, 1),
        status: 'in_progress',
        projectType: 'personal',
        createdAt: DateTime(2026, 6, 1),
        updatedAt: null,
      ),
    ];
  }
}

class _FailingAiChatApi extends AiChatApi {
  const _FailingAiChatApi();

  @override
  Future<List<AiChatMessageModel>> getHistory({
    required TaskProjectSummary project,
  }) async {
    throw const ApiException(message: 'Server error', statusCode: 500);
  }
}

class _SlowAiChatApi extends AiChatApi {
  const _SlowAiChatApi();

  @override
  Future<List<AiChatMessageModel>> getHistory({
    required TaskProjectSummary project,
  }) async {
    return [];
  }

  @override
  Future<AiChatMessageModel> sendMessage({
    required TaskProjectSummary project,
    required String message,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    return AiChatMessageModel.localAssistant(
      projectId: project.projectId,
      message: 'Start with the highest-risk task.',
    );
  }
}

Future<void> _pumpTasksScreen(WidgetTester tester, TasksApi tasksApi) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TasksScreen(key: UniqueKey(), onBack: () {}, tasksApi: tasksApi),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

TaskProjectSummary _taskProject(int projectId, String title) {
  return TaskProjectSummary(
    projectId: projectId,
    title: title,
    projectType: 'personal',
  );
}

TaskListItem _taskItem({
  required TaskProjectSummary project,
  required int taskId,
  required String title,
  required TaskStatus status,
  String? description,
}) {
  return TaskListItem(
    project: project,
    task: TaskModel(
      taskId: taskId,
      projectId: project.projectId,
      assignedTo: 1,
      assignedToName: 'Planora Tester',
      assignedToEmail: 'tester@example.com',
      assignedToAvatarUrl: null,
      members: const [],
      followers: const [],
      subtasks: const [],
      tags: const [],
      createdBy: 1,
      title: title,
      description: description,
      sectionName: null,
      priority: TaskPriority.medium,
      estimatedHours: null,
      actualHours: null,
      status: status,
      startDate: null,
      dueDate: DateTime(2026, 6, 20),
      completedAt: status == TaskStatus.completed
          ? DateTime(2026, 6, 18)
          : null,
      createdAt: DateTime(2026, 6, 1, 12, taskId % 60),
    ),
  );
}

class _ProjectFirstTasksApi extends TasksApi {
  final List<TaskProjectSummary> projects;
  final List<TaskListItem> _tasks;
  int _nextTaskId = 1000;

  _ProjectFirstTasksApi({
    required this.projects,
    required List<TaskListItem> tasks,
  }) : _tasks = [...tasks];

  @override
  Future<TaskBoardData> getTasks({TaskStatus? status}) async {
    final tasks = status == null
        ? _tasks
        : _tasks.where((item) => item.task.status == status).toList();

    return TaskBoardData(projects: projects, tasks: [...tasks]);
  }

  @override
  Future<TaskListItem> createTask({
    required TaskCreateRequest request,
    required TaskProjectSummary project,
  }) async {
    final task = _taskItem(
      project: project,
      taskId: _nextTaskId++,
      title: request.title,
      status: TaskStatus.todo,
    );

    _tasks.add(task);

    return task;
  }
}

class _DelayedTasksApi extends TasksApi {
  final Completer<TaskBoardData> _completer = Completer<TaskBoardData>();

  void complete() {
    if (_completer.isCompleted) {
      return;
    }

    _completer.complete(
      TaskBoardData(
        projects: [_taskProject(31, 'Delayed Plan')],
        tasks: const [],
      ),
    );
  }

  @override
  Future<TaskBoardData> getTasks({TaskStatus? status}) {
    return _completer.future;
  }
}

class _FailingTasksApi extends TasksApi {
  @override
  Future<TaskBoardData> getTasks({TaskStatus? status}) async {
    throw const ApiException(message: 'Task board failed', statusCode: 500);
  }
}
