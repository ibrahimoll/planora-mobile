import 'package:flutter/material.dart';

import '../../../core/theme/planora_theme.dart';

class OnboardingDescription extends StatelessWidget {
  const OnboardingDescription({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Planora helps you plan projects,\n'
      'manage tasks, predict risks, and \n'
      'deliver successful results with \n'
      'the power of AI.',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontSize: 15,
        height: 1.5,
        color: PlanoraTheme.textSecondary,
      ),
    );
  }
}
