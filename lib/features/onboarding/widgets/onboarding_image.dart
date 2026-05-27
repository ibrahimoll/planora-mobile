import 'package:flutter/material.dart';

import '../../../core/theme/planora_theme.dart';

class OnboardingImage extends StatelessWidget {
  final String assetPath;
  final double height;
  final double width;

  const OnboardingImage({
    super.key,
    required this.assetPath,
    required this.height,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: Center(
        child: Image.asset(
          assetPath,
          height: height,
          width: width,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _MissingImagePlaceholder(assetPath: assetPath);
          },
        ),
      ),
    );
  }
}

class _MissingImagePlaceholder extends StatelessWidget {
  final String assetPath;

  const _MissingImagePlaceholder({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: PlanoraTheme.softPurpleGradient,
        borderRadius: PlanoraTheme.radiusXL,
        border: Border.all(color: PlanoraTheme.border),
        boxShadow: PlanoraTheme.softCardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.image_not_supported_rounded,
            color: PlanoraTheme.primaryPurple,
            size: 38,
          ),
          const SizedBox(height: 10),
          Text(
            'Missing image',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: PlanoraTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            assetPath,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: PlanoraTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
