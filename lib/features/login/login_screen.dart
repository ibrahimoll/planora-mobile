import 'package:flutter/material.dart';

import '../../../core/theme/planora_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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
              constraints: const BoxConstraints(maxWidth: 430),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: isDark
                              ? Colors.white
                              : PlanoraTheme.textPrimary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Image.asset(
                      'assets/images/planora_logo.png',
                      height: 82,
                      fit: BoxFit.contain,
                    ),

                    const SizedBox(height: 10),

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

                    const SizedBox(height: 28),

                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: textTheme.headlineSmall?.copyWith(
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
                        color: isDark
                            ? const Color(0xFFC8CAD5)
                            : PlanoraTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 34),

                    _FieldLabel(label: 'Email', isDark: isDark),

                    const SizedBox(height: 8),

                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      style: TextStyle(
                        color: isDark ? Colors.white : PlanoraTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: _inputDecoration(
                        context: context,
                        hintText: 'Enter your email',
                        prefixIcon: Icons.email_outlined,
                      ),
                    ),

                    const SizedBox(height: 18),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _FieldLabel(label: 'Password', isDark: isDark),
                        GestureDetector(
                          onTap: () => _showComingLater(
                            'Forgot password screen coming next',
                          ),
                          child: Text(
                            'Forgot password?',
                            style: textTheme.labelSmall?.copyWith(
                              color: isDark
                                  ? const Color(0xFFA78BFA)
                                  : PlanoraTheme.primaryPurple,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      textInputAction: TextInputAction.done,
                      style: TextStyle(
                        color: isDark ? Colors.white : PlanoraTheme.textPrimary,
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

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: rememberMe,
                            onChanged: (value) {
                              setState(() {
                                rememberMe = value ?? false;
                              });
                            },
                            activeColor: isDark
                                ? const Color(0xFF8B5CF6)
                                : PlanoraTheme.primaryPurple,
                            checkColor: Colors.white,
                            side: BorderSide(
                              color: isDark
                                  ? const Color(0xFF2A2D3A)
                                  : PlanoraTheme.border,
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
                            color: isDark
                                ? Colors.white
                                : PlanoraTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      height: 58,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: isDark
                              ? const LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Color(0xFF6D47DB),
                                    Color(0xFF8B5CF6),
                                  ],
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
                          onPressed: () => _showComingLater(
                            'Backend login connection coming next',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 26),

                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: isDark
                                ? const Color(0xFF2A2D3A)
                                : PlanoraTheme.divider,
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
                            color: isDark
                                ? const Color(0xFF2A2D3A)
                                : PlanoraTheme.divider,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    _SocialButton(
                      label: 'Google',
                      logo: const _GoogleLogo(),
                      onTap: () => _showComingLater(
                        'Google login connection coming next',
                      ),
                    ),

                    const SizedBox(height: 12),

                    _SocialButton(
                      label: 'Microsoft',
                      logo: const _MicrosoftLogo(),
                      onTap: () =>
                          _showComingLater('Microsoft login coming later'),
                    ),

                    const SizedBox(height: 30),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don’t have an account? ",
                          style: textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? const Color(0xFFC8CAD5)
                                : PlanoraTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              _showComingLater('Register screen coming next'),
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
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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

class _SocialButton extends StatelessWidget {
  final String label;
  final Widget logo;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label,
    required this.logo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return SizedBox(
      height: 56,
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

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _MicrosoftLogo extends StatelessWidget {
  const _MicrosoftLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 17,
      height: 17,
      child: GridView.count(
        crossAxisCount: 2,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        children: const [
          ColoredBox(color: Color(0xFFF25022)),
          ColoredBox(color: Color(0xFF7FBA00)),
          ColoredBox(color: Color(0xFF00A4EF)),
          ColoredBox(color: Color(0xFFFFB900)),
        ],
      ),
    );
  }
}
