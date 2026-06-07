# Planora Mobile QA Report

Date: 2026-06-07

## Scope

Checked the Flutter mobile app against the local backend reference in `../backend`.
The pass focused on setup, routing, auth/API contracts, core screen reachability, loading/error/empty states, and targeted stability fixes without redesigning the existing light purple Planora direction.

## Follow-up: Home, Projects, Tasks, and AI Planning

Date: 2026-06-07

### Additional Commands Run

From `C:\Users\Ibrahim\Documents\Planora\mobile`:

```powershell
& C:\Users\Ibrahim\Downloads\flutter_windows_3.44.0-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format .
```

Result: succeeded. Final run reported `Formatted 43 files (0 changed)`.

```powershell
& C:\Users\Ibrahim\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat analyze
```

Result: succeeded with `No issues found!`.

```powershell
& C:\Users\Ibrahim\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat test
```

Result: succeeded with `All tests passed!`.

```powershell
& C:\Users\Ibrahim\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat pub get
```

Result: sandboxed run timed out after 120 seconds. Reran outside the sandbox and succeeded. Pub reported 7 newer package versions outside current constraints; no dependency files were changed.

Backend reference checks from `C:\Users\Ibrahim\Documents\Planora\backend`:

```powershell
python -m pytest tests\test_11_ai_plans_api.py
py -m pytest tests\test_11_ai_plans_api.py
& C:\Users\Ibrahim\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe -m pytest tests\test_11_ai_plans_api.py
```

Result: backend pytest could not run in this local shell because `python` is not on PATH, the Windows `py` launcher has no installed Python, and the bundled Codex Python does not include `pytest`, `fastapi`, or `sqlalchemy`.

```powershell
& C:\Users\Ibrahim\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe -m py_compile app\schemas\ai_plan_schema.py app\services\ai_plan_service.py app\routers\ai_plan_routes.py tests\test_11_ai_plans_api.py
```

Result: succeeded.

### Pages Rechecked

- Home dashboard: confirmed it uses `ProjectsApi.getProjects()` plus `TasksApi.getProjectTasks()` per project for overview counts, task-derived progress, project rows, and upcoming tasks.
- Projects list: updated progress bars and labels to use real task rows from the tasks API instead of status-only estimates.
- Project details: updated schedule/progress/tasks sections to load real project tasks from the backend and refresh after AI task generation.
- Create project: added an optional AI task toggle that calls the backend AI planning endpoint after the project row is created.
- AI chat assistant: confirmed the selected project model is used for the real AI plan endpoint, including team vs personal route selection.
- Tasks tab: existing regression test still confirms tapping Tasks opens tab index `3`, not Create Task.

### Issues Found

- Projects list progress was still inferred from project status and could look disconnected from actual DB tasks.
- Project details did not show the project's real task list.
- AI task generation was not exposed from project details/create project in a way that refreshed the DB-backed task surfaces.
- `Switch.activeColor` had become deprecated on the current Flutter SDK.

### Issues Fixed

- Project list now loads task summaries for each backend project and calculates progress from completed/total tasks when tasks exist.
- Project details now displays a `Project Tasks` section loaded from the real personal/team task endpoints.
- Project details now has a Planora-styled AI task generation sheet that calls `/ai-plan/generate`, supports append/replace, and refreshes tasks after success.
- Create Project now includes an opt-in AI task toggle. If enabled, the app creates the project first, then calls the backend planner to create real tasks for that project.
- AI chat now includes a `Plan` action that calls the backend AI planner for the selected project without faking chat history.
- Added parser coverage for `AiPlanGenerateResponse`.
- Replaced deprecated `Switch.activeColor` with `activeThumbColor`.

### Additional Files Changed

- `lib/features/ai/data/ai_plan_api.dart`
- `lib/features/projects/project_detail_screen.dart`
- `lib/features/projects/projects_screen.dart`

### Remaining From This Follow-up

- Backend pytest needs a local Python environment with the backend requirements installed and `TEST_DATABASE_URL` configured.
- Mobile visual QA was still code/test based; no emulator screenshot sweep was run.
- Team creation/invite flows remain outside this pass, so team AI planning can be used only for team projects returned by the backend.

## Follow-up: AI Chat Crash Fix

Date: 2026-06-07

### Scope

Fixed the AI Chat crash path only. Registration/auth fixes are intentionally deferred.

### Reproduction / Verification Notes

- `flutter devices` timed out inside the sandbox, then succeeded outside the sandbox and found Android emulator, Windows, Chrome, and Edge targets.
- Full authenticated manual reproduction against `https://planora-api-dqmv.onrender.com` was blocked by not having a valid test login in this thread.
- Added widget coverage that opens `AiChatScreen` with fake project/chat APIs and reproduces the risky failure path: chat history returns a backend-style `ApiException(500)`.
- The fixed screen now logs the real error with `debugPrint/debugPrintStack`, keeps a local Planora AI welcome message, and shows a friendly SnackBar instead of crashing.

### Commands Run

