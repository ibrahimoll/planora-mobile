import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/core/storage/token_storage.dart';
import 'package:mobile/main.dart' as app;

const _placeholderEmail = 'test-user@example.com';
const _placeholderPassword = 'replace-with-test-password';
const _testEmail = String.fromEnvironment(
  'PLANORA_TEST_EMAIL',
  defaultValue: _placeholderEmail,
);
const _testPassword = String.fromEnvironment(
  'PLANORA_TEST_PASSWORD',
  defaultValue: _placeholderPassword,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('authenticated navigation smoke test', (tester) async {
    expect(
      _testEmail,
      allOf(isNotEmpty, isNot(_placeholderEmail)),
      reason: 'Pass PLANORA_TEST_EMAIL with --dart-define.',
    );
    expect(
      _testPassword,
      allOf(isNotEmpty, isNot(_placeholderPassword)),
      reason: 'Pass PLANORA_TEST_PASSWORD with --dart-define.',
    );

    await TokenStorage.clearAccessToken();
    await app.main();

    await _waitForAny(tester, [
      find.byKey(const Key('login_email_field')),
      find.text('Sign In'),
    ]);
    expect(find.byType(MaterialApp), findsOneWidget);

    if (find.byKey(const Key('login_email_field')).evaluate().isEmpty) {
      await tester.tap(find.text('Sign In').first);
      await tester.pump();
    }

    await _waitFor(tester, find.byKey(const Key('login_email_field')));
    expect(find.byKey(const Key('login_password_field')), findsOneWidget);
    expect(find.byKey(const Key('login_button')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('login_email_field')),
      _testEmail,
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      _testPassword,
    );
    await tester.tap(find.byKey(const Key('login_button')));

    await _waitFor(
      tester,
      find.byKey(const Key('home_screen')),
      timeout: const Duration(seconds: 35),
    );
    expect(find.byKey(const Key('projects_tab')), findsOneWidget);

    await tester.tap(find.byKey(const Key('projects_tab')));
    await tester.pump();
    await _waitForAny(tester, [
      find.byKey(const Key('project_card')),
      find.text('No plans yet'),
      find.text('Could not load plans'),
    ], timeout: const Duration(seconds: 35));

    if (find.byKey(const Key('project_card')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('project_card')).first);
      await _waitFor(tester, find.byKey(const Key('project_tasks_tab')));
      await _waitUntilAbsent(
        tester,
        find.byKey(const Key('project_detail_loading')),
        timeout: const Duration(seconds: 35),
      );

      await tester.tap(find.byKey(const Key('project_tasks_tab')));
      await tester.pump();
      await _waitForAny(tester, [
        find.byKey(const Key('task_card')),
        find.text('No tasks in this project yet.'),
        find.text('Could not load project details.'),
      ], timeout: const Duration(seconds: 35));

      if (find.byKey(const Key('task_card')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('task_card')).first);
        await _waitFor(tester, find.byKey(const Key('task_detail_screen')));
        await tester.pageBack();
        await _waitFor(tester, find.byKey(const Key('project_tasks_tab')));
      }

      await tester.pageBack();
      await _waitFor(tester, find.byKey(const Key('projects_tab')));
    }

    await tester.tap(find.byKey(const Key('home_tab')));
    await _waitFor(tester, find.byKey(const Key('home_screen')));
    await tester.tap(find.byKey(const Key('home_profile_button')));
    await _waitFor(tester, find.byKey(const Key('logout_button')));
    await tester.ensureVisible(find.byKey(const Key('logout_button')));
    await tester.tap(find.byKey(const Key('logout_button')));

    await _waitForAny(tester, [
      find.byKey(const Key('login_email_field')),
      find.text('Sign In'),
    ], timeout: const Duration(seconds: 35));
  });
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  await _waitForAny(tester, [finder], timeout: timeout);
}

Future<void> _waitForAny(
  WidgetTester tester,
  List<Finder> finders, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finders.any((finder) => finder.evaluate().isNotEmpty)) {
      return;
    }
  }

  throw TestFailure(
    'Timed out waiting for any of: '
    '${finders.map((finder) => finder.description).join(', ')}',
  );
}

Future<void> _waitUntilAbsent(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isEmpty) {
      return;
    }
  }

  throw TestFailure('Timed out waiting for: ${finder.description} to leave.');
}
