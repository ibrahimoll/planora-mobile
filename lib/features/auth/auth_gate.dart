import 'dart:async';
import 'dart:math' as math;

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
        child: _PlanoraStartupLoading(),
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

class _PlanoraStartupLoading extends StatefulWidget {
  const _PlanoraStartupLoading();

  @override
  State<_PlanoraStartupLoading> createState() => _PlanoraStartupLoadingState();
}

class _PlanoraStartupLoadingState extends State<_PlanoraStartupLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onSurface;

    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          final pulse = 0.985 + (math.sin(progress * math.pi * 2) * 0.025);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: pulse,
                child: SizedBox(
                  width: 104,
                  height: 104,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          strokeWidth: 3.2,
                          color: primary,
                          backgroundColor: primary.withOpacity(0.10),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Container(
                        width: 76,
                        height: 76,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primary.withOpacity(0.20),
                              blurRadius: 22,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            'assets/images/planora_logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Loading Planora...',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: textColor.withOpacity(0.72),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
