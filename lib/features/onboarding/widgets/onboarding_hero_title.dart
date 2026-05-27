import 'package:flutter/material.dart';

import '../../../core/theme/planora_theme.dart';

class OnboardingHeroTitle extends StatelessWidget {
  const OnboardingHeroTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: Theme.of(context).textTheme.displayLarge?.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          height: 1.12,
          color: PlanoraTheme.textPrimary,
        ),
        children: [
          TextSpan(text: 'Plan '),
          TextSpan(
            text: 'smarter.\n',
            style: TextStyle(color: PlanoraTheme.primaryPurple),
          ),
          TextSpan(text: 'Deliver better.'),
        ],
      ),
    );
  }
}
