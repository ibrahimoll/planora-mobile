import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/planora_theme.dart';
import '../models/profile_info_section.dart';
import 'profile_api.dart';

Widget buildProfileSection(
  BuildContext context, {
  required String title,
  required List<dynamic> items,
}) {
  final isDark = PlanoraTheme.isDark(context);
  final mutedColor = isDark
      ? PlanoraTheme.darkTextMuted
      : PlanoraTheme.textSecondary;

  return TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 0, end: 1),
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) {
      return Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 18),
          child: child,
        ),
      );
    },
    child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
        ),
        boxShadow: PlanoraTheme.cardShadowFor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          for (var index = 0; index < items.length; index++) ...[
            _buildProfileActionTile(
              context,
              item: items[index],
              mutedColor: mutedColor,
            ),
            if (index != items.length - 1)
              Divider(
                height: 1,
                indent: 72,
                color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
              ),
          ],
        ],
      ),
    ),
  );
}

Widget _buildProfileActionTile(
  BuildContext context, {
  required dynamic item,
  required Color mutedColor,
}) {
  final icon = item.icon as IconData;
  final title = item.title as String;
  final subtitle = item.subtitle as String;
  final originalOnTap = item.onTap as VoidCallback;
  final onTap = title == 'Change Password'
      ? () => _showLiveChangePasswordSheet(context)
      : originalOnTap;

  return ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
    minVerticalPadding: 8,
    leading: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        size: 19,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
    title: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w900),
    ),
    subtitle: Text(
      subtitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: mutedColor, fontWeight: FontWeight.w600),
    ),
    trailing: Icon(Icons.chevron_right_rounded, color: mutedColor),
  );
}

