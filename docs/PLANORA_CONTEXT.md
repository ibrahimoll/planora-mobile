# Planora Mobile Context

Last updated: 2026-05-28

## Repository

- Mobile app repo: `ibrahimoll/planora-mobile`
- Framework: Flutter
- Main entry file: `lib/main.dart`
- Current start screen: `OnboardingScreen`

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

`lib/main.dart` now owns the current theme state:

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

A professional theme switch exists on the onboarding screen near the top-right.

Current switch behavior:

- Shows both icons side by side.
- Sun icon represents light mode.
- Moon icon represents dark mode.
- Purple rounded thumb slides smoothly between sun and moon.
- Active icon is centered inside the thumb and turns white.
- Inactive icon remains visible with muted color.
- Uses fixed geometry so sun/moon stay centered:
  - switch width: `84`
  - switch height: `40`
  - switch padding: `3`
  - thumb size: `34`
  - icon slot size: `34`

Current switch classes are private inside `onboarding_screen.dart`:

- `_ThemeToggleButton`
- `_ThemeToggleIcon`

Important implementation detail:

- The switch uses `AnimatedPositioned` instead of `AnimatedAlign` so the thumb moves by exact pixels and lines up with the icon centers.
- Each icon is wrapped in a fixed `SizedBox(width: 34, height: 34)` and `Center` to prevent drifting.

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

Dark onboarding background currently uses a near-black custom gradient in `onboarding_screen.dart`:

- `Color(0xFF05070B)`
- `Color(0xFF0B1018)`

Dark CTA button gradient currently uses:

- `Color(0xFF7C3AED)`
- `Color(0xFF5B2DDA)`

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
```

If dark images do not show, check:

1. The filenames exactly match `onboardDark_1.png` through `onboardDark_4.png`.
2. The files are inside `assets/images/`.
3. `flutter pub get` was run after changing `pubspec.yaml`.
4. The emulator/app was fully restarted if hot reload does not pick up assets.

## Recent Mobile Work Completed

Completed on 2026-05-28:

- Added complete app-level light/dark theme support.
- Added dark onboarding asset support.
- Registered `onboardDark_1.png` through `onboardDark_4.png` in `pubspec.yaml`.
- Updated onboarding widgets to use theme-aware colors instead of fixed light colors.
- Added manual onboarding theme switch.
- Refined switch to show sun/moon side by side.
- Fixed switch alignment so icons and thumb centers line up.

Important recent commit hashes:

- `2efb56829404e89bead715fc919753aa164b80fb` — dark onboarding images and color tuning.
- `a5435854dafb44170d1cc3c5e544c2ee35dd1489` — first onboarding theme toggle.
- `221a6aee91914fb049e2a1a80a17182889ea04de` — animated two-icon switch.
- `6078ca4d73edb351a9a217c698a289b92beb8517` — refined switch design.
- `522818a260fa9454f5329f555906fecf6d56e952` — centered sun/moon and thumb geometry.

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

1. Add the actual dark onboarding images:
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