```powershell
& C:\Users\Ibrahim\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat devices
```

Result: sandboxed run timed out after 120 seconds. Reran outside the sandbox and succeeded.

```powershell
& C:\Users\Ibrahim\Downloads\flutter_windows_3.44.0-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\features\ai\ai_chat_screen.dart lib\features\ai\data\ai_chat_api.dart lib\features\home\home_screen.dart test\widget_test.dart
```

Result: sandboxed run hit Dart CLI AppData analytics permission error. Reran outside the sandbox and succeeded.

```powershell
& C:\Users\Ibrahim\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat analyze
```

Result: `No issues found!`

```powershell
& C:\Users\Ibrahim\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat test
```

Result: `All tests passed!`

### Issues Fixed

- AI chat message parsing now supports numeric string IDs, missing IDs, missing `project_id`, missing `sender_id`, null/missing `message`/`body`, and invalid/null `created_at`.
- AI chat history parsing skips malformed list entries instead of casting blindly.
- AI chat send parsing tolerates incomplete server responses.
- AI Chat catches `ApiException` and other real errors, logs the actual error/stack trace, and shows a user-friendly SnackBar.
- If history loading fails, the screen keeps a local Planora AI welcome message.
- If no project is selected or available, the screen shows: `Choose a project to start chatting with Planora AI.`
- Home bottom navigation now passes an `Open Projects` callback into AI Chat so users can route to Projects from the empty state.

### Files Changed In This Fix

- `lib/features/ai/ai_chat_screen.dart`
- `lib/features/ai/data/ai_chat_api.dart`
- `lib/features/home/home_screen.dart`
- `test/widget_test.dart`
- `docs/MOBILE_QA_REPORT.md`
- `docs/PLANORA_CONTEXT.md`

## Commands Run

From `C:\Users\Ibrahim\Documents\Planora\mobile`:

```powershell
& C:\Users\Ibrahim\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat pub get
```

Result: first sandboxed attempt timed out after 120 seconds. Reran outside the sandbox and succeeded.

```powershell
& C:\Users\Ibrahim\Downloads\flutter_windows_3.44.0-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format .
```

Result: succeeded.

```powershell
& C:\Users\Ibrahim\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat analyze
```

Result: succeeded before and after fixes. Final result: `No issues found!`.

```powershell
& C:\Users\Ibrahim\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat test
```

Result: sandboxed attempts timed out silently. Reran outside the sandbox and succeeded with `All tests passed!`.

## Pages Checked

- Onboarding: starts when no token exists; startup widget test covers the signed-out boot flow.
- Login: checked form validation, backend login request, token save, and post-login navigation.
- Register: fixed to call backend registration before email verification.
- Email verification: fixed verify/resend API calls.
- Forgot password: checked backend request body and reset-link-sent state.
- Reset password: checked `/reset-password` deep-link handling and backend reset request body.
- Home dashboard: checked upcoming-task loading/error/empty states and shell navigation.
- Projects list: checked loading/error/empty states, filters, and create-project sheet.
- Project details: added reachable detail page from project cards.
- Create project: checked personal project create body against backend `ProjectCreate`.
- Tasks list: checked filters, grouped list, empty/error/loading states, and tab behavior.
- Create task: checked add-task flow only opens from plus/add request, not the Tasks tab.
- Task details: checked detail layout, tabs, comments, attachments, edit, delete, and completion actions in code.
- AI chat assistant: added reachable project-scoped chat screen using backend AI chat routes.
- Notifications: added reachable notifications screen using backend notification routes.
- Team/project members: added project-member display for team project details.
- Profile: added reachable profile screen.
- Edit profile: added profile edit bottom sheet using `/profile`.
- Change password: added password change bottom sheet using `/profile/password`.
- Settings: added settings bottom sheet with theme toggle and API URL visibility.

Note: this pass verified screens by code review and widget tests. It did not include a real emulator/device screenshot sweep.

## API Contract Checks

- `POST /auth/login`: mobile uses form data with `username` and `password`, matching `OAuth2PasswordRequestForm`.
- `POST /auth/register`: mobile now sends `username`, `email`, `password`, and `full_name`, matching `RegisterRequest`.
- `POST /auth/verify-email`: mobile now sends `email` and 6-digit `code`, matching `VerifyEmailRequest`.
- `POST /auth/resend-verification-code`: mobile sends `email`, matching backend.
- `POST /auth/forgot-password`: mobile sends `email`, matching backend.
- `POST /auth/reset-password`: mobile sends `email`, `token`, and `new_password`, matching backend.
- `GET /auth/me`: mobile uses it in `AuthGate` to load the current verified user after token restore/login.
- `GET /projects`: personal projects remain supported.
- `GET /teams` and `GET /teams/{team_id}/projects`: mobile now merges team projects into the project/task surfaces.
- `GET /teams/{team_id}/projects/{project_id}/members`: mobile now uses this in team project details.
- `GET /notifications`, `GET /notifications/unread-count`, `PATCH /notifications/read-all`, `PATCH /notifications/{id}/read`: mobile now has notification support.
- `GET/PATCH /profile` and `PATCH /profile/password`: mobile now has profile edit and password change support.
- `GET/POST /projects/{project_id}/chat` and team chat equivalents: mobile now has project-scoped AI chat support.

