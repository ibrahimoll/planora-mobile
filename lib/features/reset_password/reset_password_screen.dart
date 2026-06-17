import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  void _goToSignIn({bool clearResetLinkFromUrl = false}) {
    if (clearResetLinkFromUrl) {
      SystemNavigator.routeInformationUpdated(location: '/', replace: true);
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(onThemeToggle: widget.onThemeToggle),
      ),
      (_) => false,
    );
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

      setState(() {
        isLoading = false;
      });

      _showMessage('Password reset successfully. Please sign in.');
      _goToSignIn(clearResetLinkFromUrl: true);
    } on ApiException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } catch (error, stackTrace) {
      debugPrint('Reset password failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;
      _showMessage('Could not reset password. Please try again.');
    } finally {
      if (mounted && isLoading) {
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
                            onPressed: () =>
                                _goToSignIn(clearResetLinkFromUrl: true),
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
    return Center(
      child: Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: PlanoraTheme.primaryGradientFor(context),
          boxShadow: PlanoraTheme.floatingShadowFor(context),
        ),
        child: const Icon(
          Icons.lock_reset_rounded,
          color: Colors.white,
          size: 48,
        ),
      ),
    );
  }
}

class _PasswordRequirementRow extends StatelessWidget {
  final bool isValid;
  final String label;

  const _PasswordRequirementRow({required this.isValid, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = isValid ? PlanoraTheme.success : authMutedColor(context);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
