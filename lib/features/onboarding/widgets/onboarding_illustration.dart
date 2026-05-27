import 'package:flutter/material.dart';

class OnboardingIllustration extends StatelessWidget {
  const OnboardingIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 380,
      alignment: Alignment.center,
      child: Image.asset(
        'assets/images/onboarding_1.png',
        width: 390,
        fit: BoxFit.contain,
      ),
    );
  }
}
