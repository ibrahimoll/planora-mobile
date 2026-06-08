# Planora Mobile Context

Last updated: 2026-06-08

## Repository

- Mobile app repo: `ibrahimoll/planora-mobile`
- Framework: Flutter
- Main entry file: `lib/main.dart`
- Current start screen: `OnboardingScreen`

## Latest Mobile State - 2026-06-08

- AI Chat no longer crashes when opened from the center bottom nav on the Pixel 9 emulator against the Render backend.
- Home tab pages now receive full `AnimatedSwitcher` stack constraints, which protects AI Chat and other tab pages from loose animated layout constraints.
- AI Chat uses a burger-menu `Project Chats` drawer instead of a dropdown. The drawer lists personal projects from `/projects`, and each selection loads project-scoped chat history.
- AI Chat header shows the selected project title, keeps the local welcome bubble, anchors the composer above bottom nav, and shows `Planora AI is typing` while awaiting replies.
- Home `New Project` now opens the real Create Project bottom sheet instead of only navigating to the Projects tab.
- Projects tune icon now opens a real All/Active/Completed filter sheet.
- `AuthGate` preserves the saved token if `/auth/me` fails, logs the real error, and enters Home with a minimal fallback session user so token-authenticated screens can still load.
- Unexpected auth/reset/notification failures are now logged with `debugPrint`/`debugPrintStack` while users still get friendly messages.
- Apple login/register buttons were removed from visible auth UI while Apple auth is paused; Google remains a clear coming-soon action.
- Latest verification: `dart format lib test`, `flutter analyze`, `flutter test`, and emulator launch with `--dart-define=PLANORA_API_URL=https://planora-api-dqmv.onrender.com` passed. Home `New Project`, AI Chat, and AI project drawer were manually checked on the emulator.

## Previous Mobile State - 2026-06-07

- Latest follow-up fixed backend/mobile member identity display, project member invites, AI Chat typing feedback, task grouping, and Profile/Settings polish.
- Mobile no longer creates visible `User #id` or `Member #id` labels in the project member/task assignee paths touched in this pass; it displays nested backend user summaries with full name, username, email, then `Unknown user`.
- Project Details now has a team-project invite member sheet that posts email/username plus role to the backend invite endpoint and reloads members after success.
- AI task generation remains data-backed: Create Project and Project Details call backend `/ai-plan/generate` with task creation enabled, and AI failures are logged instead of swallowed.
- AI Chat now shows an animated `Planora AI is typing` bubble while awaiting a reply.
- Tasks list grouping now includes `Overdue`, `Today`, `Tomorrow`, `Next Week`, `Upcoming`, `Later`, and `Completed`.
- Profile/Settings now follows the provided card-based light/dark reference direction and shows real project count, completed task count, and days-active stats from backend-backed models.
- Latest verification: `flutter pub get`, `dart format .`, `flutter analyze`, and `flutter test` passed. Backend touched files passed `py_compile`; backend pytest could not start because this Python install is missing `pytest`.

- Home dashboard, Project Overview, My Projects, and Upcoming Tasks use real backend project/task data instead of static samples.
- Projects list now loads task summaries per backend project and computes progress from completed task rows when available.
- Project details now shows real project tasks and can generate AI tasks through the backend `/ai-plan/generate` endpoints.
- Create Project has an opt-in AI Tasks toggle: the project is created first, then generated tasks are persisted by the backend planner.
- Planora AI chat has a `Plan` action that calls the same backend planner for the selected personal/team project.
- `flutter analyze` and `flutter test` pass after the latest home/project/task AI-planning follow-up.

## Latest AI Chat Crash Fix - 2026-06-07

- AI Chat now handles missing/no selected project with the friendly empty state: `Choose a project to start chatting with Planora AI.`
- AI Chat routes users to Projects from the empty state when opened from Home.
- AI chat history/send failures are caught as real errors, logged with `debugPrint/debugPrintStack`, and surfaced through a user-friendly SnackBar.
- A local Planora AI welcome message remains visible when chat history loading fails.
- `AiChatMessageModel` parsing is defensive for numeric string IDs, missing `project_id`/`sender_id`, null message/body fields, and invalid/null dates.
- AI Chat shows an animated assistant typing bubble while a reply is in-flight.
- Added widget tests for the empty state, backend-style history failure, and partial chat JSON parsing.
- Latest verification: `flutter analyze` passed with no issues and `flutter test` passed with 7 tests.

## Current Mobile UI Direction

Planora mobile should use a clean, modern, friendly, professional light/dark identity with purple branding.

Design style:

