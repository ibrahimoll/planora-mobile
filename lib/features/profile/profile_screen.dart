import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/planora_theme.dart';
import '../auth/models/auth_models.dart';
import 'data/profile_api.dart';
import 'data/profile_info_content.dart';
import 'models/profile_info_section.dart';
import 'widgets/profile_info_screen.dart';

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

  String get initials => initialsFor(displayName);

  int get daysActive {
    final created = user.createdAt.toLocal();
    final startDay = DateTime(created.year, created.month, created.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = today.difference(startDay).inDays + 1;
    return days < 1 ? 1 : days;
  }

  String get accountBadgeLabel {
    if (!user.isEmailVerified) return 'Email pending';
    final role = user.role.trim();
    if (role.isEmpty) return 'Verified';
    return '${role[0].toUpperCase()}${role.substring(1)}';
  }

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  String initialsFor(String value) {
    final source = value.trim();
    if (source.isEmpty) return 'P';

    final parts = source.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }

    return source[0].toUpperCase();
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
    } catch (error, stackTrace) {
      debugPrint('Profile refresh failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Could not refresh profile.';
      });
    }
  }

  Future<void> refreshProfile() async {
    await loadProfile();
  }

  Future<void> openProfileInfoPage({
    required String title,
    required IconData icon,
    String? body,
    List<ProfileInfoSection>? sections,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileInfoScreen(
          title: title,
          icon: icon,
          body: body,
          sections: sections,
        ),
      ),
    );
  }

  void handleLogout() {
    final onLoggedOut = widget.onLoggedOut;
    Navigator.of(context).popUntil((route) => route.isFirst);
    onLoggedOut();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String errorText(Object error, String fallback) {
    if (error is ApiException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    return fallback;
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
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
      ),
      boxShadow: PlanoraTheme.cardShadowFor(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Scaffold(
      backgroundColor: isDark
          ? PlanoraTheme.darkBackground
          : PlanoraTheme.background,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: PlanoraTheme.onboardingBackgroundFor(context),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: refreshProfile,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildStaggeredItem(0, buildHeader(context)),
                        const SizedBox(height: 18),
                        if (errorMessage != null) ...[
                          buildStaggeredItem(
                            1,
                            buildErrorBanner(context, errorMessage!),
                          ),
                          const SizedBox(height: 14),
                        ],
                        buildStaggeredItem(2, buildProfileCard(context)),
                        const SizedBox(height: 18),
                        buildStaggeredItem(3, buildStatsCard(context)),
                        const SizedBox(height: 20),
                        buildStaggeredItem(
                          4,
                          buildSection(
                            context,
                            title: 'Account',
                            tiles: [
                              ProfileTileData(
                                icon: Icons.person_outline_rounded,
                                title: 'Edit Profile',
                                subtitle: 'Update your personal information',
                                onTap: showEditProfileSheet,
                              ),
                              ProfileTileData(
                                icon: Icons.lock_outline_rounded,
                                title: 'Change Password',
                                subtitle: 'Secure your account',
                                onTap: showChangePasswordSheet,
                              ),
                              ProfileTileData(
                                icon: Icons.mail_outline_rounded,
                                title: 'Email Preferences',
                                subtitle: 'Manage beta email updates',
                                onTap: () => openProfileInfoPage(
                                  title: 'Email Preferences',
                                  icon: Icons.mail_outline_rounded,
                                  sections: ProfileInfoContent.emailPreferences,
                                ),
                              ),
                              ProfileTileData(
                                icon: Icons.notifications_none_rounded,
                                title: 'Notification Settings',
                                subtitle: 'Review notification behavior',
                                onTap: () => openProfileInfoPage(
                                  title: 'Notification Settings',
                                  icon: Icons.notifications_none_rounded,
                                  sections:
                                      ProfileInfoContent.notificationSettings,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        buildStaggeredItem(
                          5,
                          buildSection(
                            context,
                            title: 'Plan & Billing',
                            tiles: [
                              ProfileTileData(
                                icon: Icons.workspace_premium_outlined,
                                title: 'Subscription Plan',
                                subtitle: 'View your current Planora plan',
                                onTap: () => openProfileInfoPage(
                                  title: 'Subscription',
                                  icon: Icons.workspace_premium_outlined,
                                  sections: ProfileInfoContent.subscription,
                                ),
                              ),
                              ProfileTileData(
                                icon: Icons.credit_card_outlined,
                                title: 'Billing & Invoices',
                                subtitle: 'Review billing availability',
                                onTap: () => openProfileInfoPage(
                                  title: 'Billing & Invoices',
                                  icon: Icons.credit_card_outlined,
                                  sections:
                                      ProfileInfoContent.billingAndInvoices,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        buildStaggeredItem(
                          6,
                          buildSection(
                            context,
                            title: 'More',
                            tiles: [
                              ProfileTileData(
                                icon: Icons.settings_outlined,
                                title: 'Settings',
                                subtitle: 'Theme and app preferences',
                                onTap: showSettingsSheet,
                              ),
                              ProfileTileData(
                                icon: Icons.help_outline_rounded,
                                title: 'Help & Support',
                                subtitle: 'Get help using Planora',
                                onTap: () => openProfileInfoPage(
                                  title: 'Help & Support',
                                  icon: Icons.help_outline_rounded,
                                  sections: ProfileInfoContent.helpSupport,
                                ),
                              ),
                              ProfileTileData(
                                icon: Icons.shield_outlined,
                                title: 'Privacy Policy',
                                subtitle: 'How Planora handles your data',
                                onTap: () => openProfileInfoPage(
                                  title: 'Privacy Policy',
                                  icon: Icons.shield_outlined,
                                  sections: ProfileInfoContent.privacyPolicy,
                                ),
                              ),
                              ProfileTileData(
                                icon: Icons.description_outlined,
                                title: 'Terms of Service',
                                subtitle: 'Planora beta usage terms',
                                onTap: () => openProfileInfoPage(
                                  title: 'Terms of Service',
                                  icon: Icons.description_outlined,
                                  sections: ProfileInfoContent.terms,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        buildStaggeredItem(7, buildLogoutButton(context)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildStaggeredItem(int index, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (index * 55)),
      curve: Curves.easeOutCubic,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: animatedChild,
          ),
        );
      },
      child: child,
    );
  }

  Widget buildHeader(BuildContext context) {
    return Row(
      children: [
        buildCircleButton(
          context,
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back',
          onTap: () => Navigator.of(context).pop(),
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
        buildCircleButton(
          context,
          icon: Icons.settings_outlined,
          tooltip: 'Settings',
          onTap: showSettingsSheet,
        ),
      ],
    );
  }

  Widget buildCircleButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            width: 44,
            height: 44,
            decoration: cardDecoration(
              context,
            ).copyWith(borderRadius: BorderRadius.circular(999)),
            child: Icon(icon, size: 21),
          ),
        ),
      ),
    );
  }

  Widget buildErrorBanner(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PlanoraTheme.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PlanoraTheme.error.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: PlanoraTheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: PlanoraTheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildProfileCard(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: showEditProfileSheet,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: cardDecoration(context),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  buildProfileAvatar(context, radius: 36),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: PlanoraTheme.isDark(context)
                              ? PlanoraTheme.darkSurface
                              : Colors.white,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.edit_outlined,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: mutedColor(context),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 10),
                    buildBadge(context, accountBadgeLabel),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: mutedColor(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildProfileAvatar(BuildContext context, {required double radius}) {
    final imageUrl = user.profilePic;
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: imageUrl == null ? PlanoraTheme.primaryGradientFor(context) : null,
        image: imageUrl == null
            ? null
            : DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
              ),
        boxShadow: PlanoraTheme.floatingShadowFor(context),
      ),
      child: imageUrl == null
          ? Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: radius * 0.62,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : null,
    );
  }

  Widget buildBadge(BuildContext context, String label) {
    final isVerified = user.isEmailVerified;
    final badgeColor = isVerified ? PlanoraTheme.success : PlanoraTheme.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: badgeColor.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: badgeColor,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget buildStatsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(context),
      child: Row(
        children: [
          Expanded(
            child: buildStatItem(
              context,
              icon: Icons.calendar_month_outlined,
              label: 'Days active',
              value: '$daysActive',
            ),
          ),
          buildVerticalDivider(context),
          Expanded(
            child: buildStatItem(
              context,
              icon: Icons.verified_user_outlined,
              label: 'Status',
              value: user.isActive ? 'Active' : 'Inactive',
            ),
          ),
          buildVerticalDivider(context),
          Expanded(
            child: buildStatItem(
              context,
              icon: Icons.badge_outlined,
              label: 'Role',
              value: user.role.isEmpty ? 'User' : user.role,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildVerticalDivider(BuildContext context) {
    return Container(
      width: 1,
      height: 46,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: PlanoraTheme.isDark(context)
          ? PlanoraTheme.darkDivider
          : PlanoraTheme.divider,
    );
  }

  Widget buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: mutedColor(context),
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  Widget buildSection(
    BuildContext context, {
    required String title,
    required List<ProfileTileData> tiles,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: mutedColor(context),
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        Container(
          decoration: cardDecoration(context),
          child: Column(
            children: [
              for (var index = 0; index < tiles.length; index++) ...[
                buildProfileTile(context, tiles[index]),
                if (index != tiles.length - 1) buildDivider(context),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget buildProfileTile(BuildContext context, ProfileTileData tile) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: tile.onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  tile.icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tile.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tile.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: mutedColor(context),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: mutedColor(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      indent: 68,
      color: PlanoraTheme.isDark(context)
          ? PlanoraTheme.darkDivider
          : PlanoraTheme.divider,
    );
  }

  Widget buildLogoutButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: handleLogout,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: PlanoraTheme.error.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: PlanoraTheme.error.withValues(alpha: 0.22)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: PlanoraTheme.error),
              SizedBox(width: 10),
              Text(
                'Log out',
                style: TextStyle(
                  color: PlanoraTheme.error,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> showEditProfileSheet() async {
    final usernameController = TextEditingController(text: user.username);
    final fullNameController = TextEditingController(text: user.fullName);

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          bool isSaving = false;

          return StatefulBuilder(
            builder: (context, setSheetState) {
              Future<void> saveProfile() async {
                final username = usernameController.text.trim();
                final fullName = fullNameController.text.trim();

                if (username.isEmpty || fullName.isEmpty) {
                  showMessage('Username and full name are required.');
                  return;
                }

                setSheetState(() => isSaving = true);

                try {
                  final updatedUser = await _profileApi.updateProfile(
                    username: username,
                    fullName: fullName,
                  );
                  if (!mounted) return;

                  setState(() => user = updatedUser);
                  widget.onUserUpdated?.call(updatedUser);
                  Navigator.of(sheetContext).pop();
                  showMessage('Profile updated.');
                } catch (error, stackTrace) {
                  debugPrint('Profile update failed: $error');
                  debugPrintStack(stackTrace: stackTrace);
                  if (!mounted) return;
                  showMessage(errorText(error, 'Could not update profile.'));
                  setSheetState(() => isSaving = false);
                }
              }

              return buildSheetScaffold(
                context,
                title: 'Edit Profile',
                subtitle: 'Update the details shown on your Planora account.',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: fullNameController,
                      textInputAction: TextInputAction.next,
                      decoration: inputDecoration(
                        context,
                        label: 'Full name',
                        icon: Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: usernameController,
                      textInputAction: TextInputAction.done,
                      decoration: inputDecoration(
                        context,
                        label: 'Username',
                        icon: Icons.alternate_email_rounded,
                      ),
                      onSubmitted: (_) {
                        if (!isSaving) saveProfile();
                      },
                    ),
                    const SizedBox(height: 18),
                    buildPrimarySheetButton(
                      context,
                      label: isSaving ? 'Saving...' : 'Save changes',
                      icon: Icons.check_rounded,
                      onPressed: isSaving ? null : saveProfile,
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } finally {
      usernameController.dispose();
      fullNameController.dispose();
    }
  }

  Future<void> showChangePasswordSheet() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          bool isSaving = false;
          bool hideOldPassword = true;
          bool hideNewPassword = true;
          bool hideConfirmPassword = true;

          return StatefulBuilder(
            builder: (context, setSheetState) {
              Future<void> savePassword() async {
                final oldPassword = oldPasswordController.text;
                final newPassword = newPasswordController.text;
                final confirmPassword = confirmPasswordController.text;

                if (oldPassword.isEmpty || newPassword.isEmpty) {
                  showMessage('Password fields are required.');
                  return;
                }

                if (newPassword.length < 8) {
                  showMessage('New password must be at least 8 characters.');
                  return;
                }

                if (newPassword != confirmPassword) {
                  showMessage('New passwords do not match.');
                  return;
                }

                setSheetState(() => isSaving = true);

                try {
                  await _profileApi.changePassword(
                    oldPassword: oldPassword,
                    newPassword: newPassword,
                  );
                  if (!mounted) return;

                  Navigator.of(sheetContext).pop();
                  showMessage('Password changed.');
                } catch (error, stackTrace) {
                  debugPrint('Password update failed: $error');
                  debugPrintStack(stackTrace: stackTrace);
                  if (!mounted) return;
                  showMessage(errorText(error, 'Could not change password.'));
                  setSheetState(() => isSaving = false);
                }
              }

              return buildSheetScaffold(
                context,
                title: 'Change Password',
                subtitle: 'Use a strong password to keep your account safe.',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    buildPasswordField(
                      context,
                      controller: oldPasswordController,
                      label: 'Current password',
                      obscureText: hideOldPassword,
                      onToggle: () => setSheetState(
                        () => hideOldPassword = !hideOldPassword,
                      ),
                    ),
                    const SizedBox(height: 14),
                    buildPasswordField(
                      context,
                      controller: newPasswordController,
                      label: 'New password',
                      obscureText: hideNewPassword,
                      onToggle: () => setSheetState(
                        () => hideNewPassword = !hideNewPassword,
                      ),
                    ),
                    const SizedBox(height: 14),
                    buildPasswordField(
                      context,
                      controller: confirmPasswordController,
                      label: 'Confirm password',
                      obscureText: hideConfirmPassword,
                      onToggle: () => setSheetState(
                        () => hideConfirmPassword = !hideConfirmPassword,
                      ),
                      onSubmitted: (_) {
                        if (!isSaving) savePassword();
                      },
                    ),
                    const SizedBox(height: 18),
                    buildPrimarySheetButton(
                      context,
                      label: isSaving ? 'Updating...' : 'Update password',
                      icon: Icons.lock_reset_rounded,
                      onPressed: isSaving ? null : savePassword,
                    ),
                  ],
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

  Future<void> showSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return buildSheetScaffold(
          sheetContext,
          title: 'Settings',
          subtitle: 'Adjust Planora app preferences.',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildSheetActionTile(
                sheetContext,
                icon: Icons.dark_mode_outlined,
                title: 'Toggle theme',
                subtitle: 'Switch between light and dark mode',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  widget.onThemeToggle();
                },
              ),
              const SizedBox(height: 10),
              buildSheetActionTile(
                sheetContext,
                icon: Icons.info_outline_rounded,
                title: 'Planora mobile beta',
                subtitle: 'Profile preferences are available in this screen',
                onTap: () {},
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildSheetScaffold(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final isDark = PlanoraTheme.isDark(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
          ),
          boxShadow: PlanoraTheme.softCardShadowFor(context),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: mutedColor(context),
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration inputDecoration(
    BuildContext context, {
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final isDark = PlanoraTheme.isDark(context);

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark ? PlanoraTheme.darkSurfaceVariant : PlanoraTheme.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.6,
        ),
      ),
    );
  }

  Widget buildPasswordField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: onSubmitted == null ? TextInputAction.next : TextInputAction.done,
      onSubmitted: onSubmitted,
      decoration: inputDecoration(
        context,
        label: label,
        icon: Icons.lock_outline_rounded,
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }

  Widget buildPrimarySheetButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed == null ? null : PlanoraTheme.primaryGradientFor(context),
          color: onPressed == null ? mutedColor(context).withValues(alpha: 0.24) : null,
          borderRadius: BorderRadius.circular(18),
          boxShadow: onPressed == null ? null : PlanoraTheme.floatingShadowFor(context),
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildSheetActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
          ),
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
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: mutedColor(context),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: mutedColor(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileTileData {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const ProfileTileData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
