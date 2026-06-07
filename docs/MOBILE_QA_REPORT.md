# Planora Mobile QA Report

Date: 2026-06-07

## Scope

Checked the Flutter mobile app against the local backend reference in `../backend`.
The pass focused on setup, routing, auth/API contracts, core screen reachability, loading/error/empty states, and targeted stability fixes without redesigning the existing light purple Planora direction.

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
8. Open Projects, create a personal project, then tap it to view project details.
9. If the account has teams, confirm team projects appear and project members load in details.
10. Open AI tab, select a project, send a message.
11. Tap notifications bell, read notifications, and mark all read.
12. Tap avatar, edit profile, change password, open settings, then logout.
