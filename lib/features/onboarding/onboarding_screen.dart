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
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = _ResponsiveMetrics.from(context, constraints);

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: PlanoraTheme.onboardingBackground,
            ),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: metrics.maxContentWidth),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: metrics.horizontalPadding,
                    ),
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
                                return _IntroOnboardingPage(
                                  data: page,
                                  metrics: metrics,
                                );
                              }

                              return _ImageOnboardingPage(
                                data: page,
                                metrics: metrics,
                                showSkip:
                                    page.type == _OnboardingPageType.feature,
                                onSkip: _skipOnboarding,
                              );
                            },
                          ),
                        ),
                        OnboardingPageDot(
                          controller: _pageController,
                          count: _pages.length,
                        ),
                        SizedBox(height: metrics.dotsToButtonGap),
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
                          SizedBox(height: metrics.buttonGap),
                          OutlinedButton(
                            onPressed: _goToSignIn,
                            child: Text(_secondaryButtonLabel),
                          ),
                        ],
                        SizedBox(height: metrics.bottomGap),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
  final _ResponsiveMetrics metrics;

  const _IntroOnboardingPage({required this.data, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          SizedBox(height: metrics.introTopGap),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/planora_logo.png',
                width: metrics.logoSize,
                height: metrics.logoSize,
              ),
              SizedBox(width: metrics.logoToTitleGap),
              Text(
                'Planora',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontSize: metrics.brandTitleSize,
                      fontWeight: FontWeight.w800,
                      color: PlanoraTheme.textPrimary,
                    ),
              ),
            ],
          ),
          SizedBox(height: metrics.titleToPillGap),
          const _AiPill(),
          SizedBox(height: metrics.pillToHeroGap),
          _HeroTitle(
            title: data.title,
            highlightedText: data.highlightedText,
            fontSize: metrics.heroTitleSize,
          ),
          SizedBox(height: metrics.heroToDescriptionGap),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: metrics.descriptionSize,
                  height: 1.55,
                  color: PlanoraTheme.textSecondary,
                ),
          ),
          SizedBox(height: metrics.descriptionToIntroImageGap),
          _OnboardingImage(
            assetPath: data.imageAsset,
            height: metrics.introImageHeight,
            width: metrics.introImageWidth,
          ),
          SizedBox(height: metrics.pageBottomPadding),
        ],
      ),
    );
  }
}

