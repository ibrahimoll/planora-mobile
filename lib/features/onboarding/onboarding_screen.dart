import 'package:flutter/material.dart';

import '../../core/theme/planora_theme.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PlanoraTheme.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsetsGeometry.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Spacer(),

              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: PlanoraTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Image.asset('assets/images/planora_logo.png'),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Planora',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
              SizedBox(height: 18),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: PlanoraTheme.lavenderGlow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'AI-Powered Project Planing',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: PlanoraTheme.primaryPurple,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .5,
                  ),
                ),
              ),
              SizedBox(height: 26),
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.displayLarge,
                  children: [
                    TextSpan(text: 'Plan '),
                    TextSpan(
                      text: 'smarter. \n',
                      style: TextStyle(color: PlanoraTheme.primaryPurple),
                    ),
                    TextSpan(text: 'Delivery better.'),
                  ],
                ),
              ),
              SizedBox(height: 18),
              Text(
                'Planora uses AI to help you plan projects, manage tasks, predict risks, and deliver results - on time, every time',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: 42),

              const _OnboardIllustration(),

              Spacer(),

              ElevatedButton(
                onPressed: () {
                  //TODO" Navigate to the register or main auth flow
                },
                child: Text('Get Started'),
              ),
              SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardIllustration extends StatelessWidget {
  const _OnboardIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 220,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: PlanoraTheme.radiusLarge,
              boxShadow: PlanoraTheme.floatingShadow,
              border: Border.all(color: PlanoraTheme.border),
            ),
          ),
          Positioned(
            left: 18,
            bottom: 34,
            child: _FloatingMiniCard(
              icon: Icons.bar_chart_rounded,
              color: PlanoraTheme.info,
            ),
          ),
          Positioned(
            top: 8,
            left: 72,
            child: _FloatingMiniCard(
              icon: Icons.check_rounded,
              color: PlanoraTheme.primaryPurple,
            ),
          ),
          Positioned(
            right: 18,
            top: 48,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: PlanoraTheme.softViolet,
              size: 34,
            ),
          ),
          Positioned(
            bottom: 58,
            child: CustomPaint(
              size: const Size(230, 70),
              painter: _CurvePainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingMiniCard extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _FloatingMiniCard({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: PlanoraTheme.cardShadow,
      ),
      child: Icon(icon, color: color, size: 30),
    );
  }
}

class _CurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = PlanoraTheme.softViolet
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path path = Path()
      ..moveTo(0, size.height * 0.65)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.25,
        size.width * 0.5,
        size.height * 0.95,
        size.width * 0.75,
        size.height * 0.35,
      )
      ..cubicTo(
        size.width * 0.86,
        size.height * 0.12,
        size.width * 0.95,
        size.height * 0.18,
        size.width,
        0,
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
