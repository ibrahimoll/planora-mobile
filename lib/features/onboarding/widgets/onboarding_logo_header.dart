import 'package:flutter/material.dart';

import '../../../../core/theme/planora_theme.dart';

class OnboardingLogoHeader extends StatelessWidget {
  const OnboardingLogoHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset('assets/images/planora_logo.png', width: 74, height: 74),

        const SizedBox(height: 14),

        Text(
          'Planora',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: PlanoraTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
