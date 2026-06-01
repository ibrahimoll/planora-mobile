import 'package:flutter/material.dart';

import '../../core/theme/planora_theme.dart';
import '../auth/shared/auth_responsive_metrics.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;

  const ForgotPasswordScreen({super.key, required this.onThemeToggle});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController emailController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  void _sendResetLink() {
    if (emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your email')));
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResetLinkSentScreen(
          onThemeToggle: widget.onThemeToggle,
          email: emailController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = AuthResponsiveMetrics.from(context, constraints);

        return Scaffold(
          resizeToAvoidBottomInset: true,
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: isDark
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF191B27), Color(0xFF11131D)],
                    )
                  : PlanoraTheme.onboardingBackgroundFor(context),
            ),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: metrics.maxContentWidth,
                  ),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.symmetric(
                      horizontal: metrics.horizontalPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: metrics.topGap),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 20,
                                color: isDark
                                    ? Colors.white
                                    : PlanoraTheme.textPrimary,
                              ),
                            ),
                            _ThemeToggle(
                              isDark: isDark,
                              onPressed: widget.onThemeToggle,
                            ),
                          ],
                        ),

                        SizedBox(height: metrics.logoToPillGap),

                        Image.asset(
                          'assets/images/planora_logo.png',
                          height: metrics.logoSize,
                          fit: BoxFit.contain,
                        ),

                        SizedBox(height: metrics.logoToPillGap),

                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0x332A1558)
                                  : PlanoraTheme.primaryLight,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'AI-POWERED PROJECT PLANNING',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall?.copyWith(
                                color: isDark
                                    ? const Color(0xFFA78BFA)
                                    : PlanoraTheme.primaryPurple,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: metrics.pillToTitleGap),

                        Image.asset(
                          isDark
                              ? 'assets/images/forgot_password_dark.png'
                              : 'assets/images/forgot_password_light.png',
                          height: metrics.logoSize * 1.65,
                          fit: BoxFit.contain,
                        ),

                        SizedBox(height: metrics.sectionGap),

                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: textTheme.headlineSmall?.copyWith(
                              fontSize: metrics.titleSize,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : PlanoraTheme.textPrimary,
                            ),
                            children: [
                              const TextSpan(text: 'Forgot '),
                              TextSpan(
                                text: 'password?',
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFFA78BFA)
                                      : PlanoraTheme.primaryPurple,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          'No worries! Enter your email address\nand we’ll send you a link to reset\nyour password.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: metrics.subtitleSize,
                            height: 1.45,
                            color: isDark
                                ? const Color(0xFFC8CAD5)
                                : PlanoraTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        SizedBox(height: metrics.titleToFormGap),

                        _FieldLabel(label: 'Email', isDark: isDark),

                        SizedBox(height: metrics.labelToFieldGap),

                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : PlanoraTheme.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: _inputDecoration(
                            context: context,
                            hintText: 'Enter your email',
                            prefixIcon: Icons.email_outlined,
                          ),
                        ),

                        SizedBox(height: metrics.sectionGap),

                        _GradientActionButton(
                          isDark: isDark,
                          height: metrics.buttonHeight,
                          label: 'Send Reset Link',
                          onPressed: _sendResetLink,
                        ),

                        SizedBox(height: metrics.sectionGap * 2),

                        Center(
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Text(
                              '‹ Back to Sign In',
                              style: textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? const Color(0xFFA78BFA)
                                    : PlanoraTheme.primaryPurple,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: metrics.bottomGap),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration({
    required BuildContext context,
    required String hintText,
    required IconData prefixIcon,
  }) {
    final isDark = PlanoraTheme.isDark(context);

    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(
        prefixIcon,
        size: 20,
        color: isDark ? const Color(0xFF8E92A3) : PlanoraTheme.textMuted,
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF1D202C) : PlanoraTheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      hintStyle: TextStyle(
        color: isDark ? const Color(0xFF8E92A3) : PlanoraTheme.textMuted,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2A2D3A) : PlanoraTheme.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF8B5CF6) : PlanoraTheme.primaryPurple,
          width: 1.5,
        ),
      ),
    );
  }
}