- Light mode: soft white/lavender background, purple primary actions, clean cards, rounded buttons, friendly professional layout.
- Dark mode: near-black background, purple glow accents, purple CTA gradient, white primary text, muted secondary text, dark outlined secondary button.
- Keep the current Planora logo unless the user explicitly asks to change it.
- Do not add the old/extra `Track & Predict` onboarding page unless the user asks for it.

## Onboarding Screens

Current onboarding uses 4 pages:

1. Intro / welcome
   - Title: `Plan smarter.\nDeliver better.`
   - Highlighted text: `smarter.`
   - Description: `Planora helps you plan projects, manage tasks, predict risks, and deliver successful results with the power of AI.`
2. AI planning
   - Title: `AI-Powered Planning`
3. Collaboration
   - Title: `Collaborate Effortlessly`
4. Final CTA
   - Title: `Ready to Achieve More?`

Current onboarding files:

- `lib/features/onboarding/onboarding_screen.dart`
- `lib/features/onboarding/data/onboarding_pages.dart`
- `lib/features/onboarding/models/onboarding_page_data.dart`
- `lib/features/onboarding/utils/onboarding_responsive_metrics.dart`
- `lib/features/onboarding/widgets/intro_onboarding_page.dart`
- `lib/features/onboarding/widgets/image_onboarding_page.dart`
- `lib/features/onboarding/widgets/onboarding_image.dart`
- `lib/features/onboarding/widgets/onboarding_page_dot.dart`
- `lib/features/onboarding/widgets/onboarding_small_widgets.dart`

## Light and Dark Theme Implementation

`lib/main.dart` owns the current theme state:

- Uses `PlanoraTheme.lightTheme`
- Uses `PlanoraTheme.darkTheme`
- Uses a local `_themeMode` state
- Starts with `ThemeMode.system`
- Allows manual switching between `ThemeMode.light` and `ThemeMode.dark`
- Passes `onThemeToggle` into `OnboardingScreen`

Current behavior:

- If the app starts in system mode, it follows the phone/emulator theme.
- Once the user taps the onboarding theme switch, it manually toggles between light and dark for the current app session.
- Theme preference is not persisted yet. Add `shared_preferences` later when building Settings/Profile.

## Onboarding Theme Switch

A professional theme switch exists on the onboarding screen and is pinned to the real top-right screen corner.

Current position:

- Implemented with `Positioned` inside the main onboarding `Stack`, not inside the onboarding content column.
- Uses `top: MediaQuery.paddingOf(context).top + 10`.
- Uses `right: 20`.
- Content column includes top spacing so the page content does not collide with the switch.

Current switch behavior:

- Shows both icons side by side.
- Sun icon represents light mode and uses `Icons.light_mode_rounded`.
- Moon icon represents dark mode and uses `CupertinoIcons.moon_fill`.
- Purple circular thumb slides smoothly between sun and moon.
- Active icon is centered inside the thumb and turns white.
- Inactive icon remains visible with muted color.
- The dark-mode purple thumb is intentionally shifted left so it has better spacing from the right edge.
- The moon slot is shifted left by the same amount so the moon remains centered inside the purple thumb.

Current switch geometry in `_ThemeToggleButton`:

- switch width: `104`
- switch height: `52`
- switch padding: `6`
- thumb size: `36`
- icon slot size: `36`
- dark thumb inset: `5`
- `innerWidth = switchWidth - (switchPadding * 2)`
- `innerHeight = switchHeight - (switchPadding * 2)`
- `thumbTravel = innerWidth - thumbSize - darkThumbInset`
- `thumbTop = (innerHeight - thumbSize) / 2`
- `iconTop = (innerHeight - iconSlotSize) / 2`

Current switch classes are private inside `onboarding_screen.dart`:

- `_ThemeToggleButton`
- `_ThemeToggleIcon`
- `_ThemeToggleMoonIcon`

Important implementation detail:

- The switch uses `AnimatedPositioned` instead of `AnimatedAlign` so the thumb moves by exact pixels and lines up with icon centers.
- The sun and moon use fixed `Positioned` slots instead of a loose `Row + Spacer` layout.
- Do not return to the custom painted moon crescent; it looked bad. The current preferred moon is `CupertinoIcons.moon_fill`.

## Onboarding Images

Light mode image assets:

- `assets/images/onboarding_1.png`
- `assets/images/onboarding_2.png`
- `assets/images/onboarding_3.png`
- `assets/images/onboarding_4.png`

Dark mode image assets:

- `assets/images/onboardDark_1.png`
- `assets/images/onboardDark_2.png`
- `assets/images/onboardDark_3.png`
- `assets/images/onboardDark_4.png`

Rules:

