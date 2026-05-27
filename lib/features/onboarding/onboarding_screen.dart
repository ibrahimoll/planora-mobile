import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../core/theme/planora_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const List<_OnboardingPageData> _pages = [
    _OnboardingPageData.intro(
      title: 'Plan smarter.\nDeliver better.',
      highlightedText: 'smarter.',
      description:
          'Planora helps you plan projects, manage tasks, predict risks, and deliver successful results with the power of AI.',
      imageAsset: 'assets/images/onboarding_1.png',
    ),
    _OnboardingPageData.feature(
      title: 'AI-Powered Planning',
      description:
          'Let AI break down your ideas into clear plans, smart tasks, and realistic timelines in seconds.',
      icon: Icons.auto_awesome_rounded,
      visualType: _FeatureVisualType.projectPlan,
    ),
    _OnboardingPageData.feature(
      title: 'Collaborate Effortlessly',
      description:
          'Work together in real-time. Assign tasks, share files, comment, and keep everyone on the same page.',
      icon: Icons.groups_rounded,
      visualType: _FeatureVisualType.teamWorkspace,
    ),
    _OnboardingPageData.finalPage(
      title: 'Ready to Achieve More?',
      description:
          'Join thousands of teams and professionals who plan smarter and deliver better with Planora.',
      icon: Icons.rocket_launch_rounded,
    ),
  ];

  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool get _isFirstPage => _currentPage == 0;
  bool get _isFinalPage => _pages[_currentPage].isFinal;
  bool get _showSecondaryButton => _isFirstPage || _isFinalPage;

  String get _primaryButtonLabel {
    if (_isFirstPage) return 'Get Started';
    if (_isFinalPage) return 'Create Account';
    return 'Next';
  }

  String get _secondaryButtonLabel {
    if (_isFinalPage) return 'I Already Have an Account';
    return 'Sign In';
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Create account coming next')));
  }

  void _goToSignIn() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sign in screen coming next')));
  }

  void _skipOnboarding() {
    _pageController.animateToPage(
      _pages.length - 1,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: PlanoraTheme.onboardingBackground,
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _pages.length,
                        onPageChanged: (index) {
                          setState(() => _currentPage = index);
                        },
                        itemBuilder: (context, index) {
                          final page = _pages[index];

                          if (page.isIntro) {
                            return _IntroOnboardingPage(data: page);
                          }

                          if (page.isFinal) {
                            return _FinalOnboardingPage(data: page);
                          }

                          return _FeatureOnboardingPage(
                            data: page,
                            onSkip: _skipOnboarding,
                          );
                        },
                      ),
                    ),
                    OnboardingPageDot(
                      controller: _pageController,
                      count: _pages.length,
                    ),
                    const SizedBox(height: 28),
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: PlanoraTheme.primaryGradient,
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        boxShadow: PlanoraTheme.floatingShadow,
                      ),
                      child: ElevatedButton(
                        onPressed: _goToNextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                        ),
                        child: Text(_primaryButtonLabel),
                      ),
                    ),
                    if (_showSecondaryButton) ...[
                      const SizedBox(height: 14),
                      OutlinedButton(
                        onPressed: _goToSignIn,
                        child: Text(_secondaryButtonLabel),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingPageDot extends StatelessWidget {
  final PageController controller;
  final int count;

  const OnboardingPageDot({
    super.key,
    required this.controller,
    this.count = 4,
  });

  @override
  Widget build(BuildContext context) {
    return SmoothPageIndicator(
      controller: controller,
      count: count,
      effect: const ExpandingDotsEffect(
        dotHeight: 8,
        dotWidth: 8,
        activeDotColor: PlanoraTheme.primaryPurple,
        dotColor: PlanoraTheme.border,
        spacing: 8,
        radius: 100,
        expansionFactor: 3.4,
      ),
      onDotClicked: (index) {
        controller.animateToPage(
          index,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
        );
      },
    );
  }
}

class _IntroOnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;

  const _IntroOnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 44),
          Image.asset('assets/images/planora_logo.png', width: 76, height: 76),
          const SizedBox(height: 14),
          Text(
            'Planora',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: PlanoraTheme.textPrimary,
                ),
          ),
          const SizedBox(height: 14),
          const _AiPill(),
          const SizedBox(height: 22),
          _HeroTitle(title: data.title, highlightedText: data.highlightedText),
          const SizedBox(height: 16),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 15,
                  height: 1.55,
                  color: PlanoraTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 220,
            child: Center(
              child: Image.asset(
                data.imageAsset!,
                width: 320,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _FeatureOnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;
  final VoidCallback onSkip;

  const _FeatureOnboardingPage({required this.data, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 18),
        SizedBox(
          height: 34,
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onSkip,
              style: TextButton.styleFrom(
                foregroundColor: PlanoraTheme.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Skip'),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _FeatureVisual(type: data.visualType),
                const SizedBox(height: 48),
                _IconBadge(icon: data.icon),
                const SizedBox(height: 26),
                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: PlanoraTheme.textPrimary,
                      ),
                ),
                const SizedBox(height: 14),
                Text(
                  data.description,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 15,
                        height: 1.55,
                        color: PlanoraTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FinalOnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;

  const _FinalOnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 52),
          const _RocketVisual(),
          const SizedBox(height: 38),
          _IconBadge(icon: data.icon),
          const SizedBox(height: 26),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: PlanoraTheme.textPrimary,
                ),
          ),
          const SizedBox(height: 14),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 15,
                  height: 1.55,
                  color: PlanoraTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _HeroTitle extends StatelessWidget {
  final String title;
  final String highlightedText;

  const _HeroTitle({required this.title, required this.highlightedText});

  @override
  Widget build(BuildContext context) {
    final parts = title.split(highlightedText);
    final baseStyle = Theme.of(context).textTheme.displayLarge?.copyWith(
          fontSize: 33,
          fontWeight: FontWeight.w800,
          height: 1.1,
          color: PlanoraTheme.textPrimary,
        );

    if (parts.length != 2) {
      return Text(title, textAlign: TextAlign.center, style: baseStyle);
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: parts.first),
          TextSpan(
            text: highlightedText,
            style: const TextStyle(color: PlanoraTheme.primaryPurple),
          ),
          TextSpan(text: parts.last),
        ],
      ),
    );
  }
}

