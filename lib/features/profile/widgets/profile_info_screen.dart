import 'package:flutter/material.dart';

import '../../../core/theme/planora_theme.dart';
import '../models/profile_info_section.dart';

class ProfileInfoScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? body;
  final List<ProfileInfoSection>? sections;

  const ProfileInfoScreen({
    super.key,
    required this.title,
    required this.icon,
    this.body,
    this.sections,
  }) : assert(body != null || sections != null);

  Color mutedColor(BuildContext context) {
    return PlanoraTheme.isDark(context)
        ? PlanoraTheme.darkTextMuted
        : PlanoraTheme.textSecondary;
  }

  List<Widget> buildContent(BuildContext context) {
    final infoSections = sections;

    if (infoSections == null || infoSections.isEmpty) {
      return [
        Text(
          body ?? '',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: mutedColor(context),
            fontWeight: FontWeight.w700,
            height: 1.45,
          ),
        ),
      ];
    }

    return [
      for (var index = 0; index < infoSections.length; index++) ...[
        if (index > 0) const SizedBox(height: 18),
        Text(
          infoSections[index].title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        Text(
          infoSections[index].body,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: mutedColor(context),
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: PlanoraTheme.onboardingBackgroundFor(context),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? PlanoraTheme.darkSurface
                          : PlanoraTheme.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark
                            ? PlanoraTheme.darkBorder
                            : PlanoraTheme.border,
                      ),
                      boxShadow: PlanoraTheme.cardShadowFor(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.11),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            icon,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 16),
                        ...buildContent(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
