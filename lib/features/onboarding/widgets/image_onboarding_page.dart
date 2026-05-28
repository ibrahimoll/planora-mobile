import 'package:flutter/material.dart';

import '../models/onboarding_page_data.dart';
import '../utils/onboarding_responsive_metrics.dart';
import 'onboarding_image.dart';
import 'onboarding_small_widgets.dart';

class ImageOnboardingPage extends StatelessWidget {
  final OnboardingPageData data;
  final OnboardingResponsiveMetrics metrics;
  final bool showSkip;
  final VoidCallback onSkip;

  const ImageOnboardingPage({
    super.key,
    required this.data,
    required this.metrics,
    required this.showSkip,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final isFinal = data.type == OnboardingPageType.finalPage;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

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
                      foregroundColor: colorScheme.onSurfaceVariant,
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
                OnboardingImage(
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

                if (data.icon != null)
                  IconBadge(icon: data.icon!, size: metrics.iconBadgeSize),

                SizedBox(height: metrics.iconToTitleGap),

                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge?.copyWith(
                    fontSize: metrics.sectionTitleSize,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),

                SizedBox(height: metrics.sectionTitleToDescriptionGap),

                Text(
                  data.description,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: metrics.descriptionSize,
                    height: 1.55,
                    color: colorScheme.onSurfaceVariant,
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