class ResetLinkSentScreen extends StatelessWidget {
  final VoidCallback onThemeToggle;
  final String email;

  const ResetLinkSentScreen({
    super.key,
    required this.onThemeToggle,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = AuthResponsiveMetrics.from(context, constraints);

        return Scaffold(
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: isDark
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF191B27), Color(0xFF11131D)],
                    )
                  : PlanoraTheme.onboardingBackgroundFor(context),
            ),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: metrics.maxContentWidth,
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: metrics.horizontalPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: metrics.topGap),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 20,
                                color: isDark
                                    ? Colors.white
                                    : PlanoraTheme.textPrimary,
                              ),
                            ),
                            _ThemeToggle(
                              isDark: isDark,
                              onPressed: onThemeToggle,
                            ),
                          ],
                        ),

                        SizedBox(height: metrics.logoToPillGap),

                        Image.asset(
                          'assets/images/planora_logo.png',
                          height: metrics.logoSize,
                          fit: BoxFit.contain,
                        ),

                        SizedBox(height: metrics.logoToPillGap),

                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0x332A1558)
                                  : PlanoraTheme.primaryLight,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'AI-POWERED PROJECT PLANNING',
                              style: textTheme.labelSmall?.copyWith(
                                color: isDark
                                    ? const Color(0xFFA78BFA)
                                    : PlanoraTheme.primaryPurple,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: metrics.pillToTitleGap),

                        Image.asset(
                          isDark
                              ? 'assets/images/reset_link_sent_dark.png'
                              : 'assets/images/reset_link_sent_light.png',
                          height: metrics.logoSize * 1.65,
                          fit: BoxFit.contain,
                        ),

                        SizedBox(height: metrics.sectionGap),

                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: textTheme.headlineSmall?.copyWith(
                              fontSize: metrics.titleSize,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : PlanoraTheme.textPrimary,
                            ),
                            children: [
                              const TextSpan(text: 'Check your '),
                              TextSpan(
                                text: 'email',
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFFA78BFA)
                                      : PlanoraTheme.primaryPurple,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          'We sent a password reset link to\nyour email address.\nPlease check your inbox.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: metrics.subtitleSize,
                            height: 1.45,
                            color: isDark
                                ? const Color(0xFFC8CAD5)
                                : PlanoraTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        SizedBox(height: metrics.sectionGap),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1D202C)
                                : const Color(0xFFF7F4FF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF2A2D3A)
                                  : PlanoraTheme.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 20,
                                color: isDark
                                    ? const Color(0xFFA78BFA)
                                    : PlanoraTheme.primaryPurple,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'If you don’t see the email,\ncheck your spam or junk folder.',
                                  style: textTheme.bodySmall?.copyWith(
                                    height: 1.4,
                                    color: isDark
                                        ? const Color(0xFFC8CAD5)
                                        : PlanoraTheme.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: metrics.sectionGap * 2),

                        Center(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(
                                context,
                              ).popUntil((route) => route.isFirst);
                            },
                            child: Text(
                              '‹ Back to Sign In',
                              style: textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? const Color(0xFFA78BFA)
                                    : PlanoraTheme.primaryPurple,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: metrics.bottomGap),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool isDark;

  const _FieldLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: isDark ? Colors.white : PlanoraTheme.textPrimary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  final bool isDark;
  final double height;
  final String label;
  final VoidCallback onPressed;

  const _GradientActionButton({
    required this.isDark,
    required this.height,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFF6D47DB), Color(0xFF8B5CF6)],
                )
              : PlanoraTheme.primaryGradientFor(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? const [
                  BoxShadow(
                    color: Color(0x4D6D47DB),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ]
              : PlanoraTheme.floatingShadowFor(context),
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
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
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  final bool isDark;
  final VoidCallback onPressed;

  const _ThemeToggle({required this.isDark, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        width: 58,
        height: 34,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1D202C) : const Color(0xFFF3EEFF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2D3A) : const Color(0xFFE6DDFB),
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
              gradient: LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF5B2DDA)],
              ),
            ),
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              size: 15,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
