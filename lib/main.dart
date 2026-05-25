import 'package:flutter/material.dart';
import 'core/theme/planora_theme.dart';
import 'features/onboarding/onboarding_screen.dart';

void main() {
  runApp(PlanoraApp());
}

class PlanoraApp extends StatefulWidget {
  const PlanoraApp({super.key});

  @override
  State<PlanoraApp> createState() => PlanoraState();
}

class PlanoraState extends State<PlanoraApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Planora',
      debugShowCheckedModeBanner: false,
      theme: PlanoraTheme.light,
      darkTheme: PlanoraTheme.dark,
      themeMode: ThemeMode.system,
      home: OnboardingScreen(),
    );
  }
}
