import 'package:flutter/material.dart';

import '../../../core/theme/planora_theme.dart';

class HomeBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const HomeBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  static const icons = [
    Icons.home_rounded,
    Icons.folder_rounded,
    Icons.check_box_rounded,
    Icons.calendar_month_rounded,
    Icons.person_rounded,
  ];

  static const labels = [
    'Home',
    'Projects',
    'Tasks',
    'Calendar',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final inactiveColor = isDark
        ? PlanoraTheme.darkTextMuted
        : PlanoraTheme.textSecondary;

    return SafeArea(
      top: false,
      child: Container(
        height: 72,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
          ),
          boxShadow: PlanoraTheme.cardShadowFor(context),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / icons.length;

            return Stack(
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 330),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment(
                    -1 + (selectedIndex * 2 / (icons.length - 1)),
                    0,
                  ),
                  child: SizedBox(
                    width: itemWidth,
                    height: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: PlanoraTheme.primaryGradientFor(context),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: PlanoraTheme.floatingShadowFor(context),
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: List.generate(icons.length, (index) {
                    final active = selectedIndex == index;

                    return Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => onTap(index),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icons[index],
                              size: active ? 23 : 21,
                              color: active ? Colors.white : inactiveColor,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              labels[index],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                                    color: active ? Colors.white : inactiveColor,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
