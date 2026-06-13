import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/storage/token_storage.dart';
import 'package:mobile/features/auth/auth_gate.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import '../../core/theme/planora_theme.dart';
import '../auth/shared/auth_responsive_metrics.dart';
import '../auth/shared/auth_widgets.dart';
import '../forgot_password/forgot_password_screen.dart';
import '../register/register_screen.dart';
import 'package:mobile/features/auth/data/google_auth_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;

  const LoginScreen({super.key, required this.onThemeToggle});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool rememberMe = false;
  bool obscurePassword = true;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedIdentifier();
  }

  Future<void> _loadRememberedIdentifier() async {
    final savedRememberMe = await TokenStorage.getRememberMe();
    final savedIdentifier = await TokenStorage.getRememberedIdentifier();

    if (!mounted) return;

    setState(() {
      rememberMe = savedRememberMe;

      if (savedIdentifier != null && savedIdentifier.trim().isNotEmpty) {
        emailController.text = savedIdentifier;
      }
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  bool _isValidIdentifier(String value) {
    final trimmed = value.trim();

    if (trimmed.contains('@')) {
      return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(trimmed);
    }

    return trimmed.length >= 3;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signIn() async {
    final identifier = emailController.text.trim();
    final password = passwordController.text;

    if (identifier.isEmpty) {
      _showMessage('Enter your email or username to continue');
      return;
    }

    if (!_isValidIdentifier(identifier)) {
      _showMessage('Enter a valid email or username');
      return;
    }

    if (password.isEmpty) {
      _showMessage('Enter your password to continue');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final tokenResponse = await AuthApi.login(
        identifier: identifier,
        password: password,
      );

      await TokenStorage.saveAccessToken(tokenResponse.accessToken);

      if (rememberMe) {
        await TokenStorage.saveRememberedIdentifier(identifier);
      } else {
        await TokenStorage.clearRememberedIdentifier();
      }

      if (!mounted) return;

      _showMessage('Signed in successfully.');

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => AuthGate(onThemeToggle: widget.onThemeToggle),
        ),
        (_) => false,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } catch (error, stackTrace) {
      debugPrint('Login failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;
      _showMessage('Login failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      isLoading = true;
    });

    try {
      final idToken = await GoogleAuthService.signInAndGetIdToken();

      if (idToken == null) {
        if (!mounted) return;
        _showMessage('Google sign-in was cancelled.');
        return;
      }

      final tokenResponse = await AuthApi.loginWithGoogle(idToken: idToken);

      await TokenStorage.saveAccessToken(tokenResponse.accessToken);

      if (!mounted) return;

      _showMessage('Signed in with Google successfully.');

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => AuthGate(onThemeToggle: widget.onThemeToggle),
        ),
        (_) => false,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } catch (error, stackTrace) {
      debugPrint('GOOGLE_LOGIN_ERROR: $error');
      debugPrintStack(label: 'GOOGLE_LOGIN_STACK', stackTrace: stackTrace);

      if (!mounted) return;
      _showMessage('Google error: $error');
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
                        SizedBox(height: metrics.logoToPillGap),
                        PlanoraAuthBrandHeader(
                          logoSize: metrics.logoSize,
                          logoToPillGap: metrics.logoToPillGap,
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
                                  ? PlanoraTheme.darkTextPrimary
                                  : PlanoraTheme.textPrimary,
                            ),
                            children: [
                              const TextSpan(text: 'Welcome '),
                              TextSpan(
                                text: 'back',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
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
                            color: authBodyColor(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: metrics.titleToFormGap),
                        const PlanoraFieldLabel(label: 'Email or Username'),
                        SizedBox(height: metrics.labelToFieldGap),
                        PlanoraAuthTextField(
                          controller: emailController,
                          hintText: 'Enter your email or username',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                        ),
                        SizedBox(height: metrics.fieldGap),
                        const PlanoraFieldLabel(label: 'Password'),
                        SizedBox(height: metrics.labelToFieldGap),
                        PlanoraAuthTextField(
                          controller: passwordController,
                          hintText: 'Enter your password',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: obscurePassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _signIn(),
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
                        SizedBox(height: metrics.rememberRowGap),
                        _RememberAndForgotRow(
                          rememberMe: rememberMe,
                          onRememberChanged: (value) {
                            setState(() {
                              rememberMe = value;
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
                        PlanoraGradientButton(
                          height: metrics.buttonHeight,
                          label: isLoading ? 'Signing In...' : 'Sign In',
                          onPressed: isLoading ? null : _signIn,
                        ),
                        SizedBox(height: metrics.sectionGap),
                        const PlanoraAuthDivider(),
                        SizedBox(height: metrics.socialGap + 6),
                        PlanoraSocialButton(
                          height: metrics.socialButtonHeight,
                          label: isLoading ? 'Signing In...' : 'Google',
                          logo: const PlanoraGoogleLogo(),
                          onTap: isLoading ? null : _signInWithGoogle,
                        ),
                        SizedBox(height: metrics.sectionGap + 4),
                        _SignUpPrompt(
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
}

class _RememberAndForgotRow extends StatelessWidget {
  final bool rememberMe;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onForgotPassword;

  const _RememberAndForgotRow({
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
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onRememberChanged(!rememberMe),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: rememberMe,
                    onChanged: (value) => onRememberChanged(value ?? false),
                    activeColor: PlanoraTheme.primaryPurple,
                    checkColor: Colors.white,
                    side: BorderSide(
                      color: authBorderColor(context),
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
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        TextButton(
          onPressed: onForgotPassword,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            minimumSize: const Size(44, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Forgot password?'),
        ),
      ],
    );
  }
}

class _SignUpPrompt extends StatelessWidget {
  final VoidCallback onTap;

  const _SignUpPrompt({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
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
          child: const Text('Sign up'),
        ),
      ],
    );
  }
}
