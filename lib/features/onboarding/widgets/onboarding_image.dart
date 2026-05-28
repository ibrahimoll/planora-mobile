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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 300,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: PlanoraTheme.softPurpleGradientFor(context),
        borderRadius: PlanoraTheme.radiusXL,
        border: Border.all(color: colorScheme.outline),
        boxShadow: PlanoraTheme.softCardShadowFor(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported_rounded,
            color: colorScheme.primary,
            size: 38,
          ),
          const SizedBox(height: 10),
          Text(
            'Missing image',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            assetPath,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
