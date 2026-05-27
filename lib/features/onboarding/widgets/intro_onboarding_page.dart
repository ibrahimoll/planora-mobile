import 'package:flutter/material.dart';

import '../../../core/theme/planora_theme.dart';
import '../models/onboarding_page_data.dart';
import '../utils/onboarding_responsive_metrics.dart';
import 'onboarding_image.dart';
import 'onboarding_small_widgets.dart';

class IntroOnboardingPage extends StatelessWidget {
  final OnboardingPageData data;
  final OnboardingResponsiveMetrics metrics;

  const IntroOnboardingPage({
    super.key,
    required this.data,
    required this.metrics,
  });

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

          const AiPill(),

          SizedBox(height: metrics.pillToHeroGap),

          HeroTitle(
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

          OnboardingImage(
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
