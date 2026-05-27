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
      type: _OnboardingPageType.intro,
      title: 'Plan smarter.\nDeliver better.',
      highlightedText: 'smarter.',
      description:
          'Planora helps you plan projects, manage tasks, predict risks, and deliver successful results with the power of AI.',
      imageAsset: 'assets/images/onboarding_1.png',
      icon: Icons.auto_awesome_rounded,
    ),
    _OnboardingPageData(
      type: _OnboardingPageType.feature,
      title: 'AI-Powered Planning',
      description:
          'Let AI break down your ideas into clear plans, smart tasks, and realistic timelines in seconds.',
      imageAsset: 'assets/images/onboarding_2.png',
      icon: Icons.auto_awesome_rounded,
    ),
    _OnboardingPageData(
      type: _OnboardingPageType.feature,
      title: 'Collaborate Effortlessly',
      description:
          'Work together in real-time. Assign tasks, share files, comment, and keep everyone on the same page.',
      imageAsset: 'assets/images/onboarding_3.png',
      icon: Icons.groups_rounded,
    ),
    _OnboardingPageData(
      type: _OnboardingPageType.finalPage,
      title: 'Ready to Achieve More?',
      description:
          'Join thousands of teams and professionals who plan smarter and deliver better with Planora.',
      imageAsset: 'assets/images/onboarding_4.png',
      icon: Icons.rocket_launch_rounded,
    ),
  ];

  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool get _isFirstPage => _currentPage == 0;
  bool get _isLastPage => _currentPage == _pages.length - 1;
  bool get _isFinalPage =>
      _pages[_currentPage].type == _OnboardingPageType.finalPage;
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

                          if (page.type == _OnboardingPageType.intro) {
                            return _IntroOnboardingPage(data: page);
                          }

                          return _ImageOnboardingPage(
                            data: page,
                            showSkip: page.type == _OnboardingPageType.feature,
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
          const SizedBox(height: 26),
          _OnboardingImage(
            assetPath: data.imageAsset,
            height: 285,
            width: 380,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ImageOnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;
  final bool showSkip;
  final VoidCallback onSkip;

  const _ImageOnboardingPage({
    required this.data,
    required this.showSkip,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final isFinal = data.type == _OnboardingPageType.finalPage;

    return Column(
      children: [
        const SizedBox(height: 18),
        SizedBox(
          height: 34,
          child: Align(
            alignment: Alignment.centerRight,
            child: showSkip
                ? TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: PlanoraTheme.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Skip'),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _OnboardingImage(
                  assetPath: data.imageAsset,
                  height: isFinal ? 330 : 250,
                ),
                SizedBox(height: isFinal ? 38 : 48),
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

class _OnboardingImage extends StatelessWidget {
  final String assetPath;
  final double height;
  final double width;

  const _OnboardingImage({
    required this.assetPath,
    required this.height,
    this.width = 330,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Image.asset(
          assetPath,
          height: height,
          width: width,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _MissingImagePlaceholder(assetPath: assetPath);
          },
        ),
      ),
    );
  }
}

class _MissingImagePlaceholder extends StatelessWidget {
  final String assetPath;

  const _MissingImagePlaceholder({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: PlanoraTheme.softPurpleGradient,
        borderRadius: PlanoraTheme.radiusXL,
        border: Border.all(color: PlanoraTheme.border),
        boxShadow: PlanoraTheme.softCardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.image_not_supported_rounded,
            color: PlanoraTheme.primaryPurple,
            size: 38,
          ),
          const SizedBox(height: 10),
          Text(
            'Missing image',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: PlanoraTheme.textPrimary,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            assetPath,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: PlanoraTheme.textSecondary,
                ),
          ),
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

enum _OnboardingPageType { intro, feature, finalPage }

class _OnboardingPageData {
  final _OnboardingPageType type;
  final String title;
  final String highlightedText;
  final String description;
  final String imageAsset;
  final IconData icon;

  const _OnboardingPageData({
    required this.type,
    required this.title,
    this.highlightedText = '',
    required this.description,
    required this.imageAsset,
    required this.icon,
  });
}
