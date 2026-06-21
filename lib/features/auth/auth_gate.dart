import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/features/home/home_screen.dart';
import 'package:mobile/features/onboarding/onboarding_screen.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/api_client.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../core/storage/token_storage.dart';
import '../../core/ui/planora_ui.dart';
import 'data/auth_api.dart';
import 'models/auth_models.dart';

class AuthGate extends StatefulWidget {
  final VoidCallback onThemeToggle;

  const AuthGate({super.key, required this.onThemeToggle});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool isLoading = true;
  UserResponse? currentUser;

  @override
  void initState() {
    super.initState();
    ApiClient.onUnauthorized = _handleUnauthorizedSession;
    _checkSession();
  }

  @override
  void dispose() {
    ApiClient.onUnauthorized = null;
    super.dispose();
  }

  Future<void> _checkSession() async {
    try {
      final hasToken = await TokenStorage.hasAccessToken()
          .timeout(const Duration(seconds: 6));

      if (!hasToken) {
        if (!mounted) return;

        setState(() {
          currentUser = null;
          isLoading = false;
        });

        return;
      }

      final user = await AuthApi.getCurrentUser()
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;

      setState(() {
        currentUser = user;
        isLoading = false;
      });

      unawaited(_registerPushDeviceAfterSessionRestore());
    } on TimeoutException catch (error, stackTrace) {
      debugPrint('AuthGate session check timed out: $error');
      debugPrintStack(stackTrace: stackTrace);
      await TokenStorage.clearAccessToken();

      if (!mounted) return;

      setState(() {
        currentUser = null;
        isLoading = false;
      });
    } on ApiException catch (error, stackTrace) {
      debugPrint('AuthGate current user load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      await TokenStorage.clearAccessToken();

      if (!mounted) return;

      setState(() {
        currentUser = null;
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('AuthGate session check failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      await TokenStorage.clearAccessToken();

      if (!mounted) return;

      setState(() {
        currentUser = null;
        isLoading = false;
      });
    }
  }

  Future<void> _registerPushDeviceAfterSessionRestore() async {
    try {
      await PushNotificationService.instance
          .registerCurrentDevice()
          .timeout(const Duration(seconds: 8));
    } catch (error, stackTrace) {
      debugPrint('Push registration after session restore failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _handleUnauthorizedSession() async {
    await PushNotificationService.instance.clearLocalPushTokenState();
    await TokenStorage.clearAccessToken();

    if (!mounted) return;

    setState(() {
      currentUser = null;
      isLoading = false;
    });
  }

  Future<void> _logout() async {
    try {
      await PushNotificationService.instance.deactivateCurrentDevice();
    } catch (error, stackTrace) {
      debugPrint('Push token cleanup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    await TokenStorage.clearAccessToken();

    if (!mounted) return;

    setState(() {
      currentUser = null;
      isLoading = false;
    });
  }

  void _updateCurrentUser(UserResponse user) {
    setState(() {
      currentUser = user;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const PlanoraScaffold(
        child: PlanoraLoadingState(message: 'Loading Planora...'),
      );
    }

    final user = currentUser;

    if (user == null) {
      return OnboardingScreen(onThemeToggle: widget.onThemeToggle);
    }

    return HomeScreen(
      user: user,
      onThemeToggle: widget.onThemeToggle,
      onLoggedOut: _logout,
      onUserUpdated: _updateCurrentUser,
    );
  }
}
