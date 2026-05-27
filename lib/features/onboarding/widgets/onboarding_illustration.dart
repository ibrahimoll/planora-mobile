import 'package:flutter/material.dart';
import '../../../core/theme/planora_theme.dart';

class OnboardingIllustration extends StatelessWidget {
  const OnboardingIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 22,
            right: 52,
            child: Transform.rotate(
              angle: 0.04,
              child: Container(
                width: 165,
                height: 105,
                decoration: BoxDecoration(
                  color: PlanoraTheme.primaryPurple.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: PlanoraTheme.primaryPurple.withValues(alpha: 0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
