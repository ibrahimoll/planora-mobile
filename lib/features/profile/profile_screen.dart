import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/planora_theme.dart';
import '../auth/models/auth_models.dart';
import 'data/profile_api.dart';

class ProfileScreen extends StatefulWidget {
  final UserResponse user;
  final VoidCallback onThemeToggle;
  final VoidCallback onLoggedOut;
  final ValueChanged<UserResponse>? onUserUpdated;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.onThemeToggle,
    required this.onLoggedOut,
    this.onUserUpdated,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileApi _profileApi = const ProfileApi();

  late UserResponse user = widget.user;
  bool isLoading = false;
  String? errorMessage;

  String get displayName {
    final fullName = user.fullName.trim();
    return fullName.isNotEmpty ? fullName : user.username;
  }

  String get initials {
    final source = displayName.trim();

    if (source.isEmpty) return 'P';

    final parts = source.split(RegExp(r'\s+'));

    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }

    return source[0].toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final loadedUser = await _profileApi.getProfile();

      if (!mounted) return;

      setState(() {
        user = loadedUser;
        isLoading = false;
      });

      widget.onUserUpdated?.call(loadedUser);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Could not refresh profile.';
        isLoading = false;
      });
    }
  }

  Color mutedColor(BuildContext context) {
    return PlanoraTheme.isDark(context)
        ? PlanoraTheme.darkTextMuted
        : PlanoraTheme.textSecondary;
  }

  BoxDecoration cardDecoration(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return BoxDecoration(
      color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
      ),
      boxShadow: PlanoraTheme.cardShadowFor(context),
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget buildHeader(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 44,
            height: 44,
            decoration: cardDecoration(context),
            child: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'Profile',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        IconButton(
          tooltip: 'Refresh profile',
          onPressed: isLoading ? null : loadProfile,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget buildProfileCard(BuildContext context) {
    final hasProfilePic =
        user.profilePic != null && user.profilePic!.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: cardDecoration(context),
      child: Column(
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: Theme.of(context).colorScheme.primary,
            backgroundImage: hasProfilePic
                ? NetworkImage(user.profilePic!)
                : null,
            child: hasProfilePic
                ? null
                : Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            user.email,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: mutedColor(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              buildPill(context, '@${user.username}'),
              buildPill(
                context,
                user.isEmailVerified ? 'Verified' : 'Email pending',
              ),
              buildPill(context, user.role),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildPill(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget buildMenuCard(BuildContext context) {
    return Container(
      decoration: cardDecoration(context),
      child: Column(
        children: [
          buildMenuTile(
            context,
            icon: Icons.edit_outlined,
            title: 'Edit Profile',
            subtitle: 'Update your name and username',
            onTap: showEditProfileSheet,
          ),
          buildDivider(context),
          buildMenuTile(
            context,
            icon: Icons.lock_outline_rounded,
            title: 'Change Password',
            subtitle: 'Use a strong password with a symbol',
            onTap: showChangePasswordSheet,
          ),
          buildDivider(context),
          buildMenuTile(
            context,
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'Theme and API configuration',
            onTap: showSettingsSheet,
          ),
        ],
      ),
    );
  }

  Widget buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      minVerticalPadding: 14,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: mutedColor(context),
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: mutedColor(context)),
    );
  }

  Widget buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      indent: 72,
      color: PlanoraTheme.isDark(context)
          ? PlanoraTheme.darkBorder
          : PlanoraTheme.border,
    );
  }

  Widget buildErrorBanner(BuildContext context) {
    if (errorMessage == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PlanoraTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: PlanoraTheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              errorMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: PlanoraTheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> showEditProfileSheet() async {
    final usernameController = TextEditingController(text: user.username);
    final fullNameController = TextEditingController(text: user.fullName);
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return buildSheetSurface(
              sheetContext,
              title: 'Edit Profile',
              icon: Icons.edit_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildSheetLabel(sheetContext, 'Full Name'),
                  const SizedBox(height: 8),
                  buildSheetTextField(
                    sheetContext,
                    controller: fullNameController,
                    hintText: 'Enter your full name',
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 16),
                  buildSheetLabel(sheetContext, 'Username'),
                  const SizedBox(height: 8),
                  buildSheetTextField(
                    sheetContext,
                    controller: usernameController,
                    hintText: 'Choose a username',
                    icon: Icons.alternate_email_rounded,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final username = usernameController.text.trim();
                              final fullName = fullNameController.text.trim();

                              if (fullName.isEmpty) {
                                showMessage('Full name is required.');
                                return;
                              }

                              if (!RegExp(
                                r'^[A-Za-z0-9_]{3,50}$',
                              ).hasMatch(username)) {
                                showMessage(
                                  'Username must be 3-50 letters, numbers, or underscores.',
                                );
                                return;
                              }

                              setSheetState(() {
                                isSaving = true;
                              });

                              try {
                                final updatedUser = await _profileApi
                                    .updateProfile(
                                      username: username,
                                      fullName: fullName,
                                    );

                                if (!mounted || !sheetContext.mounted) return;

                                setState(() {
                                  user = updatedUser;
                                });

                                widget.onUserUpdated?.call(updatedUser);
                                Navigator.of(sheetContext).pop();
                                showMessage('Profile updated successfully.');
                              } on ApiException catch (error) {
                                if (!mounted) return;
                                showMessage(error.message);
                              } catch (_) {
                                if (!mounted) return;
                                showMessage('Could not update profile.');
                              } finally {
                                if (sheetContext.mounted) {
                                  setSheetState(() {
                                    isSaving = false;
                                  });
                                }
                              }
                            },
                      child: Text(isSaving ? 'Saving...' : 'Save Changes'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    usernameController.dispose();
    fullNameController.dispose();
  }

  Future<void> showChangePasswordSheet() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureOld = true;
    bool obscureNew = true;
    bool isSaving = false;

    bool strongPassword(String password) {
      return password.length >= 8 &&
          RegExp(r'[A-Z]').hasMatch(password) &&
          RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\[\];~`]').hasMatch(password);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return buildSheetSurface(
              sheetContext,
              title: 'Change Password',
              icon: Icons.lock_outline_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildSheetLabel(sheetContext, 'Current Password'),
                  const SizedBox(height: 8),
                  buildSheetTextField(
                    sheetContext,
                    controller: oldPasswordController,
                    hintText: 'Enter current password',
                    icon: Icons.lock_outline_rounded,
                    obscureText: obscureOld,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setSheetState(() {
                          obscureOld = !obscureOld;
                        });
                      },
                      icon: Icon(
                        obscureOld
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  buildSheetLabel(sheetContext, 'New Password'),
                  const SizedBox(height: 8),
                  buildSheetTextField(
                    sheetContext,
                    controller: newPasswordController,
                    hintText: 'Enter new password',
                    icon: Icons.lock_reset_rounded,
                    obscureText: obscureNew,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setSheetState(() {
                          obscureNew = !obscureNew;
                        });
                      },
                      icon: Icon(
                        obscureNew
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  buildSheetLabel(sheetContext, 'Confirm Password'),
                  const SizedBox(height: 8),
                  buildSheetTextField(
                    sheetContext,
                    controller: confirmPasswordController,
                    hintText: 'Confirm new password',
                    icon: Icons.verified_user_outlined,
                    obscureText: obscureNew,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final oldPassword = oldPasswordController.text;
                              final newPassword = newPasswordController.text;
                              final confirmPassword =
                                  confirmPasswordController.text;

                              if (oldPassword.isEmpty) {
                                showMessage('Current password is required.');
                                return;
                              }

                              if (!strongPassword(newPassword)) {
                                showMessage(
                                  'New password must be 8+ characters with uppercase and symbol.',
                                );
                                return;
                              }

                              if (newPassword != confirmPassword) {
                                showMessage('New passwords do not match.');
                                return;
                              }

                              setSheetState(() {
                                isSaving = true;
                              });

                              try {
                                await _profileApi.changePassword(
                                  oldPassword: oldPassword,
                                  newPassword: newPassword,
                                );

                                if (!mounted || !sheetContext.mounted) return;

                                Navigator.of(sheetContext).pop();
                                showMessage('Password changed successfully.');
                              } on ApiException catch (error) {
                                if (!mounted) return;
                                showMessage(error.message);
                              } catch (_) {
                                if (!mounted) return;
                                showMessage('Could not change password.');
                              } finally {
                                if (sheetContext.mounted) {
                                  setSheetState(() {
                                    isSaving = false;
                                  });
                                }
                              }
                            },
                      child: Text(isSaving ? 'Updating...' : 'Change Password'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  Future<void> showSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return buildSheetSurface(
          sheetContext,
          title: 'Settings',
          icon: Icons.settings_outlined,
          child: Column(
            children: [
              buildSettingsRow(
                sheetContext,
                icon: Icons.dark_mode_outlined,
                title: 'Theme',
                subtitle: 'Toggle light and dark mode',
                trailing: Switch(
                  value: PlanoraTheme.isDark(context),
                  onChanged: (_) => widget.onThemeToggle(),
                ),
              ),
              const SizedBox(height: 12),
              buildSettingsRow(
                sheetContext,
                icon: Icons.cloud_outlined,
                title: 'API URL',
                subtitle: AppConfig.apiBaseUrl,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildSheetSurface(
    BuildContext sheetContext, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final isDark = PlanoraTheme.isDark(sheetContext);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.90,
        ),
        decoration: BoxDecoration(
          color: isDark ? PlanoraTheme.darkBackground : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
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
                    color: isDark
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
                      color: Theme.of(
                        sheetContext,
                      ).colorScheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      icon,
                      color: Theme.of(sheetContext).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSheetLabel(BuildContext context, String label) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900),
    );
  }

  Widget buildSheetTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget buildSettingsRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(context),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mutedColor(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing],
        ],
      ),
    );
  }

  Widget buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: () {
          widget.onLoggedOut();
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Logout'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: PlanoraTheme.onboardingBackgroundFor(context),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: RefreshIndicator(
                onRefresh: loadProfile,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: [
                    buildHeader(context),
                    const SizedBox(height: 16),
                    if (isLoading) const LinearProgressIndicator(minHeight: 3),
                    if (errorMessage != null) ...[
                      buildErrorBanner(context),
                      const SizedBox(height: 14),
                    ],
                    buildProfileCard(context),
                    const SizedBox(height: 16),
                    buildMenuCard(context),
                    const SizedBox(height: 16),
                    buildLogoutButton(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