Future<void> _showLiveChangePasswordSheet(BuildContext context) async {
  const profileApi = ProfileApi();
  final oldPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool obscureOld = true;
  bool obscureNew = true;
  bool obscureConfirm = true;
  bool isSaving = false;
  bool isSheetClosing = false;

  bool hasMinLength(String value) => value.length >= 8;
  bool hasUppercase(String value) => RegExp(r'[A-Z]').hasMatch(value);
  bool hasSymbol(String value) {
    return RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=/\\\[\];~`]').hasMatch(value);
  }

  bool isStrong(String value) {
    return hasMinLength(value) && hasUppercase(value) && hasSymbol(value);
  }

  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        void closeSheet() {
          if (isSheetClosing) return;
          isSheetClosing = true;
          FocusManager.instance.primaryFocus?.unfocus();
          if (Navigator.canPop(sheetContext)) {
            Navigator.of(sheetContext).pop();
          }
        }

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final newPassword = newPasswordController.text;
            final confirmPassword = confirmPasswordController.text;
            final minLengthMet = hasMinLength(newPassword);
            final uppercaseMet = hasUppercase(newPassword);
            final symbolMet = hasSymbol(newPassword);
            final matchMet =
                confirmPassword.isNotEmpty && newPassword == confirmPassword;
            final canSubmit = oldPasswordController.text.isNotEmpty &&
                isStrong(newPassword) &&
                matchMet &&
                !isSaving &&
                !isSheetClosing;

            void refreshRules(String _) {
              if (isSheetClosing) return;
              setSheetState(() {});
            }

            Future<void> submitPasswordChange() async {
              if (!canSubmit) return;

              setSheetState(() {
                isSaving = true;
              });

              var changedPassword = false;

              try {
                await profileApi.changePassword(
                  oldPassword: oldPasswordController.text,
                  newPassword: newPasswordController.text,
                );

                changedPassword = true;
                closeSheet();
                _showProfileSnack(context, 'Password changed successfully.');
              } on ApiException catch (error) {
                _showProfileSnack(context, error.message);
              } catch (error, stackTrace) {
                debugPrint('Password change failed: $error');
                debugPrintStack(stackTrace: stackTrace);
                _showProfileSnack(context, 'Could not change password.');
              } finally {
                if (!changedPassword && !isSheetClosing && sheetContext.mounted) {
                  setSheetState(() {
                    isSaving = false;
                  });
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.92,
                ),
                decoration: BoxDecoration(
                  color: PlanoraTheme.isDark(sheetContext)
                      ? PlanoraTheme.darkBackground
                      : Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: PlanoraTheme.floatingShadowFor(sheetContext),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: PlanoraTheme.isDark(sheetContext)
                                ? PlanoraTheme.darkBorder
                                : PlanoraTheme.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Theme.of(sheetContext)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              Icons.lock_reset_rounded,
                              color: Theme.of(sheetContext).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Change Password',
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          IconButton(
                            onPressed: isSaving ? null : closeSheet,
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const _PasswordIntroCard(),
                      const SizedBox(height: 18),
                      const _SheetLabel('Current password'),
                      const SizedBox(height: 8),
                      _PasswordField(
                        controller: oldPasswordController,
                        hintText: 'Enter your current password',
                        icon: Icons.lock_outline_rounded,
                        obscureText: obscureOld,
                        onChanged: refreshRules,
                        onToggleVisibility: () {
                          if (isSheetClosing) return;
                          setSheetState(() {
                            obscureOld = !obscureOld;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      const _SheetLabel('New password'),
                      const SizedBox(height: 8),
                      _PasswordField(
                        controller: newPasswordController,
                        hintText: 'Create a strong new password',
                        icon: Icons.password_rounded,
                        obscureText: obscureNew,
                        onChanged: refreshRules,
                        onToggleVisibility: () {
                          if (isSheetClosing) return;
                          setSheetState(() {
                            obscureNew = !obscureNew;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _PasswordRulesCard(
                        minLengthMet: minLengthMet,
                        uppercaseMet: uppercaseMet,
                        symbolMet: symbolMet,
                        showMatchRule: confirmPassword.isNotEmpty,
                        matchMet: matchMet,
                      ),
                      const SizedBox(height: 16),
                      const _SheetLabel('Confirm new password'),
                      const SizedBox(height: 8),
                      _PasswordField(
                        controller: confirmPasswordController,
                        hintText: 'Re-enter your new password',
                        icon: Icons.verified_user_outlined,
                        obscureText: obscureConfirm,
                        onChanged: refreshRules,
                        onToggleVisibility: () {
                          if (isSheetClosing) return;
                          setSheetState(() {
                            obscureConfirm = !obscureConfirm;
                          });
                        },
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: canSubmit ? submitPasswordChange : null,
                          icon: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.lock_reset_rounded),
                          label: Text(
                            isSaving
                                ? 'Updating password...'
                                : 'Update Password',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: TextButton(
                          onPressed: isSaving ? null : closeSheet,
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          'You will stay signed in after changing your password.',
                          textAlign: TextAlign.center,
                          style: Theme.of(sheetContext)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: _profileMutedColor(sheetContext),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  } finally {
    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }
}

void _showProfileSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Color _profileMutedColor(BuildContext context) {
  return PlanoraTheme.isDark(context)
      ? PlanoraTheme.darkTextMuted
      : PlanoraTheme.textSecondary;
}

class _SheetLabel extends StatelessWidget {
  final String text;

  const _SheetLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(fontWeight: FontWeight.w900),
    );
  }
}

class _PasswordIntroCard extends StatelessWidget {
  const _PasswordIntroCard();

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: isDark ? 0.16 : 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.shield_outlined, color: primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep your account protected',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Use a password that is hard to guess and different from your other accounts.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _profileMutedColor(context),
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final ValueChanged<String> onChanged;
  final VoidCallback onToggleVisibility;

  const _PasswordField({
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.obscureText,
    required this.onChanged,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon),
        suffixIcon: IconButton(
          tooltip: obscureText ? 'Show password' : 'Hide password',
          onPressed: onToggleVisibility,
          icon: Icon(
            obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }
}

class _PasswordRulesCard extends StatelessWidget {
  final bool minLengthMet;
  final bool uppercaseMet;
  final bool symbolMet;
  final bool showMatchRule;
  final bool matchMet;

  const _PasswordRulesCard({
    required this.minLengthMet,
    required this.uppercaseMet,
    required this.symbolMet,
    required this.showMatchRule,
    required this.matchMet,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
        ),
        boxShadow: PlanoraTheme.cardShadowFor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password requirements',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          _PasswordRule(text: 'At least 8 characters', isMet: minLengthMet),
          const SizedBox(height: 8),
          _PasswordRule(
            text: 'At least one uppercase letter',
            isMet: uppercaseMet,
          ),
          const SizedBox(height: 8),
          _PasswordRule(text: 'At least one symbol', isMet: symbolMet),
          if (showMatchRule) ...[
            const SizedBox(height: 8),
            _PasswordRule(text: 'Passwords match', isMet: matchMet),
          ],
        ],
      ),
    );
  }
}

class _PasswordRule extends StatelessWidget {
  final String text;
  final bool isMet;

  const _PasswordRule({required this.text, required this.isMet});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final inactiveColor = _profileMutedColor(context);
    final color = isMet ? primary : inactiveColor;

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isMet ? 0.14 : 0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Icon(
              isMet ? Icons.check_rounded : Icons.close_rounded,
              key: ValueKey(isMet),
              size: 14,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 160),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ) ??
                TextStyle(color: color, fontWeight: FontWeight.w700),
            child: Text(text),
          ),
        ),
      ],
    );
  }
}

class ProfileInfoContent {
  const ProfileInfoContent._();

  static const String betaSupportEmail = 'planora.verify@gmail.com';

  static const List<ProfileInfoSection> helpSupport = [
    ProfileInfoSection(
      title: 'Beta support',
      body:
          'Planora is currently in beta. Some features may still be incomplete, limited, or under active testing. If something does not work as expected, report the issue with enough detail so it can be reproduced and fixed.',
    ),
    ProfileInfoSection(
      title: 'What to include in a support request',
      body:
          'When reporting an issue, include your account email, username, the screen you were using, the project or task name if relevant, the exact action you tried, and the error message you saw.',
    ),
    ProfileInfoSection(
      title: 'Account and login issues',
      body:
          'For login, password, verification, or profile problems, mention whether the issue happened during login, registration, email verification, password reset, profile update, or password change.',
    ),
    ProfileInfoSection(
      title: 'Known beta limitations',
      body:
          'Some settings are currently informational only. Advanced email preferences, per-channel notification settings, billing management, subscription management, and full account deletion are not fully exposed in the mobile app yet.',
    ),
    ProfileInfoSection(
      title: 'Contact',
      body:
          'For beta support, contact Planora support at planora.verify@gmail.com. Include your account email, username, the screen where the problem happened, and the exact error message if one appeared.',
    ),
  ];

  static const List<ProfileInfoSection> subscription = [
    ProfileInfoSection(
      title: 'Planora Beta Access',
      body:
          'Your account is currently using the standard Planora beta workspace experience. During beta, paid plans, upgrades, downgrades, billing, and invoices are not available in the mobile app.',
    ),
    ProfileInfoSection(
      title: 'Current plan',
      body: 'Plan: Beta Access\nPrice: Free during beta\nRenewal: Not applicable',
    ),
    ProfileInfoSection(
      title: 'Included in beta',
      body:
          'Projects and task management\nTeam collaboration\nInvitations and comments\nNotifications\nProfile and account settings\nAttachments, when enabled\nAI planning features, when available',
    ),
    ProfileInfoSection(
      title: 'Future subscription plans',
      body:
          'Paid plans may be added later for larger teams, advanced AI usage, additional storage, or workspace-level features.',
    ),
  ];

  static const List<ProfileInfoSection> billingAndInvoices = [
    ProfileInfoSection(
      title: 'Billing is not available',
      body:
          'Planora does not currently expose billing, payment methods, invoices, upgrades, downgrades, or subscription cancellation in the mobile app.',
    ),
    ProfileInfoSection(
      title: 'Current beta status',
      body:
          'No payment method is required for Planora beta access. Billing history and invoice downloads will only make sense after production billing is added to the backend.',
    ),
  ];

  static const List<ProfileInfoSection> privacyPolicy = [
    ProfileInfoSection(title: 'Last updated', body: 'June 14, 2026'),
    ProfileInfoSection(
      title: 'Overview',
      body:
          'Planora is an AI-powered project planning and collaboration app. This policy explains what information Planora handles to provide accounts, projects, tasks, teams, notifications, attachments, comments, and AI-assisted planning features.',
    ),
    ProfileInfoSection(
      title: 'Information we collect',
      body:
          'Planora may store account and profile information such as username, email address, full name, role, email verification status, profile picture, and account creation date. Planora also stores the content you create or share, including projects, tasks, teams, invitations, comments, attachments, notifications, and AI chat or planning messages.',
    ),
    ProfileInfoSection(
      title: 'Your choices',
      body:
          'You can update supported profile information from the Profile page and change your password through the password screen. Features such as full account deletion, advanced privacy settings, and per-channel notification preferences are not currently exposed in the mobile app.',
    ),
    ProfileInfoSection(
      title: 'Contact',
      body:
          'For privacy questions or support requests, contact Planora support at planora.verify@gmail.com.',
    ),
  ];

  static const List<ProfileInfoSection> terms = [
    ProfileInfoSection(title: 'Last updated', body: 'June 14, 2026'),
    ProfileInfoSection(
      title: 'Acceptance of terms',
      body:
          'By using Planora, you agree to use the app responsibly for lawful project planning, task management, team collaboration, and AI-assisted productivity workflows.',
    ),
    ProfileInfoSection(
      title: 'Account responsibility',
      body:
          'You are responsible for keeping your login credentials secure and for all activity performed through your account. If you believe your account is no longer secure, change your password and contact support at planora.verify@gmail.com.',
    ),
    ProfileInfoSection(
      title: 'Acceptable use',
      body:
          'Do not use Planora to upload illegal content, abuse other users, share malware, expose secrets, violate intellectual property rights, disrupt the service, or attempt unauthorized access to accounts, systems, projects, teams, or backend data.',
    ),
    ProfileInfoSection(
      title: 'Contact',
      body:
          'For questions about these terms, contact Planora support at planora.verify@gmail.com.',
    ),
  ];

  static List<ProfileInfoSection>? sectionsForTitle(String title) {
    switch (title) {
      case 'Help & Support':
        return helpSupport;
      case 'Subscription':
        return subscription;
      case 'Billing & Invoices':
        return billingAndInvoices;
      case 'Privacy Policy':
        return privacyPolicy;
      case 'Terms of Service':
        return terms;
      default:
        return null;
    }
  }
}
