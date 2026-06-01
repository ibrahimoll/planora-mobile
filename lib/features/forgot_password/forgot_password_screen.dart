import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/planora_theme.dart';
import '../auth/data/auth_api.dart';
import '../auth/shared/auth_responsive_metrics.dart';
import '../auth/shared/auth_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;

  const ForgotPasswordScreen({super.key, required this.onThemeToggle});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController emailController = TextEditingController();

  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendResetLink() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      _showMessage('Enter your email to continue');
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage('Enter a valid email address');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await AuthApi.forgotPassword(email: email);

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResetLinkSentScreen(
            onThemeToggle: widget.onThemeToggle,
            email: email,
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Could not send reset code. Please try again.');
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
        final illustrationHeight = metrics.logoSize * 1.65;

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
                        PlanoraAuthIllustration(
                          lightAsset: 'assets/images/forgot_password_light.png',
                          darkAsset: 'assets/images/forgot_password_dark.png',
                          height: illustrationHeight,
                          fallbackIcon: Icons.mark_email_unread_outlined,
                        ),
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
                              const TextSpan(text: 'Forgot '),
                              TextSpan(
                                text: 'password?',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "No worries. Enter your email address and we'll send you a code to reset your password.",
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: metrics.subtitleSize,
                            height: 1.45,
                            color: authBodyColor(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: metrics.titleToFormGap),
                        const PlanoraFieldLabel(label: 'Email'),
                        SizedBox(height: metrics.labelToFieldGap),
                        PlanoraAuthTextField(
                          controller: emailController,
                          hintText: 'Enter your email',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _sendResetLink(),
                        ),
                        SizedBox(height: metrics.sectionGap),
                        PlanoraGradientButton(
                          height: metrics.buttonHeight,
                          label: isLoading ? 'Sending...' : 'Send Reset Code',
                          onPressed: isLoading ? null : _sendResetLink,
                        ),
                        SizedBox(height: metrics.sectionGap * 2),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
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
        final illustrationHeight = metrics.logoSize * 1.65;

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
                        PlanoraAuthTopBar(onThemeToggle: onThemeToggle),
                        SizedBox(height: metrics.logoToPillGap),
                        PlanoraAuthBrandHeader(
                          logoSize: metrics.logoSize,
                          logoToPillGap: metrics.logoToPillGap,
                        ),
                        SizedBox(height: metrics.pillToTitleGap),
                        PlanoraAuthIllustration(
                          lightAsset: 'assets/images/reset_link_sent_light.png',
                          darkAsset: 'assets/images/reset_link_sent_dark.png',
                          height: illustrationHeight,
                          fallbackIcon: Icons.forward_to_inbox_outlined,
                        ),
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
                              const TextSpan(text: 'Check your '),
                              TextSpan(
                                text: 'email',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'We sent a password reset link to $email. Please check your inbox.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: metrics.subtitleSize,
                            height: 1.45,
                            color: authBodyColor(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: metrics.sectionGap),
                        const _ResetHelpCard(),
                        SizedBox(height: metrics.sectionGap * 2),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
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

class _ResetHelpCard extends StatelessWidget {
  const _ResetHelpCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: PlanoraTheme.isDark(context)
            ? PlanoraTheme.darkSurfaceVariant
            : PlanoraTheme.lavenderCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: authBorderColor(context)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "If you don't see the email, check your spam or junk folder.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                height: 1.4,
                color: authBodyColor(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
