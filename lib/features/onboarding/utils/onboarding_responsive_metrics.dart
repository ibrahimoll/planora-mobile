import 'package:flutter/material.dart';

class OnboardingResponsiveMetrics {
  final double actionButtonWidth;
  final double primaryButtonHeight;
  final double secondaryButtonHeight;
  final double maxContentWidth;
  final double horizontalPadding;
  final double introTopGap;
  final double logoSize;
  final double logoToTitleGap;
  final double brandTitleSize;
  final double titleToPillGap;
  final double pillToHeroGap;
  final double heroTitleSize;
  final double heroToDescriptionGap;
  final double descriptionSize;
  final double descriptionToIntroImageGap;
  final double introImageHeight;
  final double introImageWidth;
  final double featureTopGap;
  final double skipToImageGap;
  final double featureImageHeight;
  final double featureImageWidth;
  final double finalImageHeight;
  final double finalImageWidth;
  final double featureImageToIconGap;
  final double finalImageToIconGap;
  final double iconBadgeSize;
  final double iconToTitleGap;
  final double sectionTitleSize;
  final double sectionTitleToDescriptionGap;
  final double pageBottomPadding;
  final double dotsToButtonGap;
  final double buttonGap;
  final double bottomGap;

  const OnboardingResponsiveMetrics({
    required this.maxContentWidth,
    required this.horizontalPadding,
    required this.introTopGap,
    required this.logoSize,
    required this.logoToTitleGap,
    required this.brandTitleSize,
    required this.titleToPillGap,
    required this.pillToHeroGap,
    required this.heroTitleSize,
    required this.heroToDescriptionGap,
    required this.descriptionSize,
    required this.descriptionToIntroImageGap,
    required this.introImageHeight,
    required this.introImageWidth,
    required this.featureTopGap,
    required this.skipToImageGap,
    required this.featureImageHeight,
    required this.featureImageWidth,
    required this.finalImageHeight,
    required this.finalImageWidth,
    required this.featureImageToIconGap,
    required this.finalImageToIconGap,
    required this.iconBadgeSize,
    required this.iconToTitleGap,
    required this.sectionTitleSize,
    required this.sectionTitleToDescriptionGap,
    required this.pageBottomPadding,
    required this.dotsToButtonGap,
    required this.buttonGap,
    required this.bottomGap,
    required this.actionButtonWidth,
    required this.primaryButtonHeight,
    required this.secondaryButtonHeight,
  });

  factory OnboardingResponsiveMetrics.from(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final size = MediaQuery.sizeOf(context);

    final shortestSide = size.shortestSide;

    final height = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : size.height;

    final width = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : size.width;

    final compactHeight = height < 720;
    final tinyHeight = height < 640;
    final narrowWidth = width < 360;

    final effectiveWidth = width.clamp(0.0, 430.0).toDouble();

    final imageSafeWidth = (effectiveWidth - (narrowWidth ? 32.0 : 20.0))
        .clamp(260.0, 390.0)
        .toDouble();

    final tabletLike = shortestSide >= 600;

    return OnboardingResponsiveMetrics(
      actionButtonWidth: imageSafeWidth.clamp(280.0, 330.0).toDouble(),
      primaryButtonHeight: tinyHeight ? 44 : 48,
      secondaryButtonHeight: tinyHeight ? 42 : 46,

      maxContentWidth: tabletLike ? 460 : 430,
      horizontalPadding: narrowWidth ? 20 : 28,

      introTopGap: tinyHeight ? 22 : (compactHeight ? 30 : 44),
      logoSize: tinyHeight ? 54 : (compactHeight ? 60 : 66),
      logoToTitleGap: compactHeight ? 10 : 12,
      brandTitleSize: narrowWidth ? 32 : 36,

      titleToPillGap: compactHeight ? 12 : 16,
      pillToHeroGap: compactHeight ? 16 : 22,
      heroTitleSize: narrowWidth ? 29 : (compactHeight ? 31 : 33),
      heroToDescriptionGap: compactHeight ? 12 : 16,

      descriptionSize: narrowWidth ? 14 : 15,
      descriptionToIntroImageGap: tinyHeight ? 18 : (compactHeight ? 22 : 26),

      introImageHeight: (height * (compactHeight ? .23 : .27))
          .clamp(185.0, 250.0)
          .toDouble(),
      introImageWidth: (imageSafeWidth - 30).clamp(250.0, 350.0).toDouble(),

      featureTopGap: tinyHeight ? 8 : 18,
      skipToImageGap: tinyHeight ? 8 : 20,

      featureImageHeight: (height * .40).clamp(260.0, 340.0).toDouble(),
      featureImageWidth: (imageSafeWidth + 45).clamp(320.0, 430.0).toDouble(),

      finalImageHeight: (height * .38).clamp(250.0, 330.0).toDouble(),
      finalImageWidth: imageSafeWidth,

      featureImageToIconGap: tinyHeight ? 10 : (compactHeight ? 14 : 18),
      finalImageToIconGap: tinyHeight ? 24 : (compactHeight ? 30 : 38),

      iconBadgeSize: tinyHeight ? 52 : 58,
      iconToTitleGap: compactHeight ? 18 : 26,

      sectionTitleSize: narrowWidth ? 19 : 21,
      sectionTitleToDescriptionGap: compactHeight ? 10 : 14,

      pageBottomPadding: compactHeight ? 18 : 28,
      dotsToButtonGap: compactHeight ? 18 : 28,
      buttonGap: compactHeight ? 8 : 10,
      bottomGap: compactHeight ? 12 : 20,
    );
  }
}
