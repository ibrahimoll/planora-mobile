import 'package:flutter/material.dart';

enum OnboardingPageType { intro, feature, finalPage }

class OnboardingPageData {
  final OnboardingPageType type;
  final String title;
  final String highlightedText;
  final String description;
  final String imageAsset;
  final String? darkImageAsset;
  final IconData? icon;

  const OnboardingPageData({
    required this.type,
    required this.title,
    this.highlightedText = '',
    required this.description,
    required this.imageAsset,
    this.darkImageAsset,
    this.icon,
  });

  String imageAssetFor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark && darkImageAsset != null) {
      return darkImageAsset!;
    }

    return imageAsset;
  }

  bool get isIntro => type == OnboardingPageType.intro;
  bool get isFeature => type == OnboardingPageType.feature;
  bool get isFinal => type == OnboardingPageType.finalPage;
}
