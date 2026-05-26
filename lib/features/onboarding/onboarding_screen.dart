import 'package:flutter/material.dart';

import '../../core/theme/planora_theme.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final bool isCompactHeight = size.height < 740;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8F7FF),
              Color(0xFFFFFFFF),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const Positioned(
                top: 32,
                right: 28,
                child: _DotGrid(),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: isCompactHeight ? 34 : 66),
                        const _BrandHeader(),
                        const SizedBox(height: 18),
                        const _FeaturePill(),
                        const SizedBox(height: 28),
                        const _HeroTitle(),
                        const SizedBox(height: 18),
                        Text(
                          'Planora uses AI to help you plan projects, manage tasks, predict risks, and deliver results — on time, every time.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 16,
                                height: 1.65,
                                color: PlanoraTheme.textSecondary,
                              ),
                        ),
                        SizedBox(height: isCompactHeight ? 24 : 38),
                        _OnboardIllustration(compact: isCompactHeight),
                        const Spacer(),
                        const _PrimaryGradientButton(),
                        SizedBox(height: isCompactHeight ? 14 : 28),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: PlanoraTheme.primaryGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: PlanoraTheme.primaryPurple.withValues(alpha: 0.22),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Image.asset('assets/images/planora_logo.png'),
        ),
        const SizedBox(width: 12),
        Text(
          'Planora',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
        ),
      ],
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: PlanoraTheme.lavenderGlow.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.72),
        ),
      ),
      child: Text(
        'AI-POWERED PROJECT PLANNING',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: PlanoraTheme.primaryPurple,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.35,
            ),
      ),
    );
  }
}

class _HeroTitle extends StatelessWidget {
  const _HeroTitle();

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: 38,
              height: 1.04,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.4,
              color: PlanoraTheme.textPrimary,
            ),
        children: const [
          TextSpan(text: 'Plan '),
          TextSpan(
            text: 'smarter.\n',
            style: TextStyle(color: PlanoraTheme.primaryPurple),
          ),
          TextSpan(text: 'Deliver better.'),
        ],
      ),
    );
  }
}

class _OnboardIllustration extends StatelessWidget {
  final bool compact;

  const _OnboardIllustration({required this.compact});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 215 : 260,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 320,
            height: 230,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  PlanoraTheme.softViolet.withValues(alpha: 0.20),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Positioned(
            left: 78,
            top: compact ? 34 : 42,
            child: Container(
              width: 210,
              height: 92,
              decoration: BoxDecoration(
                color: PlanoraTheme.softViolet.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            top: compact ? 58 : 76,
            left: 118,
            right: 30,
            child: _MainGlassCard(compact: compact),
          ),
          Positioned(
            left: 18,
            bottom: compact ? 48 : 64,
            child: const _FloatingMiniCard(
              icon: Icons.bar_chart_rounded,
              color: PlanoraTheme.info,
              size: 60,
            ),
          ),
          Positioned(
            top: compact ? 26 : 36,
            left: 72,
            child: const _FloatingMiniCard(
              icon: Icons.check_rounded,
              color: PlanoraTheme.primaryPurple,
              size: 62,
            ),
          ),
          Positioned(
            right: 18,
            top: compact ? 76 : 98,
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: PlanoraTheme.softViolet,
              size: 38,
            ),
          ),
          Positioned(
            right: 76,
            bottom: compact ? 46 : 62,
            child: Opacity(
              opacity: 0.28,
              child: CustomPaint(
                size: const Size(64, 42),
                painter: _MiniChartPainter(),
              ),
            ),
          ),
          Positioned(
            bottom: compact ? 78 : 96,
            left: 108,
            right: 32,
            child: CustomPaint(
              size: const Size(230, 76),
              painter: _CurvePainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MainGlassCard extends StatelessWidget {
  final bool compact;

  const _MainGlassCard({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 138 : 150,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 38,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: PlanoraTheme.primaryPurple.withValues(alpha: 0.08),
            blurRadius: 34,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 82,
              height: 9,
              decoration: BoxDecoration(
                color: PlanoraTheme.border.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: 142,
              height: 8,
              decoration: BoxDecoration(
                color: PlanoraTheme.divider.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: Icon(
                Icons.chevron_right_rounded,
                color: PlanoraTheme.textSecondary.withValues(alpha: 0.22),
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingMiniCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _FloatingMiniCard({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 30),
    );
  }
}

class _PrimaryGradientButton extends StatelessWidget {
  const _PrimaryGradientButton();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: PlanoraTheme.primaryGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: PlanoraTheme.primaryPurple.withValues(alpha: 0.30),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: ElevatedButton(
          onPressed: () {
            // TODO: Navigate to the register or main auth flow.
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: const Text('Get Started'),
        ),
      ),
    );
  }
}

class _DotGrid extends StatelessWidget {
  const _DotGrid();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.34,
      child: Column(
        children: List.generate(
          5,
          (_) => Row(
            children: List.generate(
              4,
              (_) => Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: PlanoraTheme.softViolet,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          PlanoraTheme.softViolet,
          PlanoraTheme.primaryPurple,
        ],
      ).createShader(Offset.zero & size)
      ..strokeWidth = 4.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path path = Path()
      ..moveTo(0, size.height * 0.68)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.26,
        size.width * 0.48,
        size.height * 0.83,
        size.width * 0.68,
        size.height * 0.42,
      )
      ..cubicTo(
        size.width * 0.82,
        size.height * 0.14,
        size.width * 0.92,
        size.height * 0.22,
        size.width,
        0,
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = PlanoraTheme.textSecondary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Paint dotPaint = Paint()..color = PlanoraTheme.textSecondary;

    final List<Offset> points = [
      Offset(0, size.height * 0.72),
      Offset(size.width * 0.24, size.height * 0.48),
      Offset(size.width * 0.45, size.height * 0.62),
      Offset(size.width * 0.72, size.height * 0.22),
      Offset(size.width, size.height * 0.36),
    ];

    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final Offset point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    canvas.drawPath(path, linePaint);
    for (final Offset point in points) {
      canvas.drawCircle(point, 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
