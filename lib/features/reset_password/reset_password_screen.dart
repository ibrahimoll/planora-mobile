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
  const ResetPasswordScreen({super.key, required this.onThemeToggle, required this.email});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final codeController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final codeFocusNode = FocusNode();

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool isLoading = false;
  bool isResendingCode = false;
  bool isVerifyingCode = false;
  bool isCodeVerified = false;
  String? verifiedCode;
  String? lastFailedCode;

  @override
  void initState() {
    super.initState();
    codeController.addListener(_handleCodeChanged);
    passwordController.addListener(_refreshPasswordRules);
  }

  @override
  void dispose() {
    codeController.removeListener(_handleCodeChanged);
    passwordController.removeListener(_refreshPasswordRules);
    codeFocusNode.dispose();
    codeController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _refreshPasswordRules() {
    if (mounted) setState(() {});
  }

  void _handleCodeChanged() {
    final code = codeController.text.trim();
    if (code != verifiedCode && (isCodeVerified || verifiedCode != null)) {
      setState(() {
        isCodeVerified = false;
        verifiedCode = null;
        passwordController.clear();
        confirmPasswordController.clear();
      });
    }
    if (code.length < 6 || isVerifyingCode || code == verifiedCode || code == lastFailedCode) return;
    _verifyCode(showSuccessMessage: false);
  }

  bool _hasMinLength(String value) => value.length >= 8;
  bool _hasUppercase(String value) => RegExp(r'[A-Z]').hasMatch(value);
  bool _hasSymbol(String value) => RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  bool _isStrongPassword(String value) => _hasMinLength(value) && _hasUppercase(value) && _hasSymbol(value);
  bool _isValidResetCode(String code) => RegExp(r'^\d{6}$').hasMatch(code);

  void _showMessage(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  void _goToSignIn() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(onThemeToggle: widget.onThemeToggle)),
      (_) => false,
    );
  }

  Future<void> _resendCode() async {
    if (isResendingCode || isLoading) return;
    setState(() => isResendingCode = true);
    try {
      await AuthApi.forgotPassword(email: widget.email);
      if (!mounted) return;
      codeController.clear();
      passwordController.clear();
      confirmPasswordController.clear();
      setState(() {
        isCodeVerified = false;
        verifiedCode = null;
        lastFailedCode = null;
      });
      codeFocusNode.requestFocus();
      _showMessage('A new reset code has been sent.');
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (error, stackTrace) {
      debugPrint('Resend reset code failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) _showMessage('Could not resend code. Please try again.');
    } finally {
      if (mounted) setState(() => isResendingCode = false);
    }
  }

  Future<bool> _verifyCode({bool showSuccessMessage = true}) async {
    final code = codeController.text.trim();
    if (widget.email.trim().isEmpty) {
      _showMessage('Email is missing. Please request a new code.');
      return false;
    }
    if (!_isValidResetCode(code)) {
      _showMessage(code.isEmpty ? 'Enter the reset code from your email' : 'Reset code must be 6 digits');
      return false;
    }
    if (isVerifyingCode) return false;
    setState(() => isVerifyingCode = true);
    try {
      await AuthApi.verifyResetCode(email: widget.email, resetCode: code);
      if (!mounted) return false;
      setState(() {
        isVerifyingCode = false;
        isCodeVerified = true;
        verifiedCode = code;
        lastFailedCode = null;
      });
      codeFocusNode.unfocus();
      if (showSuccessMessage) _showMessage('Code verified. Choose a new password.');
      return true;
    } on ApiException catch (error) {
      if (!mounted) return false;
      passwordController.clear();
      confirmPasswordController.clear();
      setState(() {
        isVerifyingCode = false;
        isCodeVerified = false;
        verifiedCode = null;
        lastFailedCode = code;
      });
      _showMessage(showSuccessMessage ? error.message : 'Invalid reset code.');
      return false;
    } catch (error, stackTrace) {
      debugPrint('Verify reset code failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return false;
      setState(() {
        isVerifyingCode = false;
        isCodeVerified = false;
        verifiedCode = null;
      });
      _showMessage('Could not verify code. Please try again.');
      return false;
    }
  }

  Future<void> _resetPassword() async {
    final code = codeController.text.trim();
    final password = passwordController.text;
    final confirm = confirmPasswordController.text;
    if (!(isCodeVerified && verifiedCode == code) && !await _verifyCode()) return;
    if (password.isEmpty) {
      _showMessage('Enter your new password');
      return;
    }
    if (!_isStrongPassword(password)) {
      _showMessage('Password must be 8+ characters with uppercase and symbol.');
      return;
    }
    if (confirm.isEmpty) {
      _showMessage('Confirm your new password');
      return;
    }
    if (password != confirm) {
      _showMessage('Passwords do not match');
      return;
    }
    setState(() => isLoading = true);
    try {
      await AuthApi.resetPassword(email: widget.email, resetCode: code, newPassword: password);
      if (!mounted) return;
      setState(() => isLoading = false);
      _showMessage('Password reset successfully. Please sign in.');
      _goToSignIn();
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (error, stackTrace) {
      debugPrint('Reset password failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) _showMessage('Could not reset password. Please try again.');
    } finally {
      if (mounted && isLoading) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final textTheme = Theme.of(context).textTheme;
    final metricsPassword = passwordController.text;
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = AuthResponsiveMetrics.from(context, constraints);
        return Scaffold(
          resizeToAvoidBottomInset: true,
          body: DecoratedBox(
            decoration: BoxDecoration(gradient: PlanoraTheme.onboardingBackgroundFor(context)),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: metrics.maxContentWidth),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.symmetric(horizontal: metrics.horizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: metrics.topGap),
                        PlanoraAuthTopBar(onThemeToggle: widget.onThemeToggle),
                        SizedBox(height: metrics.sectionGap),
                        const _ResetPasswordHeroSlot(),
                        SizedBox(height: metrics.sectionGap),
                        RichText(
                          textAlign: TextAlign.center,
                          textScaler: MediaQuery.textScalerOf(context),
                          text: TextSpan(
                            style: textTheme.headlineSmall?.copyWith(
                              fontSize: metrics.titleSize,
                              fontWeight: FontWeight.w800,
                              color: isDark ? PlanoraTheme.darkTextPrimary : PlanoraTheme.textPrimary,
                            ),
                            children: [
                              const TextSpan(text: 'Reset with '),
                              TextSpan(text: 'code', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Enter the 6-digit code sent to ${widget.email}. Once it is correct, you can choose your new password.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: metrics.subtitleSize,
                            height: 1.45,
                            color: authBodyColor(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: metrics.titleToFormGap),
                        _ResetCodeCard(
                          controller: codeController,
                          focusNode: codeFocusNode,
                          isVerified: isCodeVerified,
                          isVerifying: isVerifyingCode,
                          isResending: isResendingCode,
                          onVerifyPressed: isVerifyingCode ? null : () => _verifyCode(),
                          onResendPressed: isResendingCode ? null : _resendCode,
                        ),
                        SizedBox(height: metrics.fieldGap),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: isCodeVerified
                              ? Column(
                                  key: const ValueKey('password-form'),
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const PlanoraFieldLabel(label: 'New Password'),
                                    SizedBox(height: metrics.labelToFieldGap),
                                    PlanoraAuthTextField(
                                      controller: passwordController,
                                      hintText: 'Enter new password',
                                      prefixIcon: Icons.lock_outline_rounded,
                                      obscureText: obscurePassword,
                                      textInputAction: TextInputAction.next,
                                      suffixIcon: IconButton(
                                        tooltip: obscurePassword ? 'Show password' : 'Hide password',
                                        onPressed: () => setState(() => obscurePassword = !obscurePassword),
                                        icon: Icon(
                                          obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                          size: 20,
                                          color: authMutedColor(context),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _PasswordRequirementRow(isValid: _hasMinLength(metricsPassword), label: 'At least 8 characters'),
                                    _PasswordRequirementRow(isValid: _hasUppercase(metricsPassword), label: 'One uppercase letter'),
                                    _PasswordRequirementRow(isValid: _hasSymbol(metricsPassword), label: 'One symbol'),
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
                                        tooltip: obscureConfirmPassword ? 'Show password' : 'Hide password',
                                        onPressed: () => setState(() => obscureConfirmPassword = !obscureConfirmPassword),
                                        icon: Icon(
                                          obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
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
                                  ],
                                )
                              : const _LockedPasswordNotice(key: ValueKey('locked-password')),
                        ),
                        SizedBox(height: metrics.sectionGap),
                        Center(
                          child: TextButton.icon(
                            onPressed: _goToSignIn,
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

class _ResetPasswordHeroSlot extends StatelessWidget {
  const _ResetPasswordHeroSlot();
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/reset_password_custom.png',
      height: 132,
      width: double.infinity,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox(height: 8),
    );
  }
}

class _ResetCodeCard extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isVerified;
  final bool isVerifying;
  final bool isResending;
  final VoidCallback? onVerifyPressed;
  final VoidCallback? onResendPressed;
  const _ResetCodeCard({required this.controller, required this.focusNode, required this.isVerified, required this.isVerifying, required this.isResending, required this.onVerifyPressed, required this.onResendPressed});
  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final statusColor = isVerified ? PlanoraTheme.success : Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? PlanoraTheme.darkElevatedSurface : PlanoraTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isVerified ? PlanoraTheme.success.withValues(alpha: .55) : authBorderColor(context),
          width: isVerified ? 1.4 : 1,
        ),
        boxShadow: PlanoraTheme.softCardShadowFor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Reset Code',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isDark ? PlanoraTheme.darkTextPrimary : PlanoraTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _CodeStatusPill(
                label: isVerified ? 'Verified' : isVerifying ? 'Checking' : 'Required',
                icon: isVerified ? Icons.verified_rounded : isVerifying ? Icons.sync_rounded : Icons.lock_outline_rounded,
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _CodeBoxesInput(controller: controller, focusNode: focusNode, isVerified: isVerified, onSubmitted: onVerifyPressed),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  isVerified ? 'Code confirmed. You can now set a new password.' : 'Paste or type the code from your email.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: authBodyColor(context),
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              TextButton(
                onPressed: onResendPressed,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(44, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(isResending ? 'Sending...' : 'Resend'),
              ),
            ],
          ),
          if (!isVerified) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onVerifyPressed,
              icon: Icon(isVerifying ? Icons.sync_rounded : Icons.check_rounded, size: 18),
              label: Text(isVerifying ? 'Verifying...' : 'Verify Code'),
              style: OutlinedButton.styleFrom(
                backgroundColor: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.lavenderCard,
                foregroundColor: Theme.of(context).colorScheme.primary,
                side: BorderSide(color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.lavenderBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CodeBoxesInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isVerified;
  final VoidCallback? onSubmitted;
  const _CodeBoxesInput({required this.controller, required this.focusNode, required this.isVerified, required this.onSubmitted});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => focusNode.requestFocus(),
      child: SizedBox(
        height: 58,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onSubmitted?.call(),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                enableSuggestions: false,
                autocorrect: false,
                showCursor: false,
                style: const TextStyle(color: Colors.transparent),
                cursorColor: Colors.transparent,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  counterText: '',
                ),
              ),
            ),
            IgnorePointer(
              child: AnimatedBuilder(
                animation: Listenable.merge([controller, focusNode]),
                builder: (context, _) {
                  final code = controller.text;
                  final activeIndex = code.length >= 6 ? 5 : code.length;
                  return Row(
                    children: List.generate(6, (index) {
                      final value = index < code.length ? code[index] : '';
                      final isActive = focusNode.hasFocus && !isVerified && index == activeIndex;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: index == 5 ? 0 : 8),
                          child: _CodeDigitBox(value: value, isActive: isActive, isVerified: isVerified),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeDigitBox extends StatelessWidget {
  final String value;
  final bool isActive;
  final bool isVerified;
  const _CodeDigitBox({required this.value, required this.isActive, required this.isVerified});
  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final primary = Theme.of(context).colorScheme.primary;
    final borderColor = isVerified ? PlanoraTheme.success : isActive ? primary : authBorderColor(context);
    final fillColor = isVerified
        ? PlanoraTheme.success.withValues(alpha: isDark ? .14 : .08)
        : isActive
            ? primary.withValues(alpha: isDark ? .16 : .08)
            : isDark
                ? PlanoraTheme.darkSurface
                : Colors.white;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isActive || isVerified ? 1.5 : 1),
      ),
      child: value.isEmpty && isActive
          ? Container(width: 2, height: 20, decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(999)))
          : Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isVerified ? PlanoraTheme.success : isDark ? PlanoraTheme.darkTextPrimary : PlanoraTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .2,
                  ),
            ),
    );
  }
}

class _CodeStatusPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _CodeStatusPill({required this.label, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _LockedPasswordNotice extends StatelessWidget {
  const _LockedPasswordNotice({super.key});
  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.lavenderCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: authBorderColor(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primary.withValues(alpha: .12)),
            child: Icon(Icons.lock_outline_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'New password fields will appear after the reset code is correct.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: authBodyColor(context), height: 1.4, fontWeight: FontWeight.w600),
            ),
          ),
        ],
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
          Icon(isValid ? Icons.check_circle_rounded : Icons.circle_outlined, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
