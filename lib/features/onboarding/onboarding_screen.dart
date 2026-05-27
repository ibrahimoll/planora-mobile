import 'package:flutter/material.dart';

import '../../core/theme/planora_theme.dart';
import 'models/onboarding_page_data.dart';
import 'utils/onboarding_responsive_metrics.dart';
import 'widgets/image_onboarding_page.dart';
import 'widgets/intro_onboarding_page.dart';
import 'widgets/onboarding_page_dot.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const List<OnboardingPageData> onboardingPages = [
    OnboardingPageData(
      type: OnboardingPageType.intro,
      title: 'Plan smarter.\nDeliver better.',
      highlightedText: 'smarter.',
      description:
          'Planora helps you plan projects, manage tasks, predict risks, and deliver successful results with the power of AI.',
      imageAsset: 'assets/images/onboarding_1.png',
      icon: null,
    ),
    OnboardingPageData(
      type: OnboardingPageType.feature,
      title: 'AI-Powered Planning',
      description:
          'Let AI break down your ideas into clear plans, smart tasks, and realistic timelines in seconds.',
      imageAsset: 'assets/images/onboarding_2.png',
      icon: Icons.auto_awesome_rounded,
      highlightedText: '',
    ),
    OnboardingPageData(
      type: OnboardingPageType.feature,
      title: 'Collaborate Effortlessly',
      description:
          'Work together in real-time. Assign tasks, share files, comment, and keep everyone on the same page.',
      imageAsset: 'assets/images/onboarding_3.png',
      icon: Icons.groups_rounded,
      highlightedText: '',
    ),
    OnboardingPageData(
      type: OnboardingPageType.finalPage,
      title: 'Ready to Achieve More?',
      description:
          'Join thousands of teams and professionals who plan smarter and deliver better with Planora.',
      imageAsset: 'assets/images/onboarding_4.png',
      icon: Icons.rocket_launch_rounded,
      highlightedText: '',
    ),
  ];

  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool get _isFirstPage => _currentPage == 0;
  bool get _isLastPage => _currentPage == onboardingPages.length - 1;
  bool get _isFinalPage =>
      onboardingPages[_currentPage].type == OnboardingPageType.finalPage;

  String get _primaryButtonLabel {
    if (_isFirstPage) return 'Get Started';
    if (_isFinalPage) return 'Create Account';
    return 'Next';
  }

  String get _secondaryButtonLabel {
    if (_isFinalPage) return 'I Already Have an Account';
    return 'Sign In';
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign in Screen coming next.')),
    );
  }

  void _skipOnboarding() {
    _pageController.animateToPage(
      onboardingPages.length - 1,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = OnboardingResponsiveMetrics.from(context, constraints);

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: PlanoraTheme.onboardingBackground,
            ),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: metrics.maxContentWidth,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: metrics.horizontalPadding,
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: onboardingPages.length,
                            onPageChanged: (index) {
                              setState(() => _currentPage = index);
                            },
                            itemBuilder: (context, index) {
                              final page = onboardingPages[index];

                              if (page.type == OnboardingPageType.intro) {
                                return _IntroOnboardingPage(
                                  data: page,
                                  metrics: metrics,
                                );
                              }

                              return _ImageOnboardingPage(
                                data: page,
                                metrics: metrics,
                                showSkip:
                                    page.type == OnboardingPageType.feature,
                                onSkip: _skipOnboarding,
                              );
                            },
                          ),
                        ),
                        OnboardingPageDot(
                          controller: _pageController,
                          count: onboardingPages.length,
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
                        //Buttons
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
