import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/core/notifications/push_notification_service.dart';
import 'package:mobile/core/theme/planora_theme.dart';
import 'package:mobile/features/auth/auth_gate.dart';
import 'package:mobile/features/reset_password/reset_password_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  unawaited(PushNotificationService.instance.initialize());
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

    return AuthGate(onThemeToggle: _toggleThemeMode);
  }

  SystemUiOverlayStyle _systemOverlayStyle() {
    final isDark =
        _themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system && _systemIsDark);

    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemOverlayStyle(),
      child: MaterialApp(
        title: 'Planora',
        debugShowCheckedModeBanner: false,
        theme: PlanoraTheme.lightTheme,
        darkTheme: PlanoraTheme.darkTheme,
        themeMode: _themeMode,
        scrollBehavior: const PlanoraScrollBehavior(),
        home: _buildInitialScreen(),
      ),
    );
  }
}

class PlanoraScrollBehavior extends MaterialScrollBehavior {
  const PlanoraScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}
