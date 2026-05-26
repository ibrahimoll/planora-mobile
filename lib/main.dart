import 'package:flutter/material.dart';
import 'package:mobile/core/theme/planora_theme.dart';
import 'package:mobile/features/onboarding/onboarding_screen.dart';

void main() {
  runApp(const PlanoraApp());
}

class PlanoraApp extends StatelessWidget {
  const PlanoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Planora',
      debugShowCheckedModeBanner: false,
      theme: PlanoraTheme.lightTheme,
      darkTheme: PlanoraTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const OnboardingScreen(),
    );
  }
}
