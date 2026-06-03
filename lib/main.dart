import 'package:flutter/material.dart';
import 'package:mobile/core/theme/planora_theme.dart';
import 'package:mobile/features/auth/auth_gate.dart';
import 'package:mobile/features/onboarding/onboarding_screen.dart';
import 'package:mobile/features/reset_password/reset_password_screen.dart';

void main() {
  runApp(const PlanoraApp());
}

class PlanoraApp extends StatefulWidget {
  const PlanoraApp({super.key});

  @override
  State<PlanoraApp> createState() => _PlanoraAppState();
}

class _PlanoraAppState extends State<PlanoraApp> {
  ThemeMode _themeMode = ThemeMode.system;

  bool get _systemIsDark =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
      Brightness.dark;

  void _toggleThemeMode() {
    final isCurrentlyDark =
        _themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system && _systemIsDark);

    setState(() {
      _themeMode = isCurrentlyDark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  Widget _buildInitialScreen() {
    final uri = Uri.base;
    final isResetPasswordPath = uri.path == '/reset-password';

    if (isResetPasswordPath) {
      final email = uri.queryParameters['email'] ?? '';
      final resetToken = uri.queryParameters['token'] ?? '';

      return ResetPasswordScreen(
        onThemeToggle: _toggleThemeMode,
        email: email,
        resetToken: resetToken,
      );
    }

    return AuthGate(onThemeToggle: _toggleThemeMode, onLoggedOut: () {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Planora',
      debugShowCheckedModeBanner: false,
      theme: PlanoraTheme.lightTheme,
      darkTheme: PlanoraTheme.darkTheme,
      themeMode: _themeMode,
      home: _buildInitialScreen(),
    );
  }
}
