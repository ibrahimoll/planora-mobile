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
      duration: const Duration(milliseconds: 1500),
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
          final pulse = 0.97 + (math.sin(progress * math.pi * 2) * 0.045);
          final float = math.sin(progress * math.pi * 2) * 5;
          final counterRotation = -progress * math.pi * 2;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.translate(
                offset: Offset(0, float),
                child: Transform.scale(
                  scale: pulse,
                  child: SizedBox(
                    width: 144,
                    height: 144,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        CustomPaint(
                          size: const Size.square(144),
                          painter: _PlanoraLoadingPainter(
                            progress: progress,
                            color: primary,
                          ),
                        ),
                        Container(
                          width: 108,
                          height: 108,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(34),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFA855F7),
                                Color(0xFF7C3AED),
                                Color(0xFF4F46E5),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primary.withOpacity(0.38),
                                blurRadius: 34,
                                spreadRadius: 1,
                                offset: const Offset(0, 18),
                              ),
                              BoxShadow(
                                color: const Color(0xFF7C3AED).withOpacity(0.22),
                                blurRadius: 46,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        Transform.rotate(
                          angle: counterRotation * 0.08,
                          child: Container(
                            width: 86,
                            height: 86,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.9),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.asset(
                                'assets/images/planora_logo.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 21,
                          bottom: 20,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF9333EA), Color(0xFF6D28D9)],
                              ),
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: primary.withOpacity(0.35),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Text(
                'Preparing Planora',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
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
    final radius = size.width / 2 - 12;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final glowPaint = Paint()
      ..color = color.withOpacity(0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(center, radius - 4, glowPaint);

    final trackPaint = Paint()
      ..color = color.withOpacity(0.11)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final arcPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          color.withOpacity(0.02),
          const Color(0xFFA855F7),
          const Color(0xFF7C3AED),
          const Color(0xFF4F46E5),
          color.withOpacity(0.02),
        ],
        stops: const [0.0, 0.28, 0.58, 0.78, 1.0],
        transform: GradientRotation(progress * math.pi * 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      rect,
      -math.pi / 2 + progress * math.pi * 2,
      math.pi * 1.55,
      false,
      arcPaint,
    );

    final dotPaint = Paint()..color = const Color(0xFF7C3AED).withOpacity(0.95);
    final dotGlowPaint = Paint()
      ..color = color.withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    for (var i = 0; i < 4; i++) {
      final angle = progress * math.pi * 2 + (i * math.pi * 2 / 4);
      final dotRadius = radius - (i * 6);
      final offset = Offset(
        center.dx + math.cos(angle) * dotRadius,
        center.dy + math.sin(angle) * dotRadius,
      );
      final size = 4.8 - (i * 0.45);
      canvas.drawCircle(offset, size + 5, dotGlowPaint);
      canvas.drawCircle(offset, size, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PlanoraLoadingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
