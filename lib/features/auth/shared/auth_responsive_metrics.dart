import 'package:flutter/material.dart';

class AuthResponsiveMetrics {
  final double maxContentWidth;
  final double horizontalPadding;
  final double topGap;
  final double logoSize;
  final double logoToPillGap;
  final double pillToTitleGap;
  final double titleSize;
  final double subtitleSize;
  final double titleToFormGap;
  final double fieldGap;
  final double labelToFieldGap;
  final double rememberRowGap;
  final double buttonHeight;
  final double socialButtonHeight;
  final double sectionGap;
  final double socialGap;
  final double bottomGap;

  const AuthResponsiveMetrics({
    required this.maxContentWidth,
    required this.horizontalPadding,
    required this.topGap,
    required this.logoSize,
    required this.logoToPillGap,
    required this.pillToTitleGap,
    required this.titleSize,
    required this.subtitleSize,
    required this.titleToFormGap,
    required this.fieldGap,
    required this.labelToFieldGap,
    required this.rememberRowGap,
    required this.buttonHeight,
    required this.socialButtonHeight,
    required this.sectionGap,
    required this.socialGap,
    required this.bottomGap,
  });

  factory AuthResponsiveMetrics.from(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final size = MediaQuery.sizeOf(context);

    final width = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : size.width;
    final height = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : size.height;

    final shortestSide = size.shortestSide;
    final narrowWidth = width < 360;
    final compactHeight = height < 720;
    final tinyHeight = height < 640;
    final tabletLike = shortestSide >= 600;

    return AuthResponsiveMetrics(
      maxContentWidth: tabletLike ? 460 : 430,
      horizontalPadding: narrowWidth ? 20 : 24,
      topGap: tinyHeight ? 4 : (compactHeight ? 8 : 10),
      logoSize: tinyHeight ? 56 : (compactHeight ? 68 : 82),
      logoToPillGap: tinyHeight ? 6 : 10,
      pillToTitleGap: tinyHeight ? 16 : (compactHeight ? 22 : 28),
      titleSize: narrowWidth ? 23 : 25,
      subtitleSize: narrowWidth ? 13 : 14,
      titleToFormGap: tinyHeight ? 22 : (compactHeight ? 28 : 34),
      fieldGap: tinyHeight ? 12 : 18,
      labelToFieldGap: 8,
      rememberRowGap: tinyHeight ? 10 : 14,
      buttonHeight: tinyHeight ? 52 : 58,
      socialButtonHeight: tinyHeight ? 50 : 56,
      sectionGap: tinyHeight ? 18 : (compactHeight ? 22 : 26),
      socialGap: tinyHeight ? 10 : 12,
      bottomGap: compactHeight ? 18 : 30,
    );
  }
}
