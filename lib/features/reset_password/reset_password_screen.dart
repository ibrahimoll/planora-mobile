import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/planora_theme.dart';
import '../auth/data/auth_api.dart';
import '../auth/shared/auth_responsive_metrics.dart';
import '../auth/shared/auth_widgets.dart';
import '../login/login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final String email;
  final String resetToken;

  const ResetPasswordScreen({
    super.key,
    required this.onThemeToggle,
    required this.email,
    required this.resetToken,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    passwordController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  bool _hasMinLength(String value) {
    return value.length >= 8;
  }

  bool _hasUppercase(String value) {
    return RegExp(r'[A-Z]').hasMatch(value);
  }

  bool _hasSymbol(String value) {
    return RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\[\];~`]').hasMatch(value);
  }

  bool _isStrongPassword(String password) {
    return _hasMinLength(password) &&
        _hasUppercase(password) &&
        _hasSymbol(password);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _resetPassword() async {
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (widget.email.trim().isEmpty || widget.resetToken.trim().isEmpty) {
      _showMessage('Invalid reset link. Please request a new reset link.');
      return;
    }

    if (password.isEmpty) {
      _showMessage('Enter your new password');
      return;
    }

    if (!_isStrongPassword(password)) {
      _showMessage('Password must be 8+ characters with uppercase and symbol.');
      return;
    }

    if (confirmPassword.isEmpty) {
      _showMessage('Confirm your new password');
      return;
    }

    if (password != confirmPassword) {
      _showMessage('Passwords do not match');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await AuthApi.resetPassword(
        email: widget.email,
        resetToken: widget.resetToken,
        newPassword: password,
      );

      if (!mounted) return;

      _showMessage('Password reset successfully. Please sign in.');

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LoginScreen(onThemeToggle: widget.onThemeToggle),
        ),
        (_) => false,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Could not reset password. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final textTheme = Theme.of(context).textTheme;
    final password = passwordController.text;

    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = AuthResponsiveMetrics.from(context, constraints);

        return Scaffold(
          resizeToAvoidBottomInset: true,
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: PlanoraTheme.onboardingBackgroundFor(context),
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
                        PlanoraAuthTopBar(onThemeToggle: widget.onThemeToggle),
                        SizedBox(height: metrics.logoToPillGap),
                        PlanoraAuthBrandHeader(
                          logoSize: metrics.logoSize,
                          logoToPillGap: metrics.logoToPillGap,
                        ),
                        SizedBox(height: metrics.pillToTitleGap),
                        _ResetPasswordIllustration(isDark: isDark),
                        SizedBox(height: metrics.sectionGap),
                        RichText(
                          textAlign: TextAlign.center,
                          textScaler: MediaQuery.textScalerOf(context),
                          text: TextSpan(
                            style: textTheme.headlineSmall?.copyWith(
                              fontSize: metrics.titleSize,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? PlanoraTheme.darkTextPrimary
                                  : PlanoraTheme.textPrimary,
                            ),
                            children: [
                              const TextSpan(text: 'Set new '),
                              TextSpan(
                                text: 'password',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Enter your new password below.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: metrics.subtitleSize,
                            color: authBodyColor(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: metrics.titleToFormGap),
                        const PlanoraFieldLabel(label: 'New Password'),
                        SizedBox(height: metrics.labelToFieldGap),
                        PlanoraAuthTextField(
                          controller: passwordController,
                          hintText: 'Enter new password',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: obscurePassword,
                          textInputAction: TextInputAction.next,
                          suffixIcon: IconButton(
                            tooltip: obscurePassword
                                ? 'Show password'
                                : 'Hide password',
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
                              color: authMutedColor(context),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _PasswordRequirementRow(
                          isValid: _hasMinLength(password),
                          label: 'At least 8 characters',
                        ),
                        _PasswordRequirementRow(
                          isValid: _hasUppercase(password),
                          label: 'One uppercase letter',
                        ),
                        _PasswordRequirementRow(
                          isValid: _hasSymbol(password),
                          label: 'One symbol',
                        ),
                        SizedBox(height: metrics.fieldGap),
                        const PlanoraFieldLabel(label: 'Confirm Password'),
                        SizedBox(height: metrics.labelToFieldGap),
                        PlanoraAuthTextField(
                          controller: confirmPasswordController,
                          hintText: 'Confirm new password',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: obscureConfirmPassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _resetPassword(),
                          suffixIcon: IconButton(
                            tooltip: obscureConfirmPassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () {
                              setState(() {
                                obscureConfirmPassword =
                                    !obscureConfirmPassword;
                              });
                            },
                            icon: Icon(
                              obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                              color: authMutedColor(context),
                            ),
                          ),
                        ),
                        SizedBox(height: metrics.sectionGap),
                        PlanoraGradientButton(
                          height: metrics.buttonHeight,
                          label: isLoading ? 'Resetting...' : 'Reset Password',
                          onPressed: isLoading ? null : _resetPassword,
                        ),
                        SizedBox(height: metrics.sectionGap),
                        Center(
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => LoginScreen(
                                    onThemeToggle: widget.onThemeToggle,
                                  ),
                                ),
                                (_) => false,
                              );
                            },
                            icon: const Icon(Icons.chevron_left_rounded),
                            label: const Text('Back to Sign In'),
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

class _ResetPasswordIllustration extends StatelessWidget {
  final bool isDark;

  const _ResetPasswordIllustration({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Center(
      child: SizedBox(
        width: 210,
        height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              bottom: 8,
              left: 14,
              child: _CloudBubble(
                width: 86,
                height: 34,
                opacity: isDark ? 0.14 : 0.55,
              ),
            ),
            Positioned(
              bottom: 8,
              right: 14,
              child: _CloudBubble(
                width: 86,
                height: 34,
                opacity: isDark ? 0.14 : 0.55,
              ),
            ),
            Positioned(
              top: 22,
              left: 28,
              child: _Sparkle(size: 12, color: primary),
            ),
            Positioned(
              top: 52,
              left: 4,
              child: _Sparkle(size: 9, color: primary),
            ),
            Positioned(
              top: 32,
              right: 24,
              child: _Sparkle(size: 10, color: primary),
            ),
            Positioned(
              top: 78,
              right: 4,
              child: _Sparkle(size: 9, color: primary),
            ),
            Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                gradient: PlanoraTheme.primaryGradientFor(context),
                borderRadius: BorderRadius.circular(34),
                boxShadow: PlanoraTheme.floatingShadowFor(context),
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: Colors.white,
                size: 46,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloudBubble extends StatelessWidget {
  final double width;
  final double height;
  final double opacity;

  const _CloudBubble({
    required this.width,
    required this.height,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  final double size;
  final Color color;

  const _Sparkle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.auto_awesome_rounded,
      size: size,
      color: color.withValues(alpha: 0.45),
    );
  }
}

class _PasswordRequirementRow extends StatelessWidget {
  final bool isValid;
  final String label;

  const _PasswordRequirementRow({required this.isValid, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(
            isValid
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: isValid
                ? PlanoraTheme.primaryPurple
                : authMutedColor(context),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: authBodyColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
