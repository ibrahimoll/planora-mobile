import 'package:flutter/material.dart';

import '../../../core/theme/planora_theme.dart';

class OnboardingAiPill extends StatelessWidget {
  const OnboardingAiPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: PlanoraTheme.lavenderGlow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'AI-POWERED PROJECT PLANNING',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: .5,
          color: PlanoraTheme.textSecondary,
        ),
      ),
    );
  }
}
