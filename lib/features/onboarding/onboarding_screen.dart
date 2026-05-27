import 'package:flutter/material.dart';
import 'package:mobile/features/onboarding/widgets/onboarding_illustration.dart';
import 'package:mobile/features/onboarding/widgets/onboarding_page_dots.dart';

import '../../core/theme/planora_theme.dart';
import 'widgets/onboarding_ai_pill.dart';
import 'widgets/onboarding_description.dart';
import 'widgets/onboarding_hero_title.dart';
import 'widgets/onboarding_logo_header.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const SizedBox(height: 40),

                    const OnboardingLogoHeader(),

                    const SizedBox(height: 14),

                    const OnboardingAiPill(),

                    const SizedBox(height: 20),

                    const OnboardingHeroTitle(),

                    const SizedBox(height: 14),

                    const OnboardingDescription(),

                    const OnboardingIllustration(),

                    OnboardingPageDot(controller: _pageController, count: 4),
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