class _ImageOnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;
  final _ResponsiveMetrics metrics;
  final bool showSkip;
  final VoidCallback onSkip;

  const _ImageOnboardingPage({
    required this.data,
    required this.metrics,
    required this.showSkip,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final isFinal = data.type == _OnboardingPageType.finalPage;

    return Column(
      children: [
        SizedBox(height: metrics.featureTopGap),
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
        SizedBox(height: metrics.skipToImageGap),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _OnboardingImage(
                  assetPath: data.imageAsset,
                  height: isFinal
                      ? metrics.finalImageHeight
                      : metrics.featureImageHeight,
                  width: isFinal
                      ? metrics.finalImageWidth
                      : metrics.featureImageWidth,
                ),
                SizedBox(
                  height: isFinal
                      ? metrics.finalImageToIconGap
                      : metrics.featureImageToIconGap,
                ),
                _IconBadge(icon: data.icon, size: metrics.iconBadgeSize),
                SizedBox(height: metrics.iconToTitleGap),
                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: metrics.sectionTitleSize,
                        fontWeight: FontWeight.w800,
                        color: PlanoraTheme.textPrimary,
                      ),
                ),
                SizedBox(height: metrics.sectionTitleToDescriptionGap),
                Text(
                  data.description,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: metrics.descriptionSize,
                        height: 1.55,
                        color: PlanoraTheme.textSecondary,
                      ),
                ),
                SizedBox(height: metrics.pageBottomPadding),
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
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
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
  final double fontSize;

  const _HeroTitle({
    required this.title,
    required this.highlightedText,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final parts = title.split(highlightedText);
    final baseStyle = Theme.of(context).textTheme.displayLarge?.copyWith(
          fontSize: fontSize,
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
  final double size;

  const _IconBadge({required this.icon, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: PlanoraTheme.primaryLight,
        borderRadius: BorderRadius.circular(size * .31),
      ),
      child: Icon(icon, color: PlanoraTheme.primaryPurple, size: size * .48),
    );
  }
}

class _ResponsiveMetrics {
  final double maxContentWidth;
  final double horizontalPadding;
  final double introTopGap;
  final double logoSize;
  final double logoToTitleGap;
  final double brandTitleSize;
  final double titleToPillGap;
  final double pillToHeroGap;
  final double heroTitleSize;
  final double heroToDescriptionGap;
  final double descriptionSize;
  final double descriptionToIntroImageGap;
  final double introImageHeight;
  final double introImageWidth;
  final double featureTopGap;
  final double skipToImageGap;
  final double featureImageHeight;
  final double featureImageWidth;
  final double finalImageHeight;
  final double finalImageWidth;
  final double featureImageToIconGap;
  final double finalImageToIconGap;
  final double iconBadgeSize;
  final double iconToTitleGap;
  final double sectionTitleSize;
  final double sectionTitleToDescriptionGap;
  final double pageBottomPadding;
  final double dotsToButtonGap;
  final double buttonGap;
  final double bottomGap;

  const _ResponsiveMetrics({
    required this.maxContentWidth,
    required this.horizontalPadding,
    required this.introTopGap,
    required this.logoSize,
    required this.logoToTitleGap,
    required this.brandTitleSize,
    required this.titleToPillGap,
    required this.pillToHeroGap,
    required this.heroTitleSize,
    required this.heroToDescriptionGap,
    required this.descriptionSize,
    required this.descriptionToIntroImageGap,
    required this.introImageHeight,
    required this.introImageWidth,
    required this.featureTopGap,
    required this.skipToImageGap,
    required this.featureImageHeight,
    required this.featureImageWidth,
    required this.finalImageHeight,
    required this.finalImageWidth,
    required this.featureImageToIconGap,
    required this.finalImageToIconGap,
    required this.iconBadgeSize,
    required this.iconToTitleGap,
    required this.sectionTitleSize,
    required this.sectionTitleToDescriptionGap,
    required this.pageBottomPadding,
    required this.dotsToButtonGap,
    required this.buttonGap,
    required this.bottomGap,
  });

  factory _ResponsiveMetrics.from(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final size = MediaQuery.sizeOf(context);
    final shortestSide = size.shortestSide;
    final height = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : size.height;
    final width = constraints.maxWidth.isFinite ? constraints.maxWidth : size.width;
    final compactHeight = height < 720;
    final tinyHeight = height < 640;
    final narrowWidth = width < 360;
    final effectiveWidth = width.clamp(0.0, 430.0).toDouble();
    final imageSafeWidth = (effectiveWidth - (narrowWidth ? 32.0 : 20.0))
        .clamp(260.0, 390.0)
        .toDouble();
    final tabletLike = shortestSide >= 600;

    return _ResponsiveMetrics(
      maxContentWidth: tabletLike ? 460 : 430,
      horizontalPadding: narrowWidth ? 20 : 28,
      introTopGap: tinyHeight ? 22 : (compactHeight ? 30 : 44),
      logoSize: tinyHeight ? 54 : (compactHeight ? 60 : 66),
      logoToTitleGap: compactHeight ? 10 : 12,
      brandTitleSize: narrowWidth ? 32 : 36,
      titleToPillGap: compactHeight ? 12 : 16,
      pillToHeroGap: compactHeight ? 16 : 22,
      heroTitleSize: narrowWidth ? 29 : (compactHeight ? 31 : 33),
      heroToDescriptionGap: compactHeight ? 12 : 16,
      descriptionSize: narrowWidth ? 14 : 15,
      descriptionToIntroImageGap: tinyHeight ? 18 : (compactHeight ? 22 : 26),
      introImageHeight: (height * (compactHeight ? .27 : .32))
          .clamp(220.0, 300.0)
          .toDouble(),
      introImageWidth: imageSafeWidth,
      featureTopGap: tinyHeight ? 8 : 18,
      skipToImageGap: tinyHeight ? 8 : 20,
      featureImageHeight: (height * .30).clamp(200.0, 255.0).toDouble(),
      featureImageWidth: imageSafeWidth,
      finalImageHeight: (height * .38).clamp(250.0, 330.0).toDouble(),
      finalImageWidth: imageSafeWidth,
      featureImageToIconGap: tinyHeight ? 24 : (compactHeight ? 34 : 48),
      finalImageToIconGap: tinyHeight ? 24 : (compactHeight ? 30 : 38),
      iconBadgeSize: tinyHeight ? 52 : 58,
      iconToTitleGap: compactHeight ? 18 : 26,
      sectionTitleSize: narrowWidth ? 19 : 21,
      sectionTitleToDescriptionGap: compactHeight ? 10 : 14,
      pageBottomPadding: compactHeight ? 18 : 28,
      dotsToButtonGap: compactHeight ? 18 : 28,
      buttonGap: compactHeight ? 10 : 14,
      bottomGap: compactHeight ? 12 : 20,
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
