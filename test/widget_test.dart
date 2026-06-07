import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/ai/data/ai_plan_api.dart';
import 'package:mobile/features/home/widgets/home_bottom_nav.dart';
import 'package:mobile/main.dart';

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

  test('AI plan generation response parses backend task payloads', () {
    final response = AiPlanGenerateResponse.fromJson({
      'project_id': 7,
      'plan_id': 11,
      'summary': 'Generated a structured plan.',
      'tasks_created': 1,
      'tasks': [
        {
          'task_id': 21,
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
}
