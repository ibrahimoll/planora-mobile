import 'dart:ui';

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
            colors: [Color(0xFFF8F7FF), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const Positioned(top: 32, right: 28, child: _DotGrid()),
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
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontSize: 16,
                                height: 1.65,
                                color: PlanoraTheme.textSecondary,
                              ),
                        ),
                        SizedBox(height: isCompactHeight ? 20 : 34),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
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
      height: compact ? 230 : 285,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.72,
                  colors: [
                    PlanoraTheme.softViolet.withValues(alpha: 0.16),
                    PlanoraTheme.softViolet.withValues(alpha: 0.055),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: compact ? 28 : 40,
            left: 10,
            right: 54,
            child: Container(
              height: compact ? 98 : 116,
              decoration: BoxDecoration(
                color: PlanoraTheme.softViolet.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: PlanoraTheme.primaryPurple.withValues(alpha: 0.08),
                    blurRadius: 44,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: compact ? 50 : 72,
            left: 9,
            right: 36,
            child: _MainGlassCard(compact: compact),
          ),
          Positioned(
            left: 58,
            bottom: compact ? 58 : 78,
            child: const _ChartGlassCard(),
          ),
          Positioned(
            top: compact ? 30 : 52,
            left: 100,
            child: const _CheckGlassCard(),
          ),
          Positioned(
            right: 4,
            top: compact ? 72 : 102,
            child: const _SparkleCluster(),
          ),
          Positioned(
            right: 20,
            bottom: compact ? 56 : 82,
            child: Opacity(
              opacity: 0.34,
              child: CustomPaint(
                size: const Size(78, 48),
                painter: _MiniChartPainter(),
              ),
            ),
          ),
          Positioned(
            left: 108,
            right: 34,
            bottom: compact ? 90 : 116,
            child: CustomPaint(
              size: const Size(double.infinity, 94),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: compact ? 142 : 166,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 52,
                offset: const Offset(0, 24),
              ),
              BoxShadow(
                color: PlanoraTheme.primaryPurple.withValues(alpha: 0.10),
                blurRadius: 58,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(86, 34, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FadedLine(width: 82, height: 10, opacity: 0.42),
                const SizedBox(height: 16),
                _FadedLine(width: 146, height: 9, opacity: 0.32),
                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: PlanoraTheme.textSecondary.withValues(alpha: 0.18),
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FadedLine extends StatelessWidget {
  final double width;
  final double height;
  final double opacity;

  const _FadedLine({
    required this.width,
    required this.height,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: PlanoraTheme.border.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _CheckGlassCard extends StatelessWidget {
  const _CheckGlassCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFA985FF), Color(0xFF5D3BDE)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.58)),
        boxShadow: [
          BoxShadow(
            color: PlanoraTheme.primaryPurple.withValues(alpha: 0.30),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 34),
    );
  }
}

class _ChartGlassCard extends StatelessWidget {
  const _ChartGlassCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(19),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
            boxShadow: [
              BoxShadow(
                color: PlanoraTheme.primaryPurple.withValues(alpha: 0.10),
                blurRadius: 36,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: CustomPaint(painter: _BarChartPainter()),
        ),
      ),
    );
  }
}

class _SparkleCluster extends StatelessWidget {
  const _SparkleCluster();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 68,
      child: Stack(
        children: [
          Positioned(
            bottom: 30,
            left: 0,
            child: Icon(
              Icons.auto_awesome_sharp,
              color: PlanoraTheme.primaryPurple.withValues(alpha: 0.82),
              size: 42,
            ),
          ),
        ],
      ),
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
    final Rect rect = Offset.zero & size;
    final Paint glowPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          PlanoraTheme.softViolet.withValues(alpha: 0.08),
          PlanoraTheme.primaryPurple.withValues(alpha: 0.18),
        ],
      ).createShader(rect)
      ..strokeWidth = 11
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);

    final Paint paint = Paint()
      ..shader = LinearGradient(
        colors: [
          PlanoraTheme.softViolet.withValues(alpha: 0.55),
          PlanoraTheme.primaryPurple.withValues(alpha: 0.78),
        ],
      ).createShader(rect)
      ..strokeWidth = 3.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path path = Path()
      ..moveTo(0, size.height * 0.78)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.60,
        size.width * 0.34,
        size.height * 0.88,
        size.width * 0.50,
        size.height * 0.58,
      )
      ..cubicTo(
        size.width * 0.66,
        size.height * 0.26,
        size.width * 0.70,
        size.height * 0.32,
        size.width * 0.82,
        size.height * 0.30,
      )
      ..cubicTo(
        size.width * 0.94,
        size.height * 0.27,
        size.width * 0.98,
        size.height * 0.10,
        size.width,
        0,
      );

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BarChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint slashPaint = Paint()
      ..color = PlanoraTheme.softViolet.withValues(alpha: 0.70)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.14, size.height * 0.78),
      Offset(size.width * 0.30, size.height * 0.62),
      slashPaint,
    );

    final List<double> heights = [0.25, 0.48, 0.70, 0.38];
    final List<double> lefts = [0.36, 0.49, 0.62, 0.75];

    for (int i = 0; i < heights.length; i++) {
      final double barWidth = size.width * 0.095;
      final double barHeight = size.height * heights[i];
      final Rect rect = Rect.fromLTWH(
        size.width * lefts[i],
        size.height * 0.76 - barHeight,
        barWidth,
        barHeight,
      );

      final Paint paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: i == 2
              ? [PlanoraTheme.primaryPurple, PlanoraTheme.deepIndigo]
              : [
                  PlanoraTheme.softViolet.withValues(alpha: 0.46),
                  PlanoraTheme.primaryPurple.withValues(alpha: 0.12),
                ],
        ).createShader(rect);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        paint,
      );
    }

    final Paint cornerPaint = Paint()
      ..color = PlanoraTheme.primaryPurple.withValues(alpha: 0.42)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.14, size.height * 0.20),
      Offset(size.width * 0.18, size.height * 0.16),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.84, size.height * 0.22),
      Offset(size.width * 0.88, size.height * 0.18),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.84, size.height * 0.80),
      Offset(size.width * 0.88, size.height * 0.84),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = const Color(0xFFB7B5C8).withValues(alpha: 0.76)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Paint dotPaint = Paint()
      ..color = const Color(0xFFB7B5C8).withValues(alpha: 0.82);

    final List<Offset> points = [
      Offset(0, size.height * 0.72),
      Offset(size.width * 0.26, size.height * 0.30),
      Offset(size.width * 0.50, size.height * 0.66),
      Offset(size.width * 0.74, size.height * 0.26),
      Offset(size.width, size.height * 0.42),
    ];

    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final Offset point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    canvas.drawPath(path, linePaint);
    for (final Offset point in points) {
      canvas.drawCircle(point, 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
