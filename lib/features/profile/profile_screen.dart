import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/planora_theme.dart';
import '../auth/models/auth_models.dart';
import '../tasks/data/tasks_api.dart';
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
  final TasksApi _tasksApi = const TasksApi();

  late UserResponse user = widget.user;
  bool isLoading = false;
  bool isLoadingStats = true;
  String? errorMessage;
  int projectCount = 0;
  int completedTaskCount = 0;

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
    loadProfileStats();
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

  Future<void> loadProfileStats() async {
    setState(() {
      isLoadingStats = true;
    });

    try {
      final board = await _tasksApi.getTasks();
      if (!mounted) return;

      setState(() {
        projectCount = board.projects.length;
        completedTaskCount = board.tasks
            .where((item) => item.task.isCompleted)
            .length;
        isLoadingStats = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Profile stats load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;

      setState(() {
        isLoadingStats = false;
      });
    }
  }

  Future<void> refreshProfile() async {
    await Future.wait([loadProfile(), loadProfileStats()]);
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
                            title: 'Workspace',
                            tiles: [
                              ProfileTileData(
                                icon: Icons.folder_outlined,
                                title: 'Projects',
                                subtitle: isLoadingStats
                                    ? 'Loading projects...'
                                    : '$projectCount active projects',
                                onTap: () => showMessage(
                                  'Open projects from the tab bar.',
                                ),
                              ),
                              ProfileTileData(
                                icon: Icons.task_alt_rounded,
                                title: 'Completed Tasks',
                                subtitle: isLoadingStats
                                    ? 'Loading tasks...'
                                    : '$completedTaskCount tasks completed',
                                onTap: () => showMessage(
                                  'Open tasks from the tab bar.',
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
                          7,
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
                        buildStaggeredItem(8, buildLogoutButton(context)),
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
                      '@${user.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w800,
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
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: user.isEmailVerified
                      ? PlanoraTheme.success.withValues(alpha: 0.12)
                      : PlanoraTheme.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  accountBadgeLabel,
                  style: TextStyle(
                    color: user.isEmailVerified
                        ? PlanoraTheme.success
                        : PlanoraTheme.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildProfileAvatar(BuildContext context, {required double radius}) {
    final imageUrl = user.profilePic?.trim();

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => buildInitialsAvatar(context, radius),
        ),
      );
    }

    return buildInitialsAvatar(context, radius);
  }

  Widget buildInitialsAvatar(BuildContext context, double radius) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        gradient: PlanoraTheme.primaryGradientFor(context),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.58,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget buildStatsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(context),
      child: Row(
        children: [
          Expanded(
            child: buildStatItem(
              context,
              icon: Icons.folder_outlined,
              label: 'Projects',
              value: isLoadingStats ? '...' : '$projectCount',
            ),
          ),
          buildVerticalDivider(context),
          Expanded(
            child: buildStatItem(
              context,
              icon: Icons.task_alt_rounded,
              label: 'Completed',
              value: isLoadingStats ? '...' : '$completedTaskCount',
            ),
          ),
          buildVerticalDivider(context),
          Expanded(
            child: buildStatItem(
              context,
              icon: Icons.calendar_month_outlined,
              label: 'Days active',
              value: '$daysActive',
            ),
          ),
        ],
      ),
    );
  }

  Widget buildVerticalDivider(BuildContext context) {
    return Container(
      width: 1,
      height: 44,
      color: PlanoraTheme.isDark(context)
          ? PlanoraTheme.darkBorder
          : PlanoraTheme.border,
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
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 21),
        const SizedBox(height: 7),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: mutedColor(context),
                fontWeight: FontWeight.w700,
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
    final isDark = PlanoraTheme.isDark(context);
    return Container(
      width: double.infinity,
      decoration: cardDecoration(context).copyWith(
        borderRadius: BorderRadius.circular(22),
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
          for (var index = 0; index < tiles.length; index++) ...[
            buildProfileActionTile(context, tiles[index]),
            if (index != tiles.length - 1)
              Divider(
                height: 1,
                indent: 72,
                color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
              ),
          ],
        ],
      ),
    );
  }

  Widget buildProfileActionTile(BuildContext context, ProfileTileData item) {
    return ListTile(
      onTap: item.onTap,
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
          item.icon,
          size: 19,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        item.subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: mutedColor(context), fontWeight: FontWeight.w600),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: mutedColor(context)),
    );
  }

  Widget buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: handleLogout,
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Log Out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: PlanoraTheme.error,
          side: BorderSide(color: PlanoraTheme.error.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Future<void> showEditProfileSheet() async {
    final fullNameController = TextEditingController(text: user.fullName);
    final usernameController = TextEditingController(text: user.username);
    var isSaving = false;

    bool validUsername(String value) {
      return RegExp(r'^[A-Za-z0-9_]{3,50}$').hasMatch(value.trim());
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final fullName = fullNameController.text.trim();
            final username = usernameController.text.trim();
            final canSave = fullName.isNotEmpty &&
                validUsername(username) &&
                !isSaving &&
                (fullName != user.fullName.trim() || username != user.username.trim());

            Future<void> submit() async {
              if (!canSave) return;
              FocusManager.instance.primaryFocus?.unfocus();
              setSheetState(() => isSaving = true);

              try {
                final updatedUser = await _profileApi.updateProfile(
                  username: username,
                  fullName: fullName,
                );
                if (!mounted) return;
                setState(() {
                  user = updatedUser;
                });
                widget.onUserUpdated?.call(updatedUser);
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                showMessage('Profile updated successfully.');
              } on ApiException catch (error) {
                if (sheetContext.mounted) {
                  setSheetState(() => isSaving = false);
                }
                showMessage(error.message);
              } catch (error, stackTrace) {
                debugPrint('Profile update failed: $error');
                debugPrintStack(stackTrace: stackTrace);
                if (sheetContext.mounted) {
                  setSheetState(() => isSaving = false);
                }
                showMessage('Could not update profile.');
              }
            }

            return buildSheetContainer(
              sheetContext,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SheetGrabber(),
                  const SizedBox(height: 20),
                  buildSheetHeader(
                    sheetContext,
                    title: 'Edit Profile',
                    icon: Icons.edit_outlined,
                    onClose: isSaving ? null : () => Navigator.of(sheetContext).pop(),
                  ),
                  const SizedBox(height: 22),
                  _SheetLabel('Full name'),
                  const SizedBox(height: 8),
                  buildSheetTextField(
                    controller: fullNameController,
                    icon: Icons.person_outline_rounded,
                    hintText: 'Enter your full name',
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 16),
                  _SheetLabel('Username'),
                  const SizedBox(height: 8),
                  buildSheetTextField(
                    controller: usernameController,
                    icon: Icons.alternate_email_rounded,
                    hintText: 'Choose a username',
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    validUsername(username)
                        ? 'Username looks good.'
                        : 'Use 3-50 letters, numbers, or underscores.',
                    style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                          color: validUsername(username)
                              ? PlanoraTheme.success
                              : PlanoraTheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: canSave ? submit : null,
                      icon: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(isSaving ? 'Saving profile...' : 'Save Changes'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: isSaving ? null : () => Navigator.of(sheetContext).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      fullNameController.dispose();
      usernameController.dispose();
    });
  }

  Future<void> showChangePasswordSheet() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    var isSaving = false;
    var obscurePasswords = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final oldPassword = oldPasswordController.text;
            final newPassword = newPasswordController.text;
            final confirmPassword = confirmPasswordController.text;
            final passwordsMatch =
                newPassword.isNotEmpty && newPassword == confirmPassword;
            final canSave = oldPassword.isNotEmpty &&
                newPassword.length >= 8 &&
                passwordsMatch &&
                !isSaving;

            Future<void> submit() async {
              if (!canSave) return;
              FocusManager.instance.primaryFocus?.unfocus();
              setSheetState(() => isSaving = true);

              try {
                await _profileApi.changePassword(
                  oldPassword: oldPassword,
                  newPassword: newPassword,
                );
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                showMessage('Password changed successfully.');
              } on ApiException catch (error) {
                if (sheetContext.mounted) {
                  setSheetState(() => isSaving = false);
                }
                showMessage(error.message);
              } catch (error, stackTrace) {
                debugPrint('Password change failed: $error');
                debugPrintStack(stackTrace: stackTrace);
                if (sheetContext.mounted) {
                  setSheetState(() => isSaving = false);
                }
                showMessage('Could not change password.');
              }
            }

            return buildSheetContainer(
              sheetContext,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SheetGrabber(),
                  const SizedBox(height: 20),
                  buildSheetHeader(
                    sheetContext,
                    title: 'Change Password',
                    icon: Icons.lock_outline_rounded,
                    onClose: isSaving ? null : () => Navigator.of(sheetContext).pop(),
                  ),
                  const SizedBox(height: 22),
                  _SheetLabel('Current password'),
                  const SizedBox(height: 8),
                  buildSheetTextField(
                    controller: oldPasswordController,
                    icon: Icons.lock_open_outlined,
                    hintText: 'Enter current password',
                    obscureText: obscurePasswords,
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 16),
                  _SheetLabel('New password'),
                  const SizedBox(height: 8),
                  buildSheetTextField(
                    controller: newPasswordController,
                    icon: Icons.lock_outline_rounded,
                    hintText: 'Enter new password',
                    obscureText: obscurePasswords,
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 16),
                  _SheetLabel('Confirm password'),
                  const SizedBox(height: 8),
                  buildSheetTextField(
                    controller: confirmPasswordController,
                    icon: Icons.verified_user_outlined,
                    hintText: 'Confirm new password',
                    obscureText: obscurePasswords,
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          passwordsMatch || confirmPassword.isEmpty
                              ? 'Use at least 8 characters.'
                              : 'Passwords do not match.',
                          style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                                color: passwordsMatch || confirmPassword.isEmpty
                                    ? mutedColor(sheetContext)
                                    : PlanoraTheme.error,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => setSheetState(
                          () => obscurePasswords = !obscurePasswords,
                        ),
                        icon: Icon(
                          obscurePasswords
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 18,
                        ),
                        label: Text(obscurePasswords ? 'Show' : 'Hide'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: canSave ? submit : null,
                      icon: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_reset_rounded),
                      label: Text(isSaving ? 'Changing password...' : 'Change Password'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: isSaving ? null : () => Navigator.of(sheetContext).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      oldPasswordController.dispose();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    });
  }

  Future<void> showSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return buildSheetContainer(
          sheetContext,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetGrabber(),
              const SizedBox(height: 20),
              buildSheetHeader(
                sheetContext,
                title: 'Settings',
                icon: Icons.settings_outlined,
                onClose: () => Navigator.of(sheetContext).pop(),
              ),
              const SizedBox(height: 18),
              Container(
                decoration: cardDecoration(sheetContext),
                child: ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Theme.of(sheetContext)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.dark_mode_outlined,
                      color: Theme.of(sheetContext).colorScheme.primary,
                    ),
                  ),
                  title: const Text(
                    'Dark mode',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    'Toggle Planora appearance',
                    style: TextStyle(
                      color: mutedColor(sheetContext),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Switch(
                    value: PlanoraTheme.isDark(context),
                    onChanged: (_) {
                      Navigator.of(sheetContext).pop();
                      widget.onThemeToggle();
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildSheetContainer(BuildContext sheetContext, {required Widget child}) {
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: PlanoraTheme.floatingShadowFor(sheetContext),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 260),
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
          ),
        ),
      ),
    );
  }

  Widget buildSheetHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback? onClose,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded)),
      ],
    );
  }

  Widget buildSheetTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hintText,
    required ValueChanged<String> onChanged,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      obscureText: obscureText,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class _SheetGrabber extends StatelessWidget {
  const _SheetGrabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: PlanoraTheme.isDark(context)
              ? PlanoraTheme.darkBorder
              : PlanoraTheme.border,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final String label;

  const _SheetLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900),
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
