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
    _OnboardingPageData(
      title: 'Plan smarter.\nDeliver better.',
      highlightedText: 'smarter.',
      description:
          'Planora helps you plan projects, manage tasks, predict risks, and deliver successful results with the power of AI.',
      imageAsset: 'assets/images/onboarding_1.png',
    ),
    _OnboardingPageData(
      title: 'Break work\ninto clear tasks.',
      highlightedText: 'clear',
      description:
          'Turn big project ideas into structured tasks, priorities, and milestones without starting from a blank page.',
      imageAsset: 'assets/images/onboarding_2.png',
    ),
    _OnboardingPageData(
      title: 'Predict risks\nbefore delays.',
      highlightedText: 'risks',
      description:
          'Use AI-powered insights to detect overload, deadline problems, and project risks before they slow you down.',
      imageAsset: 'assets/images/onboarding_3.png',
    ),
    _OnboardingPageData(
      title: 'Work better\nwith your team.',
      highlightedText: 'team.',
      description:
          'Collaborate with members, assign tasks, track progress, and keep everyone aligned from one clean workspace.',
    ),
  ];

  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool get _isLastPage => _currentPage == _pages.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    if (!_isLastPage) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Auth screen coming next')));
  }

  void _goToSignIn() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sign in screen coming next')));
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
                          return _OnboardingPage(data: _pages[index]);
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
                        child: Text(
                          _isLastPage ? 'Start Planning' : 'Get Started',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: _goToSignIn,
                      child: const Text('Sign In'),
                    ),
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

class _OnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;

  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 34),
          Image.asset('assets/images/planora_logo.png', width: 74, height: 74),
          const SizedBox(height: 14),
          Text(
            'Planora',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: PlanoraTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          const _AiPill(),
          const SizedBox(height: 26),
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
          const SizedBox(height: 30),
          _OnboardingVisual(imageAsset: data.imageAsset),
          const SizedBox(height: 24),
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
      fontSize: 32,
      fontWeight: FontWeight.w800,
      height: 1.12,
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

class _OnboardingVisual extends StatelessWidget {
  final String? imageAsset;

  const _OnboardingVisual({this.imageAsset});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: Center(
        child: imageAsset == null
            ? const _FallbackVisual()
            : Image.asset(imageAsset!, width: 320, fit: BoxFit.contain),
      ),
    );
  }
}

class _FallbackVisual extends StatelessWidget {
  const _FallbackVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: PlanoraTheme.softPurpleGradient,
        borderRadius: PlanoraTheme.radiusXL,
        boxShadow: PlanoraTheme.softCardShadow,
        border: Border.all(color: PlanoraTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _VisualRow(icon: Icons.auto_awesome_rounded, label: 'AI planning'),
          SizedBox(height: 14),
          _VisualRow(icon: Icons.task_alt_rounded, label: 'Smart tasks'),
          SizedBox(height: 14),
          _VisualRow(icon: Icons.groups_rounded, label: 'Team progress'),
        ],
      ),
    );
  }
}

class _VisualRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _VisualRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: PlanoraTheme.primaryLight,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: PlanoraTheme.primaryPurple, size: 22),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: PlanoraTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _OnboardingPageData {
  final String title;
  final String highlightedText;
  final String description;
  final String? imageAsset;

  const _OnboardingPageData({
    required this.title,
    required this.highlightedText,
    required this.description,
    this.imageAsset,
  });
}
