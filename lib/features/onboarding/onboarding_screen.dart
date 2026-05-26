import 'package:flutter/material.dart';

import '../../core/theme/planora_theme.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PlanoraTheme.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsetsGeometry.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Spacer(),

              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: PlanoraTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Image.asset('assets/images/planora_logo.png'),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Planora',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
              SizedBox(height: 18),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: PlanoraTheme.lavenderGlow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'AI-Powered Project Planing',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: PlanoraTheme.primaryPurple,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .5,
                  ),
                ),
              ),
              SizedBox(height: 26),
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.displayLarge,
                  children: [
                    TextSpan(text: 'Plan '),
                    TextSpan(
                      text: 'smarter. \n',
                      style: TextStyle(color: PlanoraTheme.primaryPurple),
                    ),
                    TextSpan(text: 'Delivery better.'),
                  ],
                ),
              ),
              SizedBox(height: 42),
              const _OnboardIllustration(),
              Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardIllustration extends StatelessWidget {
  const _OnboardIllustration();

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