- Use the exact dark filenames above, including uppercase `D` in `onboardDark`.
- `OnboardingPageData` has `imageAsset` and optional `darkImageAsset`.
- Use `data.imageAssetFor(context)` when rendering onboarding images.
- Dark images are registered in `pubspec.yaml`.

## Current Theme / Design Files

Main theme file:

- `lib/core/theme/planora_theme.dart`

Current theme includes:

- `lightTheme`
- `darkTheme`
- light/dark colors
- light/dark gradients
- light/dark shadows
- helpers:
  - `PlanoraTheme.isDark(context)`
  - `PlanoraTheme.onboardingBackgroundFor(context)`
  - `PlanoraTheme.primaryGradientFor(context)`
  - `PlanoraTheme.softPurpleGradientFor(context)`
  - `PlanoraTheme.softGradientFor(context)`
  - `PlanoraTheme.floatingShadowFor(context)`

Dark onboarding/auth background now uses the shared theme gradient from `PlanoraTheme.darkOnboardingBackground`:

- `PlanoraTheme.darkBackground`
- `Color(0xFF1A1233)`

Dark CTA buttons now use `PlanoraTheme.primaryGradientFor(context)`, which keeps the stronger purple CTA gradient readable in dark mode.

Auth screens should not introduce one-off dark surfaces such as `0xFF1D202C` or `0xFF2A2D3A`; use `PlanoraTheme.darkSurface`, `PlanoraTheme.darkSurfaceVariant`, and `PlanoraTheme.darkBorder`.

Soft lavender accents should use `PlanoraTheme.lavenderSurface`, `PlanoraTheme.lavenderBorder`, and `PlanoraTheme.lavenderCard`.

## Asset Registration

`pubspec.yaml` currently registers:

```yaml
assets:
  - assets/images/planora_logo.png
  - assets/images/onboarding_1.png
  - assets/images/onboarding_2.png
  - assets/images/onboarding_3.png
  - assets/images/onboarding_4.png
  - assets/images/onboardDark_1.png
  - assets/images/onboardDark_2.png
  - assets/images/onboardDark_3.png
  - assets/images/onboardDark_4.png
  - assets/images/email_verification_light.png
  - assets/images/email_verification_dark.png
  - assets/images/forgot_password_light.png
  - assets/images/forgot_password_dark.png
  - assets/images/reset_link_sent_light.png
  - assets/images/reset_link_sent_dark.png
```

If dark images do not show, check:

1. The filenames exactly match `onboardDark_1.png` through `onboardDark_4.png`.
2. The files are inside `assets/images/`.
3. `flutter pub get` was run after changing `pubspec.yaml`.
4. The emulator/app was fully restarted if hot reload does not pick up assets.

## Recent Mobile Work Completed

Completed in the latest full mobile QA pass:

- Home dashboard was corrected after the QA pass so Project Overview, My Projects, and Upcoming Tasks are all derived from backend project/task data instead of sample UI data.
- Home project progress uses real task completion for that project when tasks exist, with project status as a fallback.
- Added `docs/MOBILE_QA_REPORT.md` with setup, routing, API, UI/state, testing, and remaining-gap notes.
- Registration now calls the real backend `/auth/register` endpoint and collects the required `username`.
- Email verification now calls `/auth/verify-email`, and resend calls `/auth/resend-verification-code`.
- Login now saves the token and returns through `AuthGate`, so current-user loading and logout are owned by the auth state.
- `ProjectsApi` now loads personal projects plus team projects from `/teams` and `/teams/{team_id}/projects`.
- Project cards now open a real project detail screen with overview, schedule, progress, and team project members.
- Added reachable AI chat, notifications, profile, edit profile, change password, and settings surfaces while keeping the light purple Planora style.
- Home avatar opens profile/settings, the notification bell opens notifications, and the center AI tab opens project-scoped AI chat.
- Added `test/widget_test.dart` for app startup and Tasks tab behavior.
- Verification completed:
  - `flutter pub get`
  - `dart format .`
  - `flutter analyze`
  - `flutter test`
- Remaining known gaps:
  - Team creation/invite flows are not implemented on mobile yet.
  - Project-member API responses expose IDs/roles but not names/emails, so mobile displays `User #id`.
  - Search, calendar, reports, social login, profile-picture upload, attachment upload, and persistent theme preference still need future passes.
  - Reset-password deep links still need platform-level app-link verification on device.

Completed in the latest auth UI/UX review pass:

- Added `lib/features/auth/shared/auth_widgets.dart` for shared auth UI pieces:
  - `PlanoraAuthTopBar`
  - `PlanoraAuthBrandHeader`
  - `PlanoraAuthTextField`
  - `PlanoraGradientButton`
  - `PlanoraAuthDivider`
  - `PlanoraSocialButton`
  - `PlanoraAuthIllustration`
