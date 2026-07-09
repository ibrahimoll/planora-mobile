import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/planora_theme.dart';
import '../auth/data/auth_api.dart';
import '../auth/shared/auth_responsive_metrics.dart';
import '../auth/shared/auth_widgets.dart';
import '../../core/storage/token_storage.dart';
import '../auth/auth_gate.dart';

class EmailVerificationScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final String email;

  const EmailVerificationScreen({
    super.key,
    required this.onThemeToggle,
    this.email = 'your email address',
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  static const int codeLength = 6;
  static const int initialSeconds = 47;

  final List<TextEditingController> codeControllers = List.generate(
    codeLength,
    (_) => TextEditingController(),
  );

  final List<FocusNode> codeFocusNodes = List.generate(
    codeLength,
    (_) => FocusNode(),
  );

  Timer? timer;
  int secondsRemaining = initialSeconds;
  bool isVerifying = false;
  bool isResending = false;

  String get emailLabel =>
      widget.email.trim().isEmpty ? 'your email address' : widget.email.trim();

  String get code =>
      codeControllers.map((controller) => controller.text).join();

  bool get canVerify => code.length == codeLength;
  bool get canResend => secondsRemaining == 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    timer?.cancel();

    for (final controller in codeControllers) {
      controller.dispose();
    }

    for (final focusNode in codeFocusNodes) {
      focusNode.dispose();
    }

    super.dispose();
  }

  void _startTimer() {
    timer?.cancel();

    setState(() {
      secondsRemaining = initialSeconds;
    });

    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (secondsRemaining == 0) {
        timer.cancel();
        return;
      }

      setState(() {
        secondsRemaining--;
      });
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _setCodeDigit(int index, String value) {
    codeControllers[index].value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _onCodeChanged(String value, int index) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '').split('');

      for (int i = 0; i < codeLength; i++) {
        _setCodeDigit(i, i < digits.length ? digits[i] : '');
      }

      if (digits.length >= codeLength) {
        codeFocusNodes.last.requestFocus();
      } else {
        codeFocusNodes[digits.length.clamp(0, codeLength - 1)].requestFocus();
      }

      setState(() {});
      return;
    }

    if (value.isNotEmpty && index < codeLength - 1) {
      codeFocusNodes[index + 1].requestFocus();
    }

    if (value.isEmpty && index > 0) {
      codeFocusNodes[index - 1].requestFocus();
    }

    setState(() {});
  }

  Future<void> _verifyEmail() async {
    if (!canVerify) return;

    setState(() {
      isVerifying = true;
    });

    try {
      final tokenResponse = await AuthApi.verifyEmail(
        email: widget.email,
        code: code,
      );

      await TokenStorage.saveAccessToken(tokenResponse.accessToken);

      if (!mounted) return;

      _showMessage('Email verified successfully.');

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
      debugPrint('Email verification failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;
      _showMessage('Could not verify email. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          isVerifying = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    if (!canResend || isResending) return;

    setState(() {
      isResending = true;
    });

    try {
      await AuthApi.resendVerificationCode(email: widget.email);

      if (!mounted) return;

      _showMessage('Verification code sent.');
      _startTimer();
    } on ApiException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } catch (error, stackTrace) {
      debugPrint('Resend verification failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;
      _showMessage('Could not resend code. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          isResending = false;
        });
      }
    }
  }

  String _timerText() {
    final minutes = (secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
                        SizedBox(height: metrics.pillToTitleGap),
                        PlanoraAuthIllustration(
                          lightAsset:
                              'assets/images/email_verification_light.png',
                          darkAsset:
                              'assets/images/email_verification_dark.png',
                          height: illustrationHeight,
                          fallbackIcon: Icons.mark_email_read_outlined,
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
                              const TextSpan(text: 'Verify your '),
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
                          'We sent a 6-digit verification code to $emailLabel.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: metrics.subtitleSize,
                            height: 1.45,
                            color: authBodyColor(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: metrics.titleToFormGap),
                        const PlanoraFieldLabel(label: 'Verification Code'),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, otpConstraints) {
                            final maxWidth = otpConstraints.maxWidth;
                            final boxWidth = ((maxWidth - 40) / codeLength)
                                .clamp(38.0, 46.0)
                                .toDouble();
                            final boxHeight = (boxWidth + 12)
                                .clamp(52.0, 58.0)
                                .toDouble();
                            final gap =
                                ((maxWidth - (boxWidth * codeLength)) /
                                        (codeLength - 1))
                                    .clamp(4.0, 10.0)
                                    .toDouble();

                            return Row(
                              children: List.generate(codeLength * 2 - 1, (
                                itemIndex,
                              ) {
                                if (itemIndex.isOdd) {
                                  return SizedBox(width: gap);
                                }

                                final index = itemIndex ~/ 2;
                                return _OtpBox(
                                  width: boxWidth,
                                  height: boxHeight,
                                  controller: codeControllers[index],
                                  focusNode: codeFocusNodes[index],
                                  onChanged: (value) =>
                                      _onCodeChanged(value, index),
                                );
                              }),
                            );
                          },
                        ),
                        SizedBox(height: metrics.sectionGap),
                        _ResendCodeRow(
                          canResend: canResend,
                          isLoading: isResending,
                          timerText: _timerText(),
                          onResend: _resendCode,
                        ),
                        SizedBox(height: metrics.sectionGap + 10),
                        PlanoraGradientButton(
                          height: metrics.buttonHeight,
                          label: isVerifying ? 'Verifying...' : 'Verify Email',
                          onPressed: canVerify && !isVerifying
                              ? _verifyEmail
                              : null,
                        ),
                        SizedBox(height: metrics.socialGap),
                        SizedBox(
                          height: metrics.socialButtonHeight,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(
                              Icons.email_outlined,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            label: const Text('Change Email'),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: authSurfaceColor(context),
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onSurface,
                              side: BorderSide(color: authBorderColor(context)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
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

class _OtpBox extends StatelessWidget {
  final double width;
  final double height;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _OtpBox({
    required this.width,
    required this.height,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(
            _EmailVerificationScreenState.codeLength,
          ),
        ],
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: authSurfaceColor(context),
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: authBorderColor(context)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1.8,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResendCodeRow extends StatelessWidget {
  final bool canResend;
  final bool isLoading;
  final String timerText;
  final VoidCallback onResend;

  const _ResendCodeRow({
    required this.canResend,
    required this.isLoading,
    required this.timerText,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          "Didn't receive the code? ",
          style: textTheme.bodySmall?.copyWith(
            color: authBodyColor(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        TextButton(
          onPressed: canResend ? onResend : null,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            minimumSize: const Size(44, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            disabledForegroundColor: authMutedColor(context),
          ),
          child: Text(
            isLoading
                ? 'Sending...'
                : canResend
                ? 'Resend'
                : 'Resend in $timerText',
          ),
        ),
      ],
    );
  }
}
