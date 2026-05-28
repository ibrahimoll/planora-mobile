# Planora Mobile Memory

Last updated: 2026-05-28

## Main mobile app direction

Planora Mobile is the user/team-member app for the Planora AI-powered project planning and collaboration system. The admin dashboard is separate. No guest should pass authentication.

The mobile app should keep a clean, modern, professional, friendly light-mode purple identity.

Core visual style:
- Light background
- Purple primary actions
- Soft rounded cards
- Smooth spacing
- Minimal icons
- Clean SaaS/mobile feel
- Subtle animations, not heavy or distracting

## Current design direction

Use the uploaded mobile UI reference as the current visual direction.

Important theme colors used in the app:
- Primary purple: `#6D28D9`
- Secondary purple: `#7C3AED`
- Background: `#F8FAFC`
- Surface: `#FFFFFF`
- Main text: `#1E1B4B`
- Secondary text: `#4B5563`
- Border: `#E5E7EB`

Fonts in the current theme:
- Plus Jakarta Sans for headings
- Inter for body text

## Animation rule

The app should include animations as part of the UI direction.

Use subtle animations for:
- Onboarding transitions
- Button press feedback
- Screen/page transitions
- Loading states
- AI assistant typing/loading
- Dashboard cards appearing
- Task/project progress updates
- Notifications
- Empty states

Preferred Flutter animation tools:
- `AnimatedContainer`
- `AnimatedOpacity`
- `AnimatedSwitcher`
- `TweenAnimationBuilder`
- `Hero`
- subtle route transitions
- Lottie only where it improves the screen

Animation style:
- Smooth
- Clean
- Soft
- Professional
- Not distracting

## Current onboarding state

Onboarding is currently image-based, not custom-drawn Flutter illustration-based.

Current onboarding pages:
1. `Plan smarter. Deliver better.`
2. `AI-Powered Planning`
3. `Collaborate Effortlessly`
4. `Ready to Achieve More?`

Current onboarding image assets:
- `assets/images/onboarding_1.png`
- `assets/images/onboarding_2.png`
- `assets/images/onboarding_3.png`
- `assets/images/onboarding_4.png`

Important onboarding notes:
- Page 1 has the Planora logo and title in one centered row.
- Page 1 uses the AI-powered planning pill.
- Pages 2 and 3 use larger/cropped images.
- Page 4 is the final conversion page.
- Page dots are kept.
- Buttons are custom-sized inside onboarding and should not rely fully on the global button height.
- The onboarding buttons were reduced because the global theme button height felt too large on a real phone.

Current onboarding button sizing is controlled by:
`lib/features/onboarding/utils/onboarding_responsive_metrics.dart`

Current onboarding flow file:
`lib/features/onboarding/onboarding_screen.dart`

## Current onboarding folder structure

Expected structure:

```txt
lib/features/onboarding/
├── onboarding_screen.dart
├── data/
│   └── onboarding_pages.dart
├── models/
│   └── onboarding_page_data.dart
├── utils/
│   └── onboarding_responsive_metrics.dart
└── widgets/
    ├── image_onboarding_page.dart
    ├── intro_onboarding_page.dart
    ├── onboarding_image.dart
    ├── onboarding_page_dot.dart
    └── onboarding_small_widgets.dart
```

Folder purpose:
- `onboarding_screen.dart`: page controller, current page state, buttons, and screen flow
- `data/`: actual onboarding page content
- `models/`: onboarding data model and page type enum
- `utils/`: responsive sizing calculations
- `widgets/`: reusable onboarding UI components

## Current onboarding implementation rules

Keep onboarding clean and understandable:
- Do not put all code back into one huge file.
- Keep page content in `data/onboarding_pages.dart`.
- Keep responsive numbers in `utils/onboarding_responsive_metrics.dart`.
- Keep reusable UI widgets in `widgets/`.
- Keep `onboarding_screen.dart` focused on flow only.

Use public names for widgets/classes that are imported by other files. Do not use `_PrivateName` for classes that need to be imported from another file.

## Current next step

After onboarding is stable, move to authentication UI screens in this order:
1. Login screen
2. Register screen
3. Email verification screen
4. Forgot password screen
5. Reset password screen

The onboarding buttons currently show temporary snackbars. Later they should navigate:
- `Create Account` / final primary action -> Register screen
- `Sign In` / `I Already Have an Account` -> Login screen

## Auth/backend integration notes

Backend authentication is already implemented in the Planora backend and uses protected routes. Mobile auth screens should eventually connect to:
- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/verify-email`
- `POST /auth/resend-verification-code`
- `POST /auth/forgot-password`
- `POST /auth/reset-password`
- `POST /auth/google`
- `GET /auth/me`

Important rule:
- Protected mobile screens must require an active and email-verified user.

## Development rules for future mobile work

Before major mobile work:
- Check this file.
- Check `ibrahimoll/planora-backend/docs/PLANORA_CONTEXT.md` for current backend/project status.
- Keep UI consistent with Planora purple design.
- Keep screens responsive for real phone testing.
- Use animations subtly.
- Avoid hardcoding too many fixed sizes directly inside screens; prefer responsive metrics or reusable components.

## Do not store here

Do not store secrets, tokens, API keys, Gmail app passwords, Firebase private keys, JWTs, or real OAuth tokens in this file.
