import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/core/notifications/push_notification_service.dart';
import 'package:mobile/core/theme/planora_theme.dart';
import 'package:mobile/features/auth/auth_gate.dart';
import 'package:mobile/features/reset_password/reset_password_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  await PushNotificationService.instance.initialize();

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

  bool _isResetPasswordPath(String path) {
    final normalizedPath = path.trim().toLowerCase();
    return normalizedPath == '/reset-password' ||
        normalizedPath == '/reset-password/';
  }

  Uri? _resetPasswordUriFrom(Uri uri) {
    if (_isResetPasswordPath(uri.path)) {
      return uri;
    }

    final fragment = uri.fragment.trim();
    if (fragment.isEmpty) {
      return null;
    }

    final fragmentUri = Uri.tryParse(
      fragment.startsWith('/') ? fragment : '/$fragment',
    );

    if (fragmentUri != null && _isResetPasswordPath(fragmentUri.path)) {
      return fragmentUri;
    }

    return null;
  }

  Widget _buildInitialScreen() {
    final resetUri = _resetPasswordUriFrom(Uri.base);

    if (resetUri != null) {
      final email = resetUri.queryParameters['email'] ?? '';
      final resetToken = resetUri.queryParameters['token'] ?? '';

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
