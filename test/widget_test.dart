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
import 'package:mobile/features/tasks/models/task_models.dart';

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
