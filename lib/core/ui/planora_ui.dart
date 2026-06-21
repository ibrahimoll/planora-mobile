import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/planora_theme.dart';

abstract final class PlanoraSpacing {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 22;
  static const double xxl = 28;

  static const double pageHorizontal = 20;
  static const double pageTop = 18;
  static const double pageBottom = 28;
  static const double maxContentWidth = 540;

  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(
    pageHorizontal,
    pageTop,
    pageHorizontal,
    pageBottom,
  );

  static const EdgeInsets sheetPadding = EdgeInsets.fromLTRB(20, 16, 20, 24);
}

class PlanoraScaffold extends StatelessWidget {
  final Widget child;
  final bool extendBody;
  final bool bottomSafeArea;
  final Widget? bottomNavigationBar;

  const PlanoraScaffold({
    super.key,
    required this.child,
    this.extendBody = false,
    this.bottomSafeArea = false,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Scaffold(
      extendBody: extendBody,
      backgroundColor: isDark ? PlanoraTheme.darkBackground : PlanoraTheme.background,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: PlanoraTheme.onboardingBackgroundFor(context),
        ),
        child: SafeArea(bottom: bottomSafeArea, child: child),
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

class PlanoraPage extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget child;
  final Future<void> Function()? onRefresh;
  final EdgeInsetsGeometry padding;
  final double maxWidth;
  final ScrollPhysics physics;

  const PlanoraPage({
    super.key,
    this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
    required this.child,
    this.onRefresh,
    this.padding = PlanoraSpacing.pagePadding,
    this.maxWidth = PlanoraSpacing.maxContentWidth,
    this.physics = const AlwaysScrollableScrollPhysics(),
  });

  @override
  Widget build(BuildContext context) {
    Widget content = ListView(
      physics: physics,
      padding: padding,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null) ...[
                  PlanoraTopBar(
                    title: title!,
                    subtitle: subtitle,
                    onBack: onBack,
                    actions: actions,
                  ),
                  const SizedBox(height: PlanoraSpacing.lg),
                ],
                child,
              ],
            ),
          ),
        ),
      ],
    );

    if (onRefresh != null) {
      content = RefreshIndicator(
        color: Theme.of(context).colorScheme.primary,
        backgroundColor: PlanoraTheme.isDark(context)
            ? PlanoraTheme.darkSurface
            : PlanoraTheme.surface,
        displacement: 42,
        strokeWidth: 2.4,
        onRefresh: onRefresh!,
        child: content,
      );
    }

    return content;
  }
}

class PlanoraAnimatedIn extends StatelessWidget {
  final int index;
  final Widget child;
  final int baseDurationMs;
  final int delayMs;

  const PlanoraAnimatedIn({
    super.key,
    required this.index,
    required this.child,
    this.baseDurationMs = 340,
    this.delayMs = 60,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: baseDurationMs + index * delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: Transform.scale(
              scale: 0.96 + value * 0.04,
              child: animatedChild,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class PlanoraTopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget? leading;

  const PlanoraTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Row(
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 12),
        ] else if (onBack != null) ...[
          PlanoraIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onTap: onBack!,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: isDark
                          ? PlanoraTheme.darkTextPrimary
                          : PlanoraTheme.textPrimary,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? PlanoraTheme.darkTextSecondary
                            : PlanoraTheme.textSecondary,
                      ),
                ),
              ],
            ],
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: 10),
          ...actions,
        ],
      ],
    );
  }
}

class PlanoraHomeTopBar extends StatelessWidget {
  final String greeting;
  final String subtitle;
  final Widget avatar;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final bool hasUnreadNotifications;

  const PlanoraHomeTopBar({
    super.key,
    required this.greeting,
    required this.subtitle,
    required this.avatar,
    required this.onSearch,
    required this.onNotifications,
    this.hasUnreadNotifications = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Row(
      children: [
        avatar,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: isDark
                          ? PlanoraTheme.darkTextPrimary
                          : PlanoraTheme.textPrimary,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? PlanoraTheme.darkTextSecondary
                          : PlanoraTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        PlanoraIconButton(
          icon: Icons.search_rounded,
          tooltip: 'Search',
          onTap: onSearch,
        ),
        const SizedBox(width: 10),
        Stack(
          clipBehavior: Clip.none,
          children: [
            PlanoraIconButton(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Notifications',
              onTap: onNotifications,
            ),
            if (hasUnreadNotifications)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: PlanoraTheme.error,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class PlanoraIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final Color? backgroundColor;

  const PlanoraIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 42,
    this.iconSize = 21,
    this.iconColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final resolvedBackground =
        backgroundColor ?? (isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface);
    final resolvedIconColor =
        iconColor ?? (isDark ? PlanoraTheme.darkTextPrimary : PlanoraTheme.textPrimary);

    final button = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: resolvedBackground,
            border: Border.all(
              color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
            ),
            boxShadow: PlanoraTheme.cardShadowFor(context),
          ),
          child: Icon(icon, size: iconSize, color: resolvedIconColor),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class PlanoraPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double height;

  const PlanoraPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Row(
                  key: const ValueKey('content'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(label),
                  ],
                ),
        ),
      ),
    );
  }
}

class PlanoraSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  const PlanoraSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(label),
            ],
          );

    return SizedBox(
      height: height,
      child: OutlinedButton(onPressed: onPressed, child: child),
    );
  }
}

class PlanoraGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool isLoading;
  final double height;
  final double radius;

  const PlanoraGradientButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.isLoading = false,
    this.height = 52,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            gradient: PlanoraTheme.primaryGradientFor(context),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: PlanoraTheme.floatingShadowFor(context),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: isLoading
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      key: const ValueKey('content'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 22, color: Colors.white),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
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

class PlanoraCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? color;
  final Border? border;
  final List<BoxShadow>? boxShadow;

  const PlanoraCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 22,
    this.onTap,
    this.gradient,
    this.color,
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final decoration = BoxDecoration(
      color: gradient == null
          ? color ?? (isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface)
          : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius),
      border: border ??
          Border.all(
            color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
          ),
      boxShadow: boxShadow ?? PlanoraTheme.cardShadowFor(context),
    );

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: card,
      ),
    );
  }
}

class PlanoraLoadingIndicator extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color? color;

  const PlanoraLoadingIndicator({
    super.key,
    this.size = 34,
    this.strokeWidth = 2.7,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final primary = color ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: primary,
        backgroundColor: primary.withValues(alpha: .10),
        strokeCap: StrokeCap.round,
      ),
    );
  }
}

class PlanoraBrandLoader extends StatefulWidget {
  final String message;
  final double size;
  final bool showMessage;

  const PlanoraBrandLoader({
    super.key,
    this.message = 'Loading...',
    this.size = 88,
    this.showMessage = true,
  });

  @override
  State<PlanoraBrandLoader> createState() => _PlanoraBrandLoaderState();
}

class _PlanoraBrandLoaderState extends State<PlanoraBrandLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final badgeSize = widget.size * .62;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final pulse = 0.988 + (math.sin(progress * math.pi * 2) * 0.018);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: pulse,
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PlanoraLoadingIndicator(size: widget.size, strokeWidth: 3),
                    Container(
                      width: badgeSize,
                      height: badgeSize,
                      padding: EdgeInsets.all(widget.size * .09),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.size * .22),
                        gradient: PlanoraTheme.primaryGradientFor(context),
                        border: Border.all(color: Colors.white.withValues(alpha: .10)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(widget.size * .15),
                        child: Image.asset(
                          'assets/images/planora_logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.showMessage) ...[
              const SizedBox(height: 16),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: textColor.withValues(alpha: .76),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class PlanoraLoadingState extends StatelessWidget {
  final String message;
  final String? subtitle;
  final double topPadding;
  final double size;
  final bool branded;

  const PlanoraLoadingState({
    super.key,
    this.message = 'Loading...',
    this.subtitle,
    this.topPadding = 40,
    this.size = 42,
    this.branded = false,
  });

  @override
  Widget build(BuildContext context) {
    final fullScreenLoader = topPadding == 0 && size >= 80;

    if (branded || fullScreenLoader) {
      return Center(
        child: PlanoraBrandLoader(message: message, size: size),
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Center(
        child: PlanoraCard(
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlanoraLoadingIndicator(size: size.clamp(30, 52), strokeWidth: 2.8),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class PlanoraMessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;
  final double topMargin;

  const PlanoraMessageState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionText,
    this.onAction,
    this.topMargin = 36,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      margin: EdgeInsets.only(top: topMargin),
      child: PlanoraCard(
        padding: const EdgeInsets.all(22),
        radius: 24,
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? PlanoraTheme.darkTextPrimary
                        : PlanoraTheme.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? PlanoraTheme.darkTextSecondary
                        : PlanoraTheme.textSecondary,
                  ),
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 18),
              PlanoraGradientButton(label: actionText!, onTap: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

class PlanoraSegmentedTabs extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const PlanoraSegmentedTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
        ),
        boxShadow: PlanoraTheme.cardShadowFor(context),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final selected = selectedIndex == index;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(index),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: .12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tabs[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : isDark
                                ? PlanoraTheme.darkTextSecondary
                                : PlanoraTheme.textSecondary,
                      ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class PlanoraHeroPromptCard extends StatelessWidget {
  final String title;
  final String description;
  final String buttonText;
  final VoidCallback onButtonPressed;
  final IconData leadingIcon;
  final IconData trailingIcon;
  final String badgeText;

  const PlanoraHeroPromptCard({
    super.key,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onButtonPressed,
    this.leadingIcon = Icons.auto_awesome_rounded,
    this.trailingIcon = Icons.chat_bubble_outline_rounded,
    this.badgeText = 'AI-first',
  });

  @override
  Widget build(BuildContext context) {
    return PlanoraCard(
      radius: 28,
      padding: const EdgeInsets.all(20),
      gradient: PlanoraTheme.primaryGradientFor(context),
      border: Border.all(color: Colors.white.withValues(alpha: .08)),
      boxShadow: PlanoraTheme.floatingShadowFor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: .16)),
                ),
                child: Icon(leadingIcon, color: Colors.white, size: 24),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeText,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1.18,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: .86),
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: onButtonPressed,
                    child: Text(
                      buttonText,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: .25)),
                ),
                child: Icon(trailingIcon, color: Colors.white, size: 24),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PlanoraRingProgress extends StatelessWidget {
  final double progress;
  final String centerText;
  final String label;
  final double size;

  const PlanoraRingProgress({
    super.key,
    required this.progress,
    required this.centerText,
    required this.label,
    this.size = 112,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _PlanoraRingPainter(
              progress: clamped,
              color: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerText,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanoraRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  const _PlanoraRingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * .10;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.width - stroke) / 2;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final foregroundPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progress * math.pi * 2,
      false,
      foregroundPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PlanoraRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
