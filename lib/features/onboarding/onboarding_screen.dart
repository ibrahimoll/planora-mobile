import 'package:flutter/material.dart';

import '../../core/theme/planora_theme.dart';
import 'data/onboarding_pages.dart';
import 'models/onboarding_page_data.dart';
import 'utils/onboarding_responsive_metrics.dart';
import 'widgets/image_onboarding_page.dart';
import 'widgets/intro_onboarding_page.dart';
import 'widgets/onboarding_page_dot.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;

  const OnboardingScreen({super.key, required this.onThemeToggle});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  int _currentPage = 0;

  bool get _isFirstPage => _currentPage == 0;

  bool get _isLastPage => _currentPage == onboardingPages.length - 1;

  bool get _isFinalPage =>
      onboardingPages[_currentPage].type == OnboardingPageType.finalPage;

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
      onboardingPages.length - 1,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final topInset = MediaQuery.paddingOf(context).top;

    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = OnboardingResponsiveMetrics.from(context, constraints);

        return Scaffold(
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: isDark
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF05070B), Color(0xFF0B1018)],
                    )
                  : PlanoraTheme.onboardingBackgroundFor(context),
            ),
            child: Stack(
              children: [
                if (isDark) ...[
                  Positioned(
                    top: -120,
                    left: -90,
                    right: -90,
                    child: IgnorePointer(
                      child: Container(
                        height: 310,
                        decoration: const BoxDecoration(
                          gradient: RadialGradient(
                            colors: [Color(0x332A1558), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -150,
                    left: -70,
                    right: -70,
                    child: IgnorePointer(
                      child: Container(
                        height: 330,
                        decoration: const BoxDecoration(
                          gradient: RadialGradient(
                            colors: [Color(0x262A1558), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                SafeArea(
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
                            const SizedBox(height: 44),
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
                                    return IntroOnboardingPage(
                                      data: page,
                                      metrics: metrics,
                                    );
                                  }

                                  return ImageOnboardingPage(
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

                            SizedBox(
                              width: metrics.actionButtonWidth,
                              height: metrics.primaryButtonHeight,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: isDark
                                      ? const LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            Color(0xFF7C3AED),
                                            Color(0xFF5B2DDA),
                                          ],
                                        )
                                      : PlanoraTheme.primaryGradientFor(context),
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(16),
                                  ),
                                  boxShadow: isDark
                                      ? const [
                                          BoxShadow(
                                            color: Color(0x4D5B2DDA),
                                            blurRadius: 22,
                                            offset: Offset(0, 12),
                                          ),
                                        ]
                                      : PlanoraTheme.floatingShadowFor(context),
                                ),
                                child: ElevatedButton(
                                  onPressed: _goToNextPage,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    minimumSize: Size.zero,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(_primaryButtonLabel),
                                ),
                              ),
                            ),

                            if (_showSecondaryButton) ...[
                              SizedBox(height: metrics.buttonGap),
                              SizedBox(
                                width: metrics.actionButtonWidth,
                                height: metrics.secondaryButtonHeight,
                                child: OutlinedButton(
                                  onPressed: _goToSignIn,
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: isDark
                                        ? const Color(0x66111822)
                                        : null,
                                    foregroundColor: isDark
                                        ? const Color(0xFFE5E7EB)
                                        : null,
                                    side: isDark
                                        ? const BorderSide(
                                            color: Color(0xFF222A36),
                                            width: 1.1,
                                          )
                                        : null,
                                    minimumSize: Size.zero,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(_secondaryButtonLabel),
                                ),
                              ),
                            ],

                            SizedBox(height: metrics.bottomGap),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: topInset + 8,
                  right: 18,
                  child: _ThemeToggleButton(
                    isDark: isDark,
                    onPressed: widget.onThemeToggle,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onPressed;

  const _ThemeToggleButton({required this.isDark, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    const double switchWidth = 78;
    const double switchHeight = 36;
    const double switchPadding = 3;
    const double thumbSize = 30;
    const double iconSlotSize = 30;
    const double thumbTravel = switchWidth - (switchPadding * 2) - thumbSize;

    return Tooltip(
      message: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      child: Semantics(
        button: true,
        label: isDark ? 'Switch to light mode' : 'Switch to dark mode',
        child: GestureDetector(
          onTap: onPressed,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            width: switchWidth,
            height: switchHeight,
            padding: const EdgeInsets.all(switchPadding),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0E1420) : const Color(0xFFF3EEFF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF273247)
                    : const Color(0xFFE6DDFB),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? const Color(0x80000000)
                      : const Color(0x1A6D28D9),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: SizedBox(
              width: switchWidth - (switchPadding * 2),
              height: thumbSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 330),
                    curve: Curves.easeInOutCubicEmphasized,
                    left: isDark ? thumbTravel : 0,
                    top: 0,
                    width: thumbSize,
                    height: thumbSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF8B5CF6), Color(0xFF5B2DDA)],
                        ),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x4D6D28D9),
                            blurRadius: 9,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      SizedBox(
                        width: iconSlotSize,
                        height: iconSlotSize,
                        child: _ThemeToggleIcon(
                          icon: Icons.light_mode_rounded,
                          isActive: !isDark,
                          activeColor: Colors.white,
                          inactiveColor: isDark
                              ? const Color(0xFF5D6880)
                              : const Color(0xFFF59E0B),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: iconSlotSize,
                        height: iconSlotSize,
                        child: _ThemeToggleIcon(
                          icon: Icons.dark_mode_rounded,
                          isActive: isDark,
                          activeColor: Colors.white,
                          inactiveColor: isDark
                              ? const Color(0xFF7C8596)
                              : PlanoraTheme.primaryPurple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeToggleIcon extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;

  const _ThemeToggleIcon({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        scale: isActive ? 1.0 : 0.86,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: isActive ? 1.0 : 0.72,
          child: Icon(
            icon,
            color: isActive ? activeColor : inactiveColor,
            size: 18,
          ),
        ),
      ),
    );
  }
}
