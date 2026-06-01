import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/planora_theme.dart';
import '../auth/shared/auth_responsive_metrics.dart';

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

  void _onCodeChanged(String value, int index) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '').split('');

      for (int i = 0; i < codeLength; i++) {
        codeControllers[i].text = i < digits.length ? digits[i] : '';
      }

      final nextIndex = digits.length >= codeLength
          ? codeLength - 1
          : digits.length;

      codeFocusNodes[nextIndex.clamp(0, codeLength - 1)].requestFocus();

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

  void _verifyEmail() {
    if (!canVerify) {
      _showMessage('Please enter the 6-digit verification code');
      return;
    }

    _showMessage('Verify email API connection coming next');
  }

  void _resendCode() {
    if (!canResend) return;

    _showMessage('Resend verification code API connection coming next');
    _startTimer();
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
                          'assets/images/email_verification.png',
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
                              const TextSpan(text: 'Verify your '),
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
                          'We sent a 6-digit verification code\nto your email address.',
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

                        _FieldLabel(label: 'Verification Code', isDark: isDark),

                        const SizedBox(height: 10),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            codeLength,
                            (index) => _OtpBox(
                              controller: codeControllers[index],
                              focusNode: codeFocusNodes[index],
                              isDark: isDark,
                              onChanged: (value) =>
                                  _onCodeChanged(value, index),
                            ),
                          ),
                        ),

                        SizedBox(height: metrics.sectionGap),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Didn’t receive the code? ',
                              style: textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? const Color(0xFFC8CAD5)
                                    : PlanoraTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            GestureDetector(
                              onTap: canResend ? _resendCode : null,
                              child: Text(
                                canResend
                                    ? 'Resend'
                                    : 'Resend in ${_timerText()}',
                                style: textTheme.bodySmall?.copyWith(
                                  color: canResend
                                      ? isDark
                                            ? const Color(0xFFA78BFA)
                                            : PlanoraTheme.primaryPurple
                                      : isDark
                                      ? const Color(0xFFA78BFA)
                                      : PlanoraTheme.primaryPurple,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: metrics.sectionGap + 10),

                        _GradientActionButton(
                          isDark: isDark,
                          height: metrics.buttonHeight,
                          label: 'Verify Email',
                          onPressed: _verifyEmail,
                        ),

                        SizedBox(height: metrics.socialGap),

                        SizedBox(
                          height: metrics.socialButtonHeight,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(
                              Icons.email_outlined,
                              size: 18,
                              color: isDark
                                  ? const Color(0xFFA78BFA)
                                  : PlanoraTheme.primaryPurple,
                            ),
                            label: const Text('Change Email'),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: isDark
                                  ? const Color(0xFF1D202C)
                                  : PlanoraTheme.surface,
                              foregroundColor: isDark
                                  ? Colors.white
                                  : PlanoraTheme.textPrimary,
                              side: BorderSide(
                                color: isDark
                                    ? const Color(0xFF2A2D3A)
                                    : PlanoraTheme.border,
                              ),
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
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final ValueChanged<String> onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 58,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(
          color: isDark ? Colors.white : PlanoraTheme.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: isDark ? const Color(0xFF1D202C) : PlanoraTheme.surface,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF2A2D3A) : PlanoraTheme.border,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: isDark
                  ? const Color(0xFF8B5CF6)
                  : PlanoraTheme.primaryPurple,
              width: 1.8,
            ),
          ),
        ),
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
