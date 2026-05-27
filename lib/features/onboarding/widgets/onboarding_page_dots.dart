// import 'package:flutter/material.dart';
// import 'package:smooth_page_indicator/smooth_page_indicator.dart';

// import '../../../core/theme/planora_theme.dart';

// class OnboardingPageDot extends StatelessWidget {
//   final PageController controller;
//   final int count;

//   const OnboardingPageDot({
//     super.key,
//     required this.controller,
//     this.count = 4,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return SmoothPageIndicator(
//       controller: controller,
//       count: count,
//       effect: const ExpandingDotsEffect(
//         dotHeight: 8,
//         dotWidth: 8,
//         activeDotColor: PlanoraTheme.primaryPurple,
//         dotColor: PlanoraTheme.border,
//         spacing: 8,
//         radius: 100,
//         expansionFactor: 3.4,
//       ),
//       onDotClicked: (index) {
//         controller.animateToPage(
//           index,
//           duration: const Duration(milliseconds: 350),
//           curve: Curves.easeInOutCubic,
//         );
//       },
//     );
//   }
// }
