import 'package:flutter/material.dart';
import 'package:mobile/features/onboarding/widgets/onboarding_illustration.dart';

import '../../core/theme/planora_theme.dart';
import 'widgets/onboarding_ai_pill.dart';
import 'widgets/onboarding_description.dart';
import 'widgets/onboarding_hero_title.dart';
import 'widgets/onboarding_logo_header.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: PlanoraTheme.onboardingBackground,
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    SizedBox(height: 40),

                    OnboardingLogoHeader(),

                    SizedBox(height: 14),

                    OnboardingAiPill(),

                    SizedBox(height: 20),

                    OnboardingHeroTitle(),

                    SizedBox(height: 14),

                    OnboardingDescription(),

                    SizedBox(height: 2),

                    OnboardingIllustration(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
