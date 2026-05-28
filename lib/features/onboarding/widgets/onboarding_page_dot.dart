import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class OnboardingPageDot extends StatelessWidget {
  final PageController controller;
  final int count;

  const OnboardingPageDot({
    super.key,
    required this.controller,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SmoothPageIndicator(
      controller: controller,
      count: count,
      effect: ExpandingDotsEffect(
        dotHeight: 8,
        dotWidth: 8,
        activeDotColor: colorScheme.primary,
        dotColor: colorScheme.outline,
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
