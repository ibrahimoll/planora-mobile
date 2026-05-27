import 'package:flutter/material.dart';

import '../../../core/theme/planora_theme.dart';

class HeroTitle extends StatelessWidget {
  final String title;
  final String highlightedText;
  final double fontSize;

  const HeroTitle({
    super.key,
    required this.title,
    required this.highlightedText,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final parts = title.split(highlightedText);
    final baseStyle = Theme.of(context).textTheme.displayLarge?.copyWith(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      height: 1.1,
      color: PlanoraTheme.textPrimary,
    );
    if (highlightedText.isEmpty || parts.length != 2) {
      return Text(title, textAlign: TextAlign.center, style: baseStyle);
    }
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: parts.first),
          TextSpan(
            text: highlightedText,
            style: const TextStyle(color: PlanoraTheme.primaryPurple),
          ),
          TextSpan(text: parts.last),
        ],
      ),
    );
  }
}

class AiPill extends StatelessWidget {
  const AiPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: PlanoraTheme.lavenderGlow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'AI-POWERED PROJECT PLANNING',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: .5,
          color: PlanoraTheme.textSecondary,
        ),
      ),
    );
  }
}

class IconBadge extends StatelessWidget {
  final IconData icon;
  final double size;

  const IconBadge({super.key, required this.icon, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: PlanoraTheme.primaryLight,
        borderRadius: BorderRadius.circular(size * .31),
      ),
      child: Icon(icon, color: PlanoraTheme.primaryPurple, size: size * .48),
    );
  }
}
