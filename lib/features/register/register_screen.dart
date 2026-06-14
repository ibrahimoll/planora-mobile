import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage.dart';
import '../../core/theme/planora_theme.dart';
import '../auth/auth_gate.dart';
import '../auth/data/auth_api.dart';
import '../auth/data/google_auth_service.dart';
import '../auth/shared/auth_responsive_metrics.dart';
import '../auth/shared/auth_widgets.dart';
import '../email_verification/email_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;

  const RegisterScreen({super.key, required this.onThemeToggle});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  final FocusNode passwordFocusNode = FocusNode();
  final FocusNode confirmPasswordFocusNode = FocusNode();

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool acceptTerms = false;
  bool isLoading = false;

  bool get hasStartedTyping => passwordController.text.isNotEmpty;
  bool get hasMinLength => passwordController.text.length >= 8;
  bool get hasUppercase => RegExp(r'[A-Z]').hasMatch(passwordController.text);
  bool get hasSymbol => RegExp(
    r'[!@#\$%^&*(),.?":{}|<>_\-+=/\\\[\];]',
  ).hasMatch(passwordController.text);
  bool get isPasswordValid => hasMinLength && hasUppercase && hasSymbol;

  bool get hasConfirmStarted => confirmPasswordController.text.isNotEmpty;
  bool get passwordsMatch =>
      hasConfirmStarted &&
      confirmPasswordController.text == passwordController.text;

  bool get shouldShowPasswordRules =>
      passwordFocusNode.hasFocus || hasStartedTyping;

  bool get shouldShowConfirmFeedback =>
      confirmPasswordFocusNode.hasFocus || hasConfirmStarted;

  @override
  void initState() {
    super.initState();

    passwordFocusNode.addListener(_refreshValidationState);
    confirmPasswordFocusNode.addListener(_refreshValidationState);
    passwordController.addListener(_refreshValidationState);
    confirmPasswordController.addListener(_refreshValidationState);
  }

  @override
  void dispose() {
    fullNameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    passwordFocusNode.dispose();
    confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  void _refreshValidationState() {
    if (mounted) {
      setState(() {});
    }
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }

  bool _isValidUsername(String value) {
    return RegExp(r'^[A-Za-z0-9_]{3,50}$').hasMatch(value);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createAccount() async {
    final fullName = fullNameController.text.trim();
    final username = usernameController.text.trim();
    final email = emailController.text.trim();

    if (fullName.isEmpty) {
      _showMessage('Enter your full name');
      return;
    }

    if (username.isEmpty) {
      _showMessage('Choose a username');
      return;
    }

    if (!_isValidUsername(username)) {
      _showMessage('Username must be 3-50 letters, numbers, or underscores');
      return;
    }

    if (email.isEmpty) {
      _showMessage('Enter your email to continue');
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage('Enter a valid email address');
      return;
    }

    if (!isPasswordValid) {
      _showMessage('Create a password that meets all requirements');
      passwordFocusNode.requestFocus();
      return;
    }

    if (!passwordsMatch) {
      _showMessage('Confirm password must match');
      confirmPasswordFocusNode.requestFocus();
      return;
    }

    if (!acceptTerms) {
      _showMessage('Please agree to the Terms and Privacy Policy');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await AuthApi.register(
        username: username,
        email: email,
        password: passwordController.text,
        fullName: fullName,
      );

      if (!mounted) return;

      _showMessage('Account created. Check your email for the code.');

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(
            onThemeToggle: widget.onThemeToggle,
            email: email,
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } catch (error, stackTrace) {
      debugPrint('Registration failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;
      _showMessage('Could not create account. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _registerWithGoogle() async {
    setState(() {
      isLoading = true;
    });

    try {
      final idToken = await GoogleAuthService.signInAndGetIdToken();

      if (idToken == null) {
        if (!mounted) return;
        _showMessage('Google registration was cancelled.');
        return;
      }

      final tokenResponse = await AuthApi.loginWithGoogle(idToken: idToken);

      await TokenStorage.saveAccessToken(tokenResponse.accessToken);

      if (!mounted) return;

      _showMessage('Continued with Google successfully.');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => AuthGate(onThemeToggle: widget.onThemeToggle),
        ),
        (_) => false,
      );
    } on GoogleAuthException catch (error) {
      debugPrint('GOOGLE_REGISTER_LOCAL_FAILURE: code=${error.code}');
      if (!mounted) return;
      _showMessage(error.message);
    } on ApiException catch (error) {
      debugPrint(
        'GOOGLE_REGISTER_BACKEND_REJECTED: status=${error.statusCode} '
        'message=${error.message}',
      );
      if (!mounted) return;
      final message =
          error.statusCode == 401 || error.message == 'Invalid Google token.'
          ? 'Google registration was rejected by the server. Check the release SHA fingerprints and backend Google Web client ID.'
          : error.message;
      _showMessage(message);
    } catch (error, stackTrace) {
      debugPrint('Google registration failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;
      _showMessage('Google registration failed. Please try again.');
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
                        SizedBox(height: metrics.pillToTitleGap),
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
                              const TextSpan(text: 'Create your '),
                              TextSpan(
                                text: 'account',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Join teams and professionals who plan smarter and deliver better with Planora.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: metrics.subtitleSize,
                            color: authBodyColor(context),
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                          ),
                        ),
                        SizedBox(height: metrics.titleToFormGap),
                        const PlanoraFieldLabel(label: 'Full Name'),
                        SizedBox(height: metrics.labelToFieldGap),
                        PlanoraAuthTextField(
                          controller: fullNameController,
                          hintText: 'Enter your full name',
                          prefixIcon: Icons.person_outline_rounded,
                          textInputAction: TextInputAction.next,
                        ),
                        SizedBox(height: metrics.fieldGap),
                        const PlanoraFieldLabel(label: 'Username'),
                        SizedBox(height: metrics.labelToFieldGap),
                        PlanoraAuthTextField(
                          controller: usernameController,
                          hintText: 'Choose a username',
                          prefixIcon: Icons.alternate_email_rounded,
                          textInputAction: TextInputAction.next,
                        ),
                        SizedBox(height: metrics.fieldGap),
                        const PlanoraFieldLabel(label: 'Email'),
                        SizedBox(height: metrics.labelToFieldGap),
                        PlanoraAuthTextField(
                          controller: emailController,
                          hintText: 'Enter your email',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                        ),
                        SizedBox(height: metrics.fieldGap),
                        const PlanoraFieldLabel(label: 'Password'),
                        SizedBox(height: metrics.labelToFieldGap),
                        PlanoraAuthTextField(
                          controller: passwordController,
                          focusNode: passwordFocusNode,
                          hintText: 'Create a password',
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
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            return SizeTransition(
                              sizeFactor: animation,
                              alignment: Alignment.topCenter,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: shouldShowPasswordRules
                              ? Padding(
                                  key: const ValueKey('password-rules-card'),
                                  padding: EdgeInsets.only(
                                    top: metrics.fieldGap,
                                  ),
                                  child: _PasswordRulesCard(
                                    hasStartedTyping: hasStartedTyping,
                                    hasMinLength: hasMinLength,
                                    hasUppercase: hasUppercase,
                                    hasSymbol: hasSymbol,
                                  ),
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey('password-rules-empty'),
                                ),
                        ),
                        SizedBox(height: metrics.fieldGap),
                        const PlanoraFieldLabel(label: 'Confirm Password'),
                        SizedBox(height: metrics.labelToFieldGap),
                        PlanoraAuthTextField(
                          controller: confirmPasswordController,
                          focusNode: confirmPasswordFocusNode,
                          hintText: 'Confirm your password',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: obscureConfirmPassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _createAccount(),
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
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: shouldShowConfirmFeedback
                              ? Padding(
                                  key: const ValueKey('confirm-feedback'),
                                  padding: const EdgeInsets.only(top: 10),
                                  child: _ConfirmPasswordFeedback(
                                    hasStartedTyping: hasConfirmStarted,
                                    matches: passwordsMatch,
                                  ),
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey('confirm-empty'),
                                ),
                        ),
                        SizedBox(height: metrics.fieldGap),
                        _TermsAgreementRow(
                          value: acceptTerms,
                          onChanged: (value) {
                            setState(() {
                              acceptTerms = value;
                            });
                          },
                        ),
                        SizedBox(height: metrics.sectionGap),
                        PlanoraGradientButton(
                          height: metrics.buttonHeight,
                          label: isLoading ? 'Creating...' : 'Create Account',
                          onPressed: isLoading ? null : _createAccount,
                        ),
                        SizedBox(height: metrics.sectionGap),
                        const PlanoraAuthDivider(),
                        SizedBox(height: metrics.socialGap + 6),
                        PlanoraSocialButton(
                          height: metrics.socialButtonHeight,
                          label: isLoading
                              ? 'Continuing...'
                              : 'Continue with Google',
                          logo: const PlanoraGoogleLogo(),
                          onTap: isLoading ? null : _registerWithGoogle,
                        ),
                        SizedBox(height: metrics.sectionGap + 4),
                        _SignInPrompt(onTap: () => Navigator.of(context).pop()),
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

class _PasswordRulesCard extends StatelessWidget {
  final bool hasStartedTyping;
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasSymbol;

  const _PasswordRulesCard({
    required this.hasStartedTyping,
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasSymbol,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: authSurfaceColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: authBorderColor(context)),
        boxShadow: PlanoraTheme.cardShadowFor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password must contain:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _PasswordRuleItem(
            hasStartedTyping: hasStartedTyping,
            passed: hasMinLength,
            text: 'At least 8 characters',
          ),
          const SizedBox(height: 7),
          _PasswordRuleItem(
            hasStartedTyping: hasStartedTyping,
            passed: hasUppercase,
            text: 'One uppercase letter',
          ),
          const SizedBox(height: 7),
          _PasswordRuleItem(
            hasStartedTyping: hasStartedTyping,
            passed: hasSymbol,
            text: 'One symbol',
          ),
        ],
      ),
    );
  }
}

class _PasswordRuleItem extends StatelessWidget {
  final bool hasStartedTyping;
  final bool passed;
  final String text;

  const _PasswordRuleItem({
    required this.hasStartedTyping,
    required this.passed,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final failed = hasStartedTyping && !passed;
    final iconColor = passed
        ? PlanoraTheme.success
        : failed
        ? PlanoraTheme.error
        : authMutedColor(context);
    final icon = passed
        ? Icons.check_circle_rounded
        : failed
        ? Icons.cancel_rounded
        : Icons.radio_button_unchecked_rounded;

    return Row(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Icon(
            icon,
            key: ValueKey('$text-$passed-$failed'),
            size: 16,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: failed ? PlanoraTheme.error : authBodyColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfirmPasswordFeedback extends StatelessWidget {
  final bool hasStartedTyping;
  final bool matches;

  const _ConfirmPasswordFeedback({
    required this.hasStartedTyping,
    required this.matches,
  });

  @override
  Widget build(BuildContext context) {
    final failed = hasStartedTyping && !matches;
    final icon = matches
        ? Icons.check_circle_rounded
        : failed
        ? Icons.cancel_rounded
        : Icons.radio_button_unchecked_rounded;
    final color = matches
        ? PlanoraTheme.success
        : failed
        ? PlanoraTheme.error
        : authMutedColor(context);
    final text = matches
        ? 'Passwords match'
        : failed
        ? 'Passwords do not match'
        : 'Re-enter the same password';

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: failed ? PlanoraTheme.error : authBodyColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _TermsAgreementRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _TermsAgreementRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: (nextValue) => onChanged(nextValue ?? false),
                activeColor: PlanoraTheme.primaryPurple,
                checkColor: Colors.white,
                side: BorderSide(color: authBorderColor(context), width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: textTheme.bodySmall?.copyWith(
                    color: authBodyColor(context),
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    const TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Terms of Service',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  final VoidCallback onTap;

  const _SignInPrompt({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: textTheme.bodySmall?.copyWith(
            color: authBodyColor(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            minimumSize: const Size(44, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Sign in'),
        ),
      ],
    );
  }
}
