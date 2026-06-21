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
      duration: const Duration(milliseconds: 1400),
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
          final pulse = 0.94 + (math.sin(progress * math.pi * 2) * 0.06);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: pulse,
                child: SizedBox(
                  width: 112,
                  height: 112,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size.square(112),
                        painter: _PlanoraLoadingPainter(
                          progress: progress,
                          color: primary,
                        ),
                      ),
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primary.withOpacity(0.35),
                              blurRadius: 26,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Planora is getting ready',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Loading your workspace...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor.withOpacity(0.62),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlanoraLoadingPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _PlanoraLoadingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 9;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = color.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final arcPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          color.withOpacity(0.08),
          color,
          const Color(0xFF9333EA),
          color.withOpacity(0.08),
        ],
        stops: const [0.0, 0.45, 0.72, 1.0],
        transform: GradientRotation(progress * math.pi * 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      rect,
      -math.pi / 2 + progress * math.pi * 2,
      math.pi * 1.45,
      false,
      arcPaint,
    );

    final dotPaint = Paint()..color = color.withOpacity(0.92);
    final glowPaint = Paint()
      ..color = color.withOpacity(0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    for (var i = 0; i < 3; i++) {
      final angle = progress * math.pi * 2 + (i * math.pi * 2 / 3);
      final dotRadius = radius - (i * 7);
      final offset = Offset(
        center.dx + math.cos(angle) * dotRadius,
        center.dy + math.sin(angle) * dotRadius,
      );
      canvas.drawCircle(offset, 8 - i.toDouble(), glowPaint);
      canvas.drawCircle(offset, 3.5 - (i * 0.35), dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PlanoraLoadingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
