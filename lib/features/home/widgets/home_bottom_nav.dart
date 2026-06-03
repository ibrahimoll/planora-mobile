import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
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
  ];

  static const labels = [
    'Home',
    'Projects',
    'Tasks',
    'Calendar',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final primary = Theme.of(context).colorScheme.primary;
    final inactiveColor = isDark ? Colors.white : PlanoraTheme.textSecondary;
    final backgroundColor = isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface;

    return AnimatedBottomNavigationBar.builder(
      itemCount: icons.length,
      activeIndex: selectedIndex > 1 ? selectedIndex - 1 : selectedIndex,
      gapLocation: GapLocation.center,
      notchSmoothness: NotchSmoothness.softEdge,
      leftCornerRadius: 24,
      rightCornerRadius: 24,
      height: 72,
      elevation: 0,
      backgroundColor: backgroundColor,
      splashColor: primary.withValues(alpha: 0.12),
      onTap: (index) {
        final mappedIndex = index > 1 ? index + 1 : index;
        onTap(mappedIndex);
      },
      tabBuilder: (index, isActive) {
        final mappedIndex = index > 1 ? index + 1 : index;
        final selected = selectedIndex == mappedIndex;
        final color = selected ? primary : inactiveColor;

        return Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: selected ? 1.10 : 1.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: Icon(
                  icons[index],
                  size: 22,
                  color: color,
                ),
              ),
              const SizedBox(height: 5),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                      color: color,
                    ),
                child: Text(
                  labels[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