API base URL remains controlled by:

```dart
String.fromEnvironment('PLANORA_API_URL', defaultValue: 'https://planora-api-dqmv.onrender.com')
```

Use `--dart-define=PLANORA_API_URL=...` for local backend or Render safely. No secrets were hardcoded.

## Issues Found

- Register did not call `/auth/register`; it only navigated to email verification.
- Register did not collect `username`, but backend requires it.
- Email verification and resend were placeholders.
- Login pushed `HomeScreen` directly, bypassing `AuthGate`, which made logout/navigation state fragile.
- Project cards showed a snackbar instead of a detail page.
- Team projects were not fetched, so team project tasks/member UI could not be reached.
- AI chat, notifications, profile, edit profile, change password, and settings were missing or placeholder-only.
- No Flutter test directory existed.
- Standard `flutter test` needed to run outside the sandbox in this environment.

## Issues Fixed

- Replaced Home dashboard sample project/overview data with backend-derived projects and tasks.
- Home Project Overview now uses live project/task counts, completion percentage, and at-risk counts.
- Home My Projects now displays real project rows with backend title/status/deadline/type and task-derived progress.
- Home Upcoming Tasks now shares the same backend dashboard load and refresh path.
- Added real register API call and username field.
- Added real email verification and resend verification API calls.
- Changed login success navigation to return through `AuthGate`.
- Added `AuthGate` user update support for profile edits.
- Added team loading into `ProjectsApi` and merged personal/team projects.
- Added project detail screen with description, schedule, status, progress, and project members.
- Added notifications API and notifications screen.
- Added AI chat API and project-scoped AI chat screen.
- Added profile API and profile screen with edit profile, change password, settings, and logout.
- Connected Home avatar, notification bell, and AI tab to real screens.
- Added widget tests for app startup and Tasks tab behavior.
- Verified Tasks tab emits index `3`, not create task or AI center action.

## Issues Remaining

- Create team, invite team members, and create team-project flows are still not implemented in mobile.
- Backend project-member responses currently expose member IDs/roles but not names/emails; the mobile member UI shows `User #id`.
- Search, calendar, reports, social login, profile-picture upload, and attachment upload are still incomplete/placeholders.
- Reset-password deep-link handling exists in Flutter via `Uri.base`, but mobile platform deep-link/app-link configuration still needs device-level verification.
- Theme preference is session-only and is not persisted yet.
- This pass did not run a real emulator/device visual screenshot sweep.

## Files Changed

- `lib/features/ai/ai_chat_screen.dart`
- `lib/features/ai/data/ai_chat_api.dart`
- `lib/features/auth/auth_gate.dart`
- `lib/features/auth/data/project_api.dart`
- `lib/features/auth/models/project_models.dart`
- `lib/features/email_verification/email_verification_screen.dart`
- `lib/features/home/home_screen.dart`
- `lib/features/home/widgets/home_bottom_nav.dart`
- `lib/features/login/login_screen.dart`
- `lib/features/notifications/data/notifications_api.dart`
- `lib/features/notifications/notifications_screen.dart`
- `lib/features/profile/data/profile_api.dart`
- `lib/features/profile/profile_screen.dart`
- `lib/features/projects/project_detail_screen.dart`
- `lib/features/projects/projects_screen.dart`
- `lib/features/register/register_screen.dart`
- `test/widget_test.dart`
- `docs/MOBILE_QA_REPORT.md`
- `docs/PLANORA_CONTEXT.md`

## Manual Test Checklist

Run the app with Render:

```powershell
& C:\Users\Ibrahim\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat run
```

Run the app with local backend from an Android emulator:

```powershell
& C:\Users\Ibrahim\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat run --dart-define=PLANORA_API_URL=http://10.0.2.2:8000
```

Run the app with local backend from Windows desktop/web:

```powershell
& C:\Users\Ibrahim\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat run --dart-define=PLANORA_API_URL=http://localhost:8000
```

Manual flow:

1. Start signed out and confirm onboarding appears.
2. Open Register, create an account with username/email/password/full name.
3. Confirm email verification screen appears and accepts a 6-digit code.
4. Use resend verification after the timer expires.
5. Login and confirm Home opens.
6. Tap Tasks tab and confirm it opens the task list, not create task.
7. Tap the add task action and confirm Create Task opens.
8. Open Projects, create a personal project, optionally enable AI Tasks, then confirm the project appears.
9. Tap the project to view details, generate AI tasks, and confirm the Project Tasks section refreshes from the backend.
10. If the account has teams, confirm team projects appear and project members load in details.
11. Open AI tab, select a project, send a message, then tap Plan and confirm generated tasks appear in Project Details or Tasks.
12. Tap notifications bell, read notifications, and mark all read.
13. Tap avatar, edit profile, change password, open settings, then logout.
