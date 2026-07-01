import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/planora_theme.dart';

Color authSurfaceColor(BuildContext context) => PlanoraTheme.isDark(context)
    ? PlanoraTheme.darkSurface
    : PlanoraTheme.surface;

Color authBorderColor(BuildContext context) => PlanoraTheme.isDark(context)
    ? PlanoraTheme.darkBorder
    : PlanoraTheme.border;

Color authMutedColor(BuildContext context) => PlanoraTheme.isDark(context)
    ? PlanoraTheme.darkTextMuted
    : PlanoraTheme.textMuted;

Color authBodyColor(BuildContext context) => PlanoraTheme.isDark(context)
    ? PlanoraTheme.darkTextMuted
    : PlanoraTheme.textSecondary;

class PlanoraAuthTopBar extends StatelessWidget {
  final VoidCallback onThemeToggle;
  final VoidCallback? onBack;

  const PlanoraAuthTopBar({
    super.key,
    required this.onThemeToggle,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: onBack ?? () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: isDark
                ? PlanoraTheme.darkTextPrimary
                : PlanoraTheme.textPrimary,
          ),
        ),
        PlanoraAuthThemeToggle(isDark: isDark, onPressed: onThemeToggle),
      ],
    );
  }
}

class PlanoraAuthBrandHeader extends StatelessWidget {
  final double logoSize;
  final double logoToPillGap;

  const PlanoraAuthBrandHeader({
    super.key,
    required this.logoSize,
    required this.logoToPillGap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Image.asset(
          'assets/images/planora_logo.png',
          height: logoSize,
          fit: BoxFit.contain,
        ),
        SizedBox(height: logoToPillGap),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isDark
                  ? PlanoraTheme.darkPrimaryContainer
                  : PlanoraTheme.primaryLight,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'AI-POWERED PROJECT PLANNING',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(
                color: isDark
                    ? PlanoraTheme.darkPrimary
                    : PlanoraTheme.primaryPurple,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PlanoraAuthIllustration extends StatelessWidget {
  final String lightAsset;
  final String darkAsset;
  final double height;
  final IconData fallbackIcon;

  const PlanoraAuthIllustration({
    super.key,
    required this.lightAsset,
    required this.darkAsset,
    required this.height,
    this.fallbackIcon = Icons.image_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Image.asset(
      isDark ? darkAsset : lightAsset,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: height,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: PlanoraTheme.softPurpleGradientFor(context),
            borderRadius: PlanoraTheme.radiusLarge,
            border: Border.all(color: authBorderColor(context)),
            boxShadow: PlanoraTheme.softCardShadowFor(context),
          ),
          child: Icon(
            fallbackIcon,
            color: Theme.of(context).colorScheme.primary,
            size: 44,
          ),
        );
      },
    );
  }
}

class PlanoraFieldLabel extends StatelessWidget {
  final String label;

  const PlanoraFieldLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: isDark ? PlanoraTheme.darkTextPrimary : PlanoraTheme.textPrimary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class PlanoraAuthTextField extends StatelessWidget {
  final Key? fieldKey;
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;

  const PlanoraAuthTextField({
    super.key,
    this.fieldKey,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return TextField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      inputFormatters: inputFormatters,
      style: TextStyle(
        color: isDark ? PlanoraTheme.darkTextPrimary : PlanoraTheme.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(prefixIcon, size: 20, color: authMutedColor(context)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: authSurfaceColor(context),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        hintStyle: TextStyle(
          color: authMutedColor(context),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: authBorderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PlanoraTheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PlanoraTheme.error, width: 1.5),
        ),
      ),
    );
  }
}

class PlanoraGradientButton extends StatelessWidget {
  final double height;
  final String label;
  final VoidCallback? onPressed;

  const PlanoraGradientButton({
    super.key,
    required this.height,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.58,
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: PlanoraTheme.primaryGradientFor(context),
            borderRadius: BorderRadius.circular(16),
            boxShadow: enabled
                ? PlanoraTheme.floatingShadowFor(context)
                : const <BoxShadow>[],
          ),
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class PlanoraAuthDivider extends StatelessWidget {
  const PlanoraAuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: authBorderColor(context))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or continue with',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: authBodyColor(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: authBorderColor(context))),
      ],
    );
  }
}

class PlanoraSocialButton extends StatelessWidget {
  final double height;
  final String label;
  final Widget logo;
  final VoidCallback? onTap;

  const PlanoraSocialButton({
    super.key,
    required this.height,
    required this.label,
    required this.logo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: authSurfaceColor(context),
          foregroundColor: isDark
              ? PlanoraTheme.darkTextPrimary
              : PlanoraTheme.textPrimary,
          side: BorderSide(color: authBorderColor(context)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [logo, const SizedBox(width: 12), Text(label)],
        ),
      ),
    );
  }
}

class PlanoraGoogleLogo extends StatelessWidget {
  const PlanoraGoogleLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/google_logo.svg',
      width: 20,
      height: 20,
    );
  }
}

class PlanoraAuthThemeToggle extends StatelessWidget {
  final bool isDark;
  final VoidCallback onPressed;

  const PlanoraAuthThemeToggle({
    super.key,
    required this.isDark,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      child: Semantics(
        button: true,
        label: isDark ? 'Switch to light mode' : 'Switch to dark mode',
        child: GestureDetector(
          onTap: onPressed,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            width: 58,
            height: 34,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark
                  ? PlanoraTheme.darkSurface
                  : PlanoraTheme.lavenderSurface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isDark
                    ? PlanoraTheme.darkBorder
                    : PlanoraTheme.lavenderBorder,
              ),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOutCubic,
              alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: PlanoraTheme.primaryGradient,
                ),
                child: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