- Removed the empty placeholder files under `lib/features/login/widgets/`.
- Updated login/register/forgot-password/email-verification to use the shared auth widgets and theme colors.
- Replaced hard-coded auth dark backgrounds with `PlanoraTheme.onboardingBackgroundFor(context)`.
- Updated onboarding final primary action so `Create Account` opens `RegisterScreen` instead of showing a snackbar.
- Register password validation now stays neutral while empty, then shows check/X states after typing.
- Register password rules currently require:
  - at least 8 characters
  - one uppercase letter
  - one symbol
- Confirm password now shows neutral, matching, or non-matching feedback without showing an error before typing.
- Forgot password validates email locally, uses the light/dark email image slots, and transitions to the reset-link-sent state without adding external images.
- Email verification now shows the target email, uses responsive OTP boxes, supports multi-digit paste/autofill better, mutes the resend timer when disabled, and disables verify until 6 digits are entered.
- `pubspec.yaml` registers the reset-link-sent light/dark assets.
- Verification completed:
  - `dart format .`
  - `flutter analyze`
  - `flutter test` was skipped because there is no `test/` directory yet.

Completed through the latest mobile onboarding/theme-switch pass:

- Added complete app-level light/dark theme support.
- Added dark onboarding asset support.
- Registered `onboardDark_1.png` through `onboardDark_4.png` in `pubspec.yaml`.
- Updated onboarding widgets to use theme-aware colors instead of fixed light colors.
- Added manual onboarding theme switch.
- Refined switch to show sun/moon side by side.
- Fixed switch alignment so icons and thumb centers line up.
- Pinned the switch to the real top-right corner outside the onboarding content column.
- Increased switch card spacing to prevent thumb clipping.
- Replaced the custom painted moon with `CupertinoIcons.moon_fill`.
- Shifted the dark-mode purple thumb and moon slot left by `5px` so the moon sits centered inside the purple circle.

Important recent commit hashes:

- `2efb56829404e89bead715fc919753aa164b80fb` — dark onboarding images and color tuning.
- `a5435854dafb44170d1cc3c5e544c2ee35dd1489` — first onboarding theme toggle.
- `221a6aee91914fb049e2a1a80a17182889ea04de` — animated two-icon switch.
- `6078ca4d73edb351a9a217c698a289b92beb8517` — refined switch design.
- `522818a260fa9454f5329f555906fecf6d56e952` — centered sun/moon and thumb geometry.
- `00ed66f3ec1d2e8a31b42565373188a48cb9ab94` — pinned onboarding theme switch to screen corner.
- `189564f74daf1804422c1c43f3200407f311acf6` — increased onboarding theme switch spacing.
- `e31ffcf1e9d9b5d4314cfb7867ee17c5a4385722` — added more space around the switch thumb.
- `76c1a7f7aa53055c6b8767a6f74c4c8bee9c0157` — tried custom painted moon for theme switch.
- `dadc6f423db75cc5245d1086bfe025694e5ead77` — shifted and reshaped custom moon.
- `559b832b66deac5a30456a2467ae7b0ce9ce0429` — final preferred moon fix: Cupertino moon icon and left-shifted dark thumb.

## Local Git Conflict Recovery

If `git pull` or commit fails because of unmerged files/conflicts and there are no local changes to preserve, reset to GitHub `main`:

```powershell
cd C:\Users\Ibrahim\Documents\Planora\planora-mobile
git merge --abort
git fetch origin
git reset --hard origin/main
git clean -fd
```

Then continue with normal verification.

## Local Verification Commands

Use these commands after pulling mobile changes:

```powershell
cd C:\Users\Ibrahim\Documents\Planora\planora-mobile
git pull
flutter pub get
flutter analyze
flutter run
```

If the local path is different, adjust the `cd` path.

## Next Recommended Mobile Steps

1. Add or verify the actual dark onboarding images:
   - `assets/images/onboardDark_1.png`
   - `assets/images/onboardDark_2.png`
   - `assets/images/onboardDark_3.png`
   - `assets/images/onboardDark_4.png`
2. Test onboarding in light mode and dark mode.
3. Adjust spacing only after seeing the real dark images in the emulator.
4. Later, add persistent theme choice using `shared_preferences` when building Settings/Profile.
5. Continue next mobile screens in this design order:
   - Login
   - Register
   - Email verification
   - Forgot password
   - Reset password
   - Home dashboard
   - Projects
   - Tasks
   - AI chat
   - Notifications
   - Profile / Settings
