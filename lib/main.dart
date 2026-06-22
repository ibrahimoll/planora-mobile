import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/core/notifications/push_notification_service.dart';
import 'package:mobile/core/theme/planora_theme.dart';
import 'package:mobile/features/auth/auth_gate.dart';

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
        navigatorKey: PushNotificationService.instance.navigatorKey,
        title: 'Planora',
        debugShowCheckedModeBanner: false,
        theme: PlanoraTheme.lightTheme,
        darkTheme: PlanoraTheme.darkTheme,
        themeMode: _themeMode,
        scrollBehavior: const PlanoraScrollBehavior(),
        home: AuthGate(onThemeToggle: _toggleThemeMode),
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
