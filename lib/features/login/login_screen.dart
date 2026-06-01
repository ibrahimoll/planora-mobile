import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/planora_theme.dart';
import '../auth/shared/auth_responsive_metrics.dart';
import '../forgot_password/forgot_password_screen.dart';
import '../register/register_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;

  const LoginScreen({super.key, required this.onThemeToggle});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool rememberMe = true;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _showComingLater(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
                            _AuthThemeToggle(
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
                        RichText(
                          textAlign: TextAlign.center,
                          textScaler: MediaQuery.textScalerOf(context),
                          text: TextSpan(
                            style: textTheme.headlineSmall?.copyWith(
                              fontSize: metrics.titleSize,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : PlanoraTheme.textPrimary,
                            ),
                            children: [
                              const TextSpan(text: 'Welcome '),
                              TextSpan(
                                text: 'back',
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFFA78BFA)
                                      : PlanoraTheme.primaryPurple,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to your account to continue',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: metrics.subtitleSize,
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
                          textInputAction: TextInputAction.next,
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
                        SizedBox(height: metrics.fieldGap),
                        _FieldLabel(label: 'Password', isDark: isDark),
                        SizedBox(height: metrics.labelToFieldGap),
                        TextField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          textInputAction: TextInputAction.done,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : PlanoraTheme.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration:
                              _inputDecoration(
                                context: context,
                                hintText: 'Enter your password',
                                prefixIcon: Icons.lock_outline_rounded,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      obscurePassword = !obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 20,
                                    color: isDark
                                        ? const Color(0xFF8E92A3)
                                        : PlanoraTheme.textMuted,
                                  ),
                                ),
                              ),
                        ),
                        SizedBox(height: metrics.rememberRowGap),
                        _RememberAndForgotRow(
                          isDark: isDark,
                          rememberMe: rememberMe,
                          onRememberChanged: (value) {
                            setState(() {
                              rememberMe = value ?? false;
                            });
                          },
                          onForgotPassword: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ForgotPasswordScreen(
                                  onThemeToggle: widget.onThemeToggle,
                                ),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: metrics.sectionGap),
                        _GradientActionButton(
                          isDark: isDark,
                          height: metrics.buttonHeight,
                          label: 'Sign In',
                          onPressed: () => _showComingLater(
                            'Backend login connection coming next',
                          ),
                        ),
                        SizedBox(height: metrics.sectionGap),
                        _AuthDivider(isDark: isDark),
                        SizedBox(height: metrics.socialGap + 6),
                        _SocialButton(
                          height: metrics.socialButtonHeight,
                          label: 'Google',
                          logo: const _GoogleLogo(),
                          onTap: () => _showComingLater(
                            'Google login connection coming next',
                          ),
                        ),
                        SizedBox(height: metrics.socialGap),
                        _SocialButton(
                          height: metrics.socialButtonHeight,
                          label: 'Apple',
                          logo: const _AppleLogo(),
                          onTap: () =>
                              _showComingLater('Apple login coming later'),
                        ),
                        SizedBox(height: metrics.sectionGap + 4),
                        _SignUpPrompt(
                          isDark: isDark,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RegisterScreen(
                                  onThemeToggle: widget.onThemeToggle,
                                ),
                              ),
                            );
                          },
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PlanoraTheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PlanoraTheme.error, width: 1.5),
      ),
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

class _RememberAndForgotRow extends StatelessWidget {
  final bool isDark;
  final bool rememberMe;
  final ValueChanged<bool?> onRememberChanged;
  final VoidCallback onForgotPassword;

  const _RememberAndForgotRow({
    required this.isDark,
    required this.rememberMe,
    required this.onRememberChanged,
    required this.onForgotPassword,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: rememberMe,
                onChanged: onRememberChanged,
                activeColor: isDark
                    ? const Color(0xFF8B5CF6)
                    : PlanoraTheme.primaryPurple,
                checkColor: Colors.white,
                side: BorderSide(
                  color: isDark ? const Color(0xFF2A2D3A) : PlanoraTheme.border,
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Remember me',
              style: textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white : PlanoraTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: onForgotPassword,
          child: Text(
            'Forgot password?',
            style: textTheme.bodySmall?.copyWith(
              color: isDark
                  ? const Color(0xFFA78BFA)
                  : PlanoraTheme.primaryPurple,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
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

class _AuthDivider extends StatelessWidget {
  final bool isDark;

  const _AuthDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Divider(
            color: isDark ? const Color(0xFF2A2D3A) : PlanoraTheme.divider,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or continue with',
            style: textTheme.bodySmall?.copyWith(
              color: isDark
                  ? const Color(0xFFC8CAD5)
                  : PlanoraTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: isDark ? const Color(0xFF2A2D3A) : PlanoraTheme.divider,
          ),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final double height;
  final String label;
  final Widget logo;
  final VoidCallback onTap;

  const _SocialButton({
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
          backgroundColor: isDark
              ? const Color(0xFF1D202C)
              : PlanoraTheme.surface,
          foregroundColor: isDark ? Colors.white : PlanoraTheme.textPrimary,
          side: BorderSide(
            color: isDark ? const Color(0xFF2A2D3A) : PlanoraTheme.border,
          ),
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

class _SignUpPrompt extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _SignUpPrompt({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Don’t have an account? ',
          style: textTheme.bodySmall?.copyWith(
            color: isDark
                ? const Color(0xFFC8CAD5)
                : PlanoraTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            'Sign up',
            style: textTheme.bodySmall?.copyWith(
              color: isDark
                  ? const Color(0xFFA78BFA)
                  : PlanoraTheme.primaryPurple,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/google_logo.svg',
      width: 20,
      height: 20,
    );
  }
}

class _AppleLogo extends StatelessWidget {
  const _AppleLogo();

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Icon(
      Icons.apple_rounded,
      size: 22,
      color: isDark ? Colors.white : Colors.black,
    );
  }
}

class _AuthThemeToggle extends StatelessWidget {
  final bool isDark;
  final VoidCallback onPressed;

  const _AuthThemeToggle({required this.isDark, required this.onPressed});

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
              color: isDark ? const Color(0xFF1D202C) : const Color(0xFFF3EEFF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF2A2D3A)
                    : const Color(0xFFE6DDFB),
              ),
            ),
            child: Stack(
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeInOutCubic,
                  alignment: isDark
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF8B5CF6), Color(0xFF5B2DDA)],
                      ),
                    ),
                    child: Icon(
                      isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