class _AiPill extends StatelessWidget {
  const _AiPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: PlanoraTheme.lavenderGlow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'AI-POWERED PROJECT PLANNING',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .5,
              color: PlanoraTheme.textSecondary,
            ),
      ),
    );
  }
}

class _FeatureVisual extends StatelessWidget {
  final _FeatureVisualType type;

  const _FeatureVisual({required this.type});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 238,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 230,
            height: 230,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xFFEDE7FF), Color(0x00EDE7FF)],
              ),
            ),
          ),
          switch (type) {
            _FeatureVisualType.projectPlan => const _ProjectPlanVisual(),
            _FeatureVisualType.teamWorkspace => const _TeamWorkspaceVisual(),
          },
        ],
      ),
    );
  }
}

class _ProjectPlanVisual extends StatelessWidget {
  const _ProjectPlanVisual();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 302,
      height: 218,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            top: 0,
            right: 10,
            child: _FloatingIcon(icon: Icons.auto_awesome_rounded),
          ),
          Positioned(
            top: 16,
            left: 0,
            right: 32,
            child: _GlassCard(
              height: 176,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _CardTitle('Project Plan'),
                  SizedBox(height: 12),
                  _PlanTaskRow(label: 'Research', isDone: true),
                  SizedBox(height: 8),
                  _PlanTaskRow(label: 'Design', isDone: true),
                  SizedBox(height: 8),
                  _PlanTaskRow(label: 'Development'),
                  SizedBox(height: 8),
                  _PlanTaskRow(label: 'Testing'),
                ],
              ),
            ),
          ),
          const Positioned(
            right: 20,
            bottom: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _MiniBar(height: 28),
                SizedBox(width: 8),
                _MiniBar(height: 42),
                SizedBox(width: 8),
                _MiniBar(height: 58),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamWorkspaceVisual extends StatelessWidget {
  const _TeamWorkspaceVisual();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 306,
      height: 218,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            bottom: 10,
            left: 0,
            child: _FloatingIcon(icon: Icons.person_rounded),
          ),
          const Positioned(
            top: 0,
            right: 2,
            child: _FloatingIcon(icon: Icons.chat_bubble_rounded),
          ),
          Positioned(
            top: 16,
            left: 26,
            right: 14,
            child: _GlassCard(
              height: 202,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _CardTitle('Team Workspace'),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      _AvatarBubble(label: 'I'),
                      SizedBox(width: 4),
                      _AvatarBubble(label: 'M'),
                      SizedBox(width: 4),
                      _AvatarBubble(label: 'A'),
                      SizedBox(width: 4),
                      _AvatarBubble(label: '+3', small: true),
                    ],
                  ),
                  SizedBox(height: 13),
                  _ActivityRow(
                    icon: Icons.edit_rounded,
                    title: 'Design phase updated',
                    time: '2m ago',
                  ),
                  SizedBox(height: 8),
                  _ActivityRow(
                    icon: Icons.assignment_ind_rounded,
                    title: 'Task assigned to you',
                    time: '5m ago',
                  ),
                  SizedBox(height: 8),
                  _ActivityRow(
                    icon: Icons.upload_file_rounded,
                    title: 'File uploaded',
                    time: '10m ago',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RocketVisual extends StatelessWidget {
  const _RocketVisual();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 330,
      child: Center(
        child: SizedBox(
          width: 310,
          height: 310,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 248,
                height: 248,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0xFFEDE7FF), Color(0x00EDE7FF)],
                  ),
                ),
              ),
              Positioned(
                left: 22,
                top: 112,
                child: _Star(size: 18, color: PlanoraTheme.primaryPurple),
              ),
              Positioned(
                right: 40,
                top: 136,
                child: _Star(size: 16, color: PlanoraTheme.primaryPurple),
              ),
              Positioned(
                left: 82,
                bottom: 46,
                child: _Cloud(width: 88, height: 42),
              ),
              Positioned(
                right: 38,
                bottom: 52,
                child: _Cloud(width: 96, height: 46),
              ),
              CustomPaint(
                size: const Size(250, 250),
                painter: _RocketPainter(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;

  const _IconBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: PlanoraTheme.primaryLight,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: PlanoraTheme.primaryPurple, size: 28),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final double height;
  final Widget child;

  const _GlassCard({required this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(238),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PlanoraTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1C6D28D9),
            blurRadius: 28,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _FloatingIcon extends StatelessWidget {
  final IconData icon;

  const _FloatingIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        gradient: PlanoraTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: PlanoraTheme.floatingShadow,
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}

class _CardTitle extends StatelessWidget {
  final String text;

  const _CardTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: PlanoraTheme.textPrimary,
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _PlanTaskRow extends StatelessWidget {
  final String label;
  final bool isDone;

  const _PlanTaskRow({required this.label, this.isDone = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: isDone ? PlanoraTheme.primaryPurple : PlanoraTheme.border,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: PlanoraTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: PlanoraTheme.divider,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  final double height;

  const _MiniBar({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: height,
      decoration: BoxDecoration(
        gradient: PlanoraTheme.primaryGradient,
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  final String label;
  final bool small;

  const _AvatarBubble({required this.label, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: small ? 25 : 28,
      height: small ? 25 : 28,
      decoration: BoxDecoration(
        color: small ? PlanoraTheme.primaryLight : PlanoraTheme.secondaryPurple,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: small ? PlanoraTheme.primaryPurple : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String time;

  const _ActivityRow({
    required this.icon,
    required this.title,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PlanoraTheme.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: PlanoraTheme.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: PlanoraTheme.primaryPurple, size: 14),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: PlanoraTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
              ),
            ),
            Text(
              time,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 9,
                    color: PlanoraTheme.textMuted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Star extends StatelessWidget {
  final double size;
  final Color color;

  const _Star({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.auto_awesome_rounded,
      size: size,
      color: color.withAlpha(140),
    );
  }
}

class _Cloud extends StatelessWidget {
  final double width;
  final double height;

  const _Cloud({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: _CloudCircle(size: height * .72),
          ),
          Positioned(
            left: width * .24,
            bottom: height * .08,
            child: _CloudCircle(size: height),
          ),
          Positioned(
            right: width * .18,
            bottom: 0,
            child: _CloudCircle(size: height * .82),
          ),
          Positioned(
            right: 0,
            bottom: height * .04,
            child: _CloudCircle(size: height * .6),
          ),
        ],
      ),
    );
  }
}

class _CloudCircle extends StatelessWidget {
  final double size;

  const _CloudCircle({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(238),
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
    );
  }
}

class _RocketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2 + 2);
    canvas.rotate(0.58);

    final shadowPaint = Paint()
      ..color = const Color(0x246D28D9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-28, -88, 56, 154),
        const Radius.circular(30),
      ),
      shadowPaint,
    );

    final flamePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFF7ED), Color(0xFFFFD6A5)],
      ).createShader(const Rect.fromLTWH(-12, 62, 24, 56));
    final flamePath = Path()
      ..moveTo(-13, 62)
      ..quadraticBezierTo(0, 124, 13, 62)
      ..close();
    canvas.drawPath(flamePath, flamePaint);

    final leftFin = Path()
      ..moveTo(-28, 34)
      ..lineTo(-76, 76)
      ..quadraticBezierTo(-50, 18, -24, 8)
      ..close();
    canvas.drawPath(leftFin, Paint()..color = PlanoraTheme.secondaryPurple);

    final rightFin = Path()
      ..moveTo(28, 34)
      ..lineTo(76, 76)
      ..quadraticBezierTo(50, 18, 24, 8)
      ..close();
    canvas.drawPath(rightFin, Paint()..color = PlanoraTheme.primaryPurple);

    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Color(0xFFEDE9FE)],
      ).createShader(const Rect.fromLTWH(-32, -92, 64, 158));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-32, -86, 64, 152),
        const Radius.circular(36),
      ),
      bodyPaint,
    );

    final nosePath = Path()
      ..moveTo(-28, -56)
      ..quadraticBezierTo(0, -118, 28, -56)
      ..close();
    canvas.drawPath(nosePath, Paint()..color = PlanoraTheme.secondaryPurple);

    canvas.drawCircle(
      const Offset(0, -26),
      19,
      Paint()..color = PlanoraTheme.primaryPurple,
    );
    canvas.drawCircle(
      const Offset(0, -26),
      13,
      Paint()..color = const Color(0xFFC4B5FD),
    );

    final linePaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-32, -86, 64, 152),
        const Radius.circular(36),
      ),
      linePaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum _OnboardingPageKind { intro, feature, finalPage }

enum _FeatureVisualType { projectPlan, teamWorkspace }

class _OnboardingPageData {
  final _OnboardingPageKind kind;
  final String title;
  final String highlightedText;
  final String description;
  final String? imageAsset;
  final IconData icon;
  final _FeatureVisualType visualType;

  bool get isIntro => kind == _OnboardingPageKind.intro;
  bool get isFinal => kind == _OnboardingPageKind.finalPage;

  const _OnboardingPageData.intro({
    required this.title,
    required this.highlightedText,
    required this.description,
    required this.imageAsset,
  }) : kind = _OnboardingPageKind.intro,
       icon = Icons.auto_awesome_rounded,
       visualType = _FeatureVisualType.projectPlan;

  const _OnboardingPageData.feature({
    required this.title,
    required this.description,
    required this.icon,
    required this.visualType,
  }) : kind = _OnboardingPageKind.feature,
       highlightedText = '',
       imageAsset = null;

  const _OnboardingPageData.finalPage({
    required this.title,
    required this.description,
    required this.icon,
  }) : kind = _OnboardingPageKind.finalPage,
       highlightedText = '',
       imageAsset = null,
       visualType = _FeatureVisualType.projectPlan;
}
