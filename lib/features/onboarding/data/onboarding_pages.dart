import 'package:flutter/material.dart';

import '../models/onboarding_page_data.dart';

const List<OnboardingPageData> onboardingPages = [
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
  ),
  OnboardingPageData(
    type: OnboardingPageType.feature,
    title: 'Collaborate Effortlessly',
    description:
        'Work together in real-time. Assign tasks, share files, comment, and keep everyone on the same page.',
    imageAsset: 'assets/images/onboarding_3.png',
    icon: Icons.groups_rounded,
  ),
  OnboardingPageData(
    type: OnboardingPageType.finalPage,
    title: 'Ready to Achieve More?',
    description:
        'Join thousands of teams and professionals who plan smarter and deliver better with Planora.',
    imageAsset: 'assets/images/onboarding_4.png',
    icon: Icons.rocket_launch_rounded,
  ),
];
