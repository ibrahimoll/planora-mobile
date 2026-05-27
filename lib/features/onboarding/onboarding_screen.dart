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
      visualType: _OnboardingVisualType.projectPlan,
    ),
    _OnboardingPageData.feature(
      title: 'Collaborate Effortlessly',
      description:
          'Work together in real-time. Assign tasks, share files, comment, and keep everyone on the same page.',
      icon: Icons.groups_rounded,
      visualType: _OnboardingVisualType.teamWorkspace,
    ),
    _OnboardingPageData.feature(
      title: 'Track & Predict',
      description:
          'Track progress, get AI insights, and predict risks before they become problems.',
      icon: Icons.trending_up_rounded,
      visualType: _OnboardingVisualType.progressRisk,
    ),
  ];

  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool get _isFirstPage => _currentPage == 0;
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

                          return page.isIntro
                              ? _IntroOnboardingPage(data: page)
                              : _FeatureOnboardingPage(
                                  data: page,
                                  showSkip: index != _pages.length - 1,
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
                        child: Text(
                          _isFirstPage
                              ? 'Get Started'
                              : _isLastPage
                              ? 'Start Planning'
                              : 'Next',
                        ),
                      ),
                    ),
                    if (_isFirstPage) ...[
                      const SizedBox(height: 14),
                      OutlinedButton(
                        onPressed: _goToSignIn,
                        child: const Text('Sign In'),
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
  final bool showSkip;
  final VoidCallback onSkip;

  const _FeatureOnboardingPage({
    required this.data,
    required this.showSkip,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
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
  final _OnboardingVisualType type;

  const _FeatureVisual({required this.type});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
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
            _OnboardingVisualType.projectPlan => const _ProjectPlanVisual(),
            _OnboardingVisualType.teamWorkspace => const _TeamWorkspaceVisual(),
            _OnboardingVisualType.progressRisk => const _ProgressRiskVisual(),
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const _FloatingIcon(
          top: 8,
          right: -8,
          icon: Icons.auto_awesome_rounded,
        ),
        _GlassCard(
          width: 260,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CardTitle('Project Plan'),
              const SizedBox(height: 16),
              const _PlanTaskRow(label: 'Research', isDone: true),
              const SizedBox(height: 14),
              const _PlanTaskRow(label: 'Design', isDone: true),
              const SizedBox(height: 14),
              const _PlanTaskRow(label: 'Development'),
              const SizedBox(height: 14),
              const _PlanTaskRow(label: 'Testing'),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
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
        ),
      ],
    );
  }
}

class _TeamWorkspaceVisual extends StatelessWidget {
  const _TeamWorkspaceVisual();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const _FloatingIcon(
          bottom: -12,
          left: -18,
          icon: Icons.person_rounded,
        ),
        const _FloatingIcon(
          top: -10,
          right: -12,
          icon: Icons.chat_bubble_rounded,
        ),
        _GlassCard(
          width: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CardTitle('Team Workspace'),
              const SizedBox(height: 12),
              Row(
                children: const [
                  _AvatarBubble(label: 'I'),
                  SizedBox(width: 4),
                  _AvatarBubble(label: 'M'),
                  SizedBox(width: 4),
                  _AvatarBubble(label: 'A'),
                  SizedBox(width: 4),
                  _AvatarBubble(label: '+3', small: true),
                ],
              ),
              const SizedBox(height: 18),
              const _ActivityRow(
                icon: Icons.edit_rounded,
                title: 'Design phase updated',
                time: '2m ago',
              ),
              const SizedBox(height: 10),
              const _ActivityRow(
                icon: Icons.assignment_ind_rounded,
                title: 'Task assigned to you',
                time: '5m ago',
              ),
              const SizedBox(height: 10),
              const _ActivityRow(
                icon: Icons.upload_file_rounded,
                title: 'File uploaded',
                time: '10m ago',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressRiskVisual extends StatelessWidget {
  const _ProgressRiskVisual();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const _FloatingIcon(
          bottom: -14,
          right: -12,
          icon: Icons.verified_rounded,
        ),
        _GlassCard(
          width: 286,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CardTitle('Project Progress'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: PlanoraTheme.primaryPurple,
                        width: 7,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '72%',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'On Track',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: PlanoraTheme.success,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: const [
                        _ProgressLegend(label: 'Completed', value: '72%'),
                        SizedBox(height: 10),
                        _ProgressLegend(label: 'In Progress', value: '18%'),
                        SizedBox(height: 10),
                        _ProgressLegend(label: 'Pending', value: '10%'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const _CardTitle('Risk Prediction'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: PlanoraTheme.divider),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: PlanoraTheme.warning.withAlpha(28),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: PlanoraTheme.warning,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Medium Risk',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '2 risks identified',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
  final double width;
  final Widget child;

  const _GlassCard({required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(235),
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
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
  final IconData icon;

  const _FloatingIcon({
    this.top,
    this.right,
    this.bottom,
    this.left,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          gradient: PlanoraTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: PlanoraTheme.floatingShadow,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
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
    return Row(
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
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PlanoraTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: PlanoraTheme.primaryLight,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: PlanoraTheme.primaryPurple, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: PlanoraTheme.textPrimary,
                fontWeight: FontWeight.w700,
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
    );
  }
}

class _ProgressLegend extends StatelessWidget {
  final String label;
  final String value;

  const _ProgressLegend({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: PlanoraTheme.primaryPurple,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: PlanoraTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
            ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: PlanoraTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

enum _OnboardingVisualType { projectPlan, teamWorkspace, progressRisk }

class _OnboardingPageData {
  final bool isIntro;
  final String title;
  final String highlightedText;
  final String description;
  final String? imageAsset;
  final IconData icon;
  final _OnboardingVisualType visualType;

  const _OnboardingPageData.intro({
    required this.title,
    required this.highlightedText,
    required this.description,
    required this.imageAsset,
  }) : isIntro = true,
       icon = Icons.auto_awesome_rounded,
       visualType = _OnboardingVisualType.projectPlan;

  const _OnboardingPageData.feature({
    required this.title,
    required this.description,
    required this.icon,
    required this.visualType,
  }) : isIntro = false,
       highlightedText = '',
       imageAsset = null;
}
