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

  static const _items = [
    _BottomNavItem(Icons.today_rounded, 'Today', 0),
    _BottomNavItem(Icons.route_rounded, 'Plans', 1),
    _BottomNavItem(Icons.check_box_rounded, 'Tasks', 3),
    _BottomNavItem(Icons.person_rounded, 'Profile', 4),
  ];

  int get _visualSlot {
    if (selectedIndex == 0) return 0;
    if (selectedIndex == 1) return 1;
    if (selectedIndex == 3) return 3;
    if (selectedIndex == 4) return 4;
    return 2;
  }

  bool get _showSlidingIndicator => selectedIndex != 2;

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final primary = Theme.of(context).colorScheme.primary;
    final barColor = isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface;
    final inactiveColor = isDark ? Colors.white : PlanoraTheme.textSecondary;
    final aiSelected = selectedIndex == 2;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: 92,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 72,
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
                ),
                boxShadow: PlanoraTheme.cardShadowFor(context),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final slotWidth = constraints.maxWidth / 5;
                  final left = slotWidth * _visualSlot;

                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeInOutCubicEmphasized,
                        left: left,
                        top: 0,
                        bottom: 0,
                        width: slotWidth,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: _showSlidingIndicator ? 1 : 0,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: primary.withValues(
                                  alpha: isDark ? 0.20 : 0.12,
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          _buildTab(
                            context: context,
                            item: _items[0],
                            primary: primary,
                            inactiveColor: inactiveColor,
                          ),
                          _buildTab(
                            context: context,
                            item: _items[1],
                            primary: primary,
                            inactiveColor: inactiveColor,
                          ),
                          const Expanded(child: SizedBox.shrink()),
                          _buildTab(
                            context: context,
                            item: _items[2],
                            primary: primary,
                            inactiveColor: inactiveColor,
                          ),
                          _buildTab(
                            context: context,
                            item: _items[3],
                            primary: primary,
                            inactiveColor: inactiveColor,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            Positioned(
              top: 0,
              child: GestureDetector(
                onTap: () => onTap(2),
                child: AnimatedScale(
                  scale: aiSelected ? 1.08 : 1.0,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: PlanoraTheme.primaryGradientFor(context),
                      border: Border.all(
                        color: isDark
                            ? PlanoraTheme.darkSurface
                            : PlanoraTheme.surface,
                        width: 6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.28 : 0.16,
                          ),
                          blurRadius: aiSelected ? 22 : 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 58,
              child: IgnorePointer(
                child: Text(
                  'AI Planner',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: aiSelected ? FontWeight.w900 : FontWeight.w800,
                    color: aiSelected ? primary : inactiveColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab({
    required BuildContext context,
    required _BottomNavItem item,
    required Color primary,
    required Color inactiveColor,
  }) {
    final selected = selectedIndex == item.index;
    final color = selected ? primary : inactiveColor;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onTap(item.index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutBack,
              child: Icon(item.icon, size: selected ? 23 : 21, color: color),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                color: color,
              ),
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem {
  final IconData icon;
  final String label;
  final int index;

  const _BottomNavItem(this.icon, this.label, this.index);
}
