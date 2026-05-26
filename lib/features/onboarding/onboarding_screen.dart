import 'package:flutter/material.dart';
import 'package:mobile/core/theme/planora_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPageData> _pages = const [
    _OnboardingPageData(
      title: 'Planora',
      subtitle: 'Plan. Organize. Achieve.\nTogether.',
      description: 'AI-powered planning\nfor teams that build.',
      imagePath: 'assets/images/onboarding_1.png',
    ),
    _OnboardingPageData(
      title: 'Smart Planning',
      subtitle: 'Break big projects\ninto clear tasks.',
      description: 'Let AI organize your work\ninto simple daily steps.',
      imagePath: 'assets/images/onboarding_2.png',
    ),
    _OnboardingPageData(
      title: 'Stay on Track',
      subtitle: 'Track progress.\nAvoid delays.',
      description: 'Get reminders, insights,\nand risk predictions.',
      imagePath: 'assets/images/onboarding_3.png',
    ),
  ];

  void _nextPage() {
    if (_currentPage == _pages.length - 1) {
      // TODO: Navigate to register/login screen
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PlanoraTheme.background,
      body: SafeArea(
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

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 52),

                        Image.asset(
                          'assets/images/planora_logo.png',
                          width: 72,
                          height: 72,
                          fit: BoxFit.contain,
                        ),

                        const SizedBox(height: 28),

                        Text(
                          page.title,
                          style: const TextStyle(
                            fontSize: 48,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF070B3F),
                            letterSpacing: -1.5,
                          ),
                        ),

                        const SizedBox(height: 28),

                        Text(
                          page.subtitle,
                          style: TextStyle(
                            fontSize: 24,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF070B3F).withOpacity(0.72),
                          ),
                        ),

                        const Spacer(),

                        Center(
                          child: Image.asset(
                            page.imagePath,
                            height: 260,
                            fit: BoxFit.contain,
                          ),
                        ),

                        const Spacer(),

                        Center(
                          child: Text(
                            page.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF070B3F).withOpacity(0.70),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    );
                  },
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: _currentPage == index ? 10 : 9,
                    height: _currentPage == index ? 10 : 9,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? PlanoraTheme.primary
                          : PlanoraTheme.primarySoft.withOpacity(0.25),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PlanoraTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentPage == _pages.length - 1
                            ? 'Start Now'
                            : 'Get Started',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 18),
                      const Icon(Icons.arrow_forward_rounded, size: 26),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF070B3F).withOpacity(0.60),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      // TODO: Navigate to login screen
                    },
                    child: Text(
                      'Log in',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: PlanoraTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final String title;
  final String subtitle;
  final String description;
  final String imagePath;

  const _OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.imagePath,
  });
}
