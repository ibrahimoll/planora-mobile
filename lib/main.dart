import 'package:flutter/material.dart';
import 'package:mobile/core/theme/planora_theme.dart';
import 'package:mobile/features/onboarding/onboarding_screen.dart';

void main() {
  runApp(PlanoraApp());
}

class PlanoraApp extends StatefulWidget {
  const PlanoraApp({super.key});

  @override
  State<PlanoraApp> createState() => _PlanoraAppState();
}

class _PlanoraAppState extends State<PlanoraApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Planora',
      debugShowCheckedModeBanner: false,
      theme: PlanoraTheme.lightTheme,
      darkTheme: PlanoraTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: OnboardingScreen(),
    );
  }
}
