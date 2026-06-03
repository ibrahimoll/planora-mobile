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
    Icons.auto_awesome_rounded,
    Icons.check_box_rounded,
    Icons.calendar_month_rounded,
  ];

  static const labels = [
    'Home',
    'Projects',
    'AI',
    'Tasks',
    'Calendar',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final primary = Theme.of(context).colorScheme.primary;
    final barColor = isDark ? const Color(0xFF252A29) : PlanoraTheme.surface;
    final inactiveColor = isDark ? Colors.white : PlanoraTheme.textSecondary;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: 92,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 64,
              margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(0),
                ),
                boxShadow: PlanoraTheme.cardShadowFor(context),
              ),
              child: Row(
                children: List.generate(icons.length, (index) {
                  if (index == 2) {
                    return const Expanded(child: SizedBox.shrink());
                  }

                  final active = selectedIndex == index;

                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => onTap(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedScale(
                              scale: active ? 1.10 : 1.0,
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutBack,
                              child: Icon(
                                icons[index],
                                size: 23,
                                color: active ? primary : inactiveColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                                    fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                                    color: active ? primary : inactiveColor,
                                  ),
                              child: Text(
                                labels[index],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Positioned(
              top: 0,
              child: GestureDetector(
                onTap: () => onTap(2),
                child: AnimatedScale(
                  scale: selectedIndex == 2 ? 1.06 : 1.0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: Column(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selectedIndex == 2 ? primary : const Color(0xFFF9A825),
                          border: Border.all(
                            color: isDark ? const Color(0xFF3B403E) : Colors.white,
                            width: 6,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: selectedIndex == 2 ? Colors.white : const Color(0xFF252A29),
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 220),
                        style: Theme.of(context).textTheme.labelSmall!.copyWith(
                              color: selectedIndex == 2 ? primary : inactiveColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 9,
                            ),
                        child: const Text('Planora AI'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
