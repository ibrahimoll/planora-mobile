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

  String initialsFor(String value) {
    final source = value.trim();

    if (source.isEmpty) return 'P';

    final parts = source.split(RegExp(r'\s+'));

    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }

    return source[0].toUpperCase();
  }

  int get daysActive {
    final created = user.createdAt.toLocal();
    final startDay = DateTime(created.year, created.month, created.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = today.difference(startDay).inDays + 1;

    return days < 1 ? 1 : days;
  }

  String get accountBadgeLabel {
    if (!user.isEmailVerified) {
      return 'Email pending';
    }

    final role = user.role.trim();

    if (role.isEmpty) {
      return 'Verified';
    }

    return '${role[0].toUpperCase()}${role.substring(1)}';
  }

  @override
  void initState() {
    super.initState();
    loadProfile();
    loadProfileStats();
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
        errorMessage = 'Could not refresh profile.';
        isLoading = false;
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

  Color mutedColor(BuildContext context) {
    return PlanoraTheme.isDark(context)
        ? PlanoraTheme.darkTextMuted
        : PlanoraTheme.textSecondary;
  }

  Color sheetBarrierColor(BuildContext context) {
    return Colors.black.withValues(
      alpha: PlanoraTheme.isDark(context) ? 0.62 : 0.38,
    );
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

  Widget buildProfileCard(BuildContext context) {
    return Container(
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
                    Icons.photo_camera_outlined,
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
                const SizedBox(height: 3),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mutedColor(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    buildPill(context, '@${user.username}'),
                    buildPill(context, accountBadgeLabel),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              tooltip: 'Edit profile',
              padding: EdgeInsets.zero,
              onPressed: showEditProfileSheet,
              icon: Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildProfileAvatar(BuildContext context, {required double radius}) {
    final profilePic = user.profilePic?.trim();
    final size = radius * 2;

    if (profilePic != null && profilePic.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          profilePic,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Profile avatar load failed: $error');
            return buildFallbackAvatar(context, radius: radius);
          },
        ),
      );
    }

    return buildFallbackAvatar(context, radius: radius);
  }

  Widget buildFallbackAvatar(BuildContext context, {required double radius}) {
    return buildInitialsAvatar(context, label: initials, radius: radius);
  }

  Widget buildInitialsAvatar(
    BuildContext context, {
    required String label,
    required double radius,
  }) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        gradient: PlanoraTheme.primaryGradientFor(context),
        borderRadius: BorderRadius.circular(999),
        boxShadow: PlanoraTheme.floatingShadowFor(context),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.62,
          fontWeight: FontWeight.w900,
        ),
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

  Widget buildStatsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: cardDecoration(context),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: buildStatItem(
                context,
                icon: Icons.folder_outlined,
                value: projectCount,
                label: 'Projects',
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            buildStatDivider(context),
            Expanded(
              child: buildStatItem(
                context,
                icon: Icons.check_box_outlined,
                value: completedTaskCount,
                label: 'Tasks Completed',
                color: PlanoraTheme.info,
              ),
            ),
            buildStatDivider(context),
            Expanded(
              child: buildStatItem(
                context,
                icon: Icons.calendar_today_outlined,
                value: daysActive,
                label: 'Days Active',
                color: PlanoraTheme.success,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildStatDivider(BuildContext context) {
    return VerticalDivider(
      width: 1,
      color: PlanoraTheme.isDark(context)
          ? PlanoraTheme.darkBorder
          : PlanoraTheme.border,
    );
  }

  Widget buildStatItem(
    BuildContext context, {
    required IconData icon,
    required int value,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(height: 9),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: isLoadingStats
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  '$value',
                  key: ValueKey(value),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: mutedColor(context),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget buildProfileSection(
    BuildContext context, {
    required String title,
    required List<_ProfileActionItem> items,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
      decoration: cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < items.length; index++) ...[
            buildMenuTile(context, item: items[index]),
            if (index != items.length - 1) buildDivider(context),
          ],
        ],
      ),
    );
  }

  Widget buildAccountSection(BuildContext context) {
    return buildProfileSection(
      context,
      title: 'Account',
      items: [
        _ProfileActionItem(
          icon: Icons.person_outline_rounded,
          title: 'Edit Profile',
          subtitle: 'Update your personal information',
          onTap: showEditProfileSheet,
        ),
        _ProfileActionItem(
          icon: Icons.lock_outline_rounded,
          title: 'Change Password',
          subtitle: 'Update your account password',
          onTap: showChangePasswordSheet,
        ),
        _ProfileActionItem(
          icon: Icons.mail_outline_rounded,
          title: 'Email Preferences',
          subtitle: 'Manage your email notifications',
          onTap: () => openProfileInfoPage(
            title: 'Email Preferences',
            icon: Icons.mail_outline_rounded,
            body:
                'Email preferences are handled by Planora notifications. Backend preference endpoints are not available yet, so this page is read-only.',
          ),
        ),
        _ProfileActionItem(
          icon: Icons.notifications_none_rounded,
          title: 'Notification Settings',
          subtitle: 'Customize your notifications',
          onTap: () => openProfileInfoPage(
            title: 'Notification Settings',
            icon: Icons.notifications_none_rounded,
            body:
                'In-app notifications are loaded from the backend Notifications API. Per-channel notification settings are disabled until the backend exposes preferences.',
          ),
        ),
      ],
    );
  }

  Widget buildWorkspaceSection(BuildContext context) {
    return buildProfileSection(
      context,
      title: 'Workspace',
      items: [
        _ProfileActionItem(
          icon: Icons.workspace_premium_outlined,
          title: 'Subscription',
          subtitle: 'View current plan information',
          onTap: () => openProfileInfoPage(
            title: 'Subscription',
            icon: Icons.workspace_premium_outlined,
            body:
                'Your current Planora mobile account is using the standard workspace experience. Subscription management is read-only because billing endpoints are not available to the mobile app.',
          ),
        ),
        _ProfileActionItem(
          icon: Icons.credit_card_outlined,
          title: 'Billing & Invoices',
          subtitle: 'View billing availability',
          onTap: () => openProfileInfoPage(
            title: 'Billing & Invoices',
            icon: Icons.credit_card_outlined,
            body:
                'Billing and invoice history are not exposed by the current backend API. This page is intentionally informational instead of calling an unsupported endpoint.',
          ),
        ),
      ],
    );
  }

  Widget buildMoreSection(BuildContext context) {
    return buildProfileSection(
      context,
      title: 'More',
      items: [
        _ProfileActionItem(
          icon: Icons.help_outline_rounded,
          title: 'Help & Support',
          subtitle: 'Beta support and troubleshooting',
          onTap: () => openProfileInfoPage(
            title: 'Help & Support',
            icon: Icons.help_outline_rounded,
            sections: ProfileInfoContent.helpSupport,
          ),
        ),
        _ProfileActionItem(
          icon: Icons.shield_outlined,
          title: 'Privacy Policy',
          subtitle: 'How Planora handles your data',
          onTap: () => openProfileInfoPage(
            title: 'Privacy Policy',
            icon: Icons.shield_outlined,
            sections: ProfileInfoContent.privacyPolicy,
          ),
        ),
        _ProfileActionItem(
          icon: Icons.description_outlined,
          title: 'Terms of Service',
          subtitle: 'Rules for using Planora',
          onTap: () => openProfileInfoPage(
            title: 'Terms of Service',
            icon: Icons.description_outlined,
            sections: ProfileInfoContent.terms,
          ),
        ),
      ],
    );
  }

  Widget buildMenuTile(
    BuildContext context, {
    required _ProfileActionItem item,
  }) {
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(item.icon, size: 19, color: primary),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle,
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
              const SizedBox(width: 10),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: mutedColor(context),
                  size: 20,
                ),
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
      indent: 62,
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
    final fullNameFocus = FocusNode();
    final usernameFocus = FocusNode();
    bool isSaving = false;
    String? fullNameError;
    String? usernameError;
    String? sheetError;

    bool hasChanges() {
      return usernameController.text.trim() != user.username.trim() ||
          fullNameController.text.trim() != user.fullName.trim();
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: sheetBarrierColor(context),
      enableDrag: true,
      isDismissible: !isSaving,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 340),
        reverseDuration: Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final canSave = !isSaving && hasChanges();
            final previewName = fullNameController.text.trim().isNotEmpty
                ? fullNameController.text.trim()
                : user.username;
            final previewUsername = usernameController.text.trim().isNotEmpty
                ? usernameController.text.trim()
                : user.username;

            void clearErrors() {
              setSheetState(() {
                fullNameError = null;
                usernameError = null;
                sheetError = null;
              });
            }

            Future<void> saveProfile() async {
              final username = usernameController.text.trim();
              final fullName = fullNameController.text.trim();

              if (!hasChanges()) {
                return;
              }

              if (fullName.isEmpty) {
                setSheetState(() {
                  fullNameError = 'Full name is required.';
                  usernameError = null;
                  sheetError = null;
                });
                fullNameFocus.requestFocus();
                return;
              }

              if (!RegExp(r'^[A-Za-z0-9_]{3,50}$').hasMatch(username)) {
                setSheetState(() {
                  fullNameError = null;
                  usernameError =
                      'Use 3-50 letters, numbers, or underscores only.';
                  sheetError = null;
                });
                usernameFocus.requestFocus();
                return;
              }

              setSheetState(() {
                isSaving = true;
                fullNameError = null;
                usernameError = null;
                sheetError = null;
              });

              try {
                final updatedUser = await _profileApi.updateProfile(
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
                setSheetState(() {
                  sheetError = error.message;
                });
              } catch (error, stackTrace) {
                debugPrint('Profile update failed: $error');
                debugPrintStack(stackTrace: stackTrace);

                if (!mounted) return;
                setSheetState(() {
                  sheetError = 'Could not update profile.';
                });
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() {
                    isSaving = false;
                  });
                }
              }
            }

            return buildSheetSurface(
              sheetContext,
              title: 'Edit Profile',
              icon: Icons.edit_outlined,
              isBusy: isSaving,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildEditProfilePreviewCard(
                    sheetContext,
                    name: previewName,
                    username: previewUsername,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Personal details',
                    style: Theme.of(sheetContext).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Update how your profile appears across Planora.',
                    style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                      color: mutedColor(sheetContext),
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  buildSheetLabel(sheetContext, 'Full Name'),
                  const SizedBox(height: 8),
                  buildSheetTextField(
                    sheetContext,
                    controller: fullNameController,
                    focusNode: fullNameFocus,
                    hintText: 'Enter your full name',
                    icon: Icons.person_outline_rounded,
                    errorText: fullNameError,
                    enabled: !isSaving,
                    keyboardType: TextInputType.name,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    onChanged: (_) => clearErrors(),
                    onSubmitted: (_) => usernameFocus.requestFocus(),
                  ),
                  const SizedBox(height: 16),
                  buildSheetLabel(sheetContext, 'Username'),
                  const SizedBox(height: 8),
                  buildSheetTextField(
                    sheetContext,
                    controller: usernameController,
                    focusNode: usernameFocus,
                    hintText: 'Choose a username',
                    icon: Icons.alternate_email_rounded,
                    errorText: usernameError,
                    helperText:
                        '3-50 characters. Letters, numbers, and underscores only.',
                    enabled: !isSaving,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.username],
                    onChanged: (_) => clearErrors(),
                    onSubmitted: (_) => saveProfile(),
                  ),
                  if (sheetError != null) ...[
                    const SizedBox(height: 14),
                    buildInlineError(sheetContext, sheetError!),
                  ],
                  const SizedBox(height: 22),
                  buildGradientActionButton(
                    sheetContext,
                    isEnabled: canSave,
                    isLoading: isSaving,
                    label: 'Save Changes',
                    loadingLabel: 'Saving...',
                    icon: Icons.check_rounded,
                    onPressed: saveProfile,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: isSaving
                          ? null
                          : () => Navigator.of(sheetContext).pop(),
                      child: const Text('Cancel'),
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
    usernameFocus.dispose();
    fullNameFocus.dispose();
  }

  Widget buildEditProfilePreviewCard(
    BuildContext context, {
    required String name,
    required String username,
  }) {
    final isDark = PlanoraTheme.isDark(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: PlanoraTheme.softGradientFor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.lavenderBorder,
        ),
        boxShadow: PlanoraTheme.softCardShadowFor(context),
      ),
      child: Row(
        children: [
          buildInitialsAvatar(context, label: initialsFor(name), radius: 31),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mutedColor(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '@$username',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> showChangePasswordSheet() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSaving = false;

    bool strongPassword(String password) {
      return password.length >= 8 &&
          RegExp(r'[A-Z]').hasMatch(password) &&
          RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\\[\];~`]').hasMatch(password);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: sheetBarrierColor(context),
      enableDrag: true,
      isDismissible: !isSaving,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 340),
        reverseDuration: Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return buildSheetSurface(
              sheetContext,
              title: 'Change Password',
              icon: Icons.lock_reset_rounded,
              isBusy: isSaving,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildPasswordIntroCard(sheetContext),
                  const SizedBox(height: 18),
                  buildSheetLabel(sheetContext, 'Current password'),
                  const SizedBox(height: 8),
                  buildSheetTextField(
                    sheetContext,
                    controller: oldPasswordController,
                    hintText: 'Enter your current password',
                    icon: Icons.lock_outline_rounded,
                    obscureText: obscureOld,
                    enabled: !isSaving,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.password],
                    suffixIcon: IconButton(
                      tooltip: obscureOld ? 'Show password' : 'Hide password',
                      onPressed: isSaving
                          ? null
                          : () {
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
                  buildSheetLabel(sheetContext, 'New password'),
                  const SizedBox(height: 8),
                  buildSheetTextField(
                    sheetContext,
                    controller: newPasswordController,
                    hintText: 'Create a strong new password',
                    icon: Icons.password_rounded,
                    obscureText: obscureNew,
                    enabled: !isSaving,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    suffixIcon: IconButton(
                      tooltip: obscureNew ? 'Show password' : 'Hide password',
                      onPressed: isSaving
                          ? null
                          : () {
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
                  const SizedBox(height: 12),
                  buildPasswordRulesCard(sheetContext),
                  const SizedBox(height: 16),
                  buildSheetLabel(sheetContext, 'Confirm new password'),
                  const SizedBox(height: 8),
                  buildSheetTextField(
                    sheetContext,
                    controller: confirmPasswordController,
                    hintText: 'Re-enter your new password',
                    icon: Icons.verified_user_outlined,
                    obscureText: obscureConfirm,
                    enabled: !isSaving,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    suffixIcon: IconButton(
                      tooltip: obscureConfirm ? 'Show password' : 'Hide password',
                      onPressed: isSaving
                          ? null
                          : () {
                              setSheetState(() {
                                obscureConfirm = !obscureConfirm;
                              });
                            },
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  buildGradientActionButton(
                    sheetContext,
                    isEnabled: !isSaving,
                    isLoading: isSaving,
                    label: 'Update Password',
                    loadingLabel: 'Updating password...',
                    icon: Icons.lock_reset_rounded,
                    onPressed: () async {
                      final oldPassword = oldPasswordController.text;
                      final newPassword = newPasswordController.text;
                      final confirmPassword = confirmPasswordController.text;

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
                      } catch (error, stackTrace) {
                        debugPrint('Password change failed: $error');
                        debugPrintStack(stackTrace: stackTrace);

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
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: isSaving
                          ? null
                          : () => Navigator.of(sheetContext).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'You will stay signed in after changing your password.',
                      textAlign: TextAlign.center,
                      style: Theme.of(sheetContext).textTheme.bodySmall
                          ?.copyWith(
                            color: mutedColor(sheetContext),
                            fontWeight: FontWeight.w600,
                          ),
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

  Widget buildPasswordIntroCard(BuildContext context) {
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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Use a password that is hard to guess and different from your other accounts.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mutedColor(context),
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

  Widget buildPasswordRulesCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(
        context,
      ).copyWith(borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password requirements',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          buildPasswordRule(context, 'At least 8 characters'),
          const SizedBox(height: 8),
          buildPasswordRule(context, 'At least one uppercase letter'),
          const SizedBox(height: 8),
          buildPasswordRule(context, 'At least one symbol'),
        ],
      ),
    );
  }

  Widget buildPasswordRule(BuildContext context, String text) {
    final primary = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Icon(Icons.check_rounded, size: 14, color: primary),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: mutedColor(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> showSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: sheetBarrierColor(context),
      enableDrag: true,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 340),
        reverseDuration: Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
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
    bool isBusy = false,
  }) {
    final isDark = PlanoraTheme.isDark(sheetContext);
    final media = MediaQuery.of(sheetContext);
    final primary = Theme.of(sheetContext).colorScheme.primary;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeOutCubic,
          builder: (context, value, animatedChild) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 28 * (1 - value)),
                child: Transform.scale(
                  alignment: Alignment.bottomCenter,
                  scale: 0.98 + (0.02 * value),
                  child: animatedChild,
                ),
              ),
            );
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 430,
              maxHeight: media.size.height * 0.90,
            ),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? PlanoraTheme.darkBackground : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                border: Border.all(
                  color: isDark
                      ? PlanoraTheme.darkBorder.withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.72),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.16),
                    blurRadius: 34,
                    offset: const Offset(0, -10),
                  ),
                  BoxShadow(
                    color: primary.withValues(alpha: isDark ? 0.20 : 0.12),
                    blurRadius: 38,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
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
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: isDark ? 0.18 : 0.10),
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: Icon(icon, color: primary, size: 23),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(sheetContext).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Material(
                          color: isDark
                              ? PlanoraTheme.darkSurfaceVariant
                              : PlanoraTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            onTap: isBusy
                                ? null
                                : () => Navigator.of(sheetContext).pop(),
                            borderRadius: BorderRadius.circular(999),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.close_rounded,
                                color: mutedColor(sheetContext),
                                size: 21,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    child,
                  ],
                ),
              ),
            ),
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
    bool enabled = true,
    Widget? suffixIcon,
    String? errorText,
    String? helperText,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    Iterable<String>? autofillHints,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) {
    final isDark = PlanoraTheme.isDark(context);
    final primary = Theme.of(context).colorScheme.primary;
    final fillColor = isDark
        ? PlanoraTheme.darkSurfaceVariant.withValues(alpha: 0.62)
        : const Color(0xFFF8FAFC);
    final borderColor = isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        helperText: helperText,
        errorText: errorText,
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 10),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primary, size: 18),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 60,
          minHeight: 56,
        ),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: primary, width: 1.7),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: PlanoraTheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: PlanoraTheme.error, width: 1.7),
        ),
      ),
    );
  }

  Widget buildInlineError(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PlanoraTheme.error.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PlanoraTheme.error.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: PlanoraTheme.error, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
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

  Widget buildGradientActionButton(
    BuildContext context, {
    required bool isEnabled,
    required bool isLoading,
    required String label,
    required String loadingLabel,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final isDark = PlanoraTheme.isDark(context);
    final buttonRadius = BorderRadius.circular(18);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      opacity: isEnabled ? 1 : 0.58,
      child: Material(
        color: Colors.transparent,
        borderRadius: buttonRadius,
        child: Ink(
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: isEnabled ? PlanoraTheme.primaryGradientFor(context) : null,
            color: isEnabled
                ? null
                : isDark
                    ? PlanoraTheme.darkSurfaceVariant
                    : PlanoraTheme.surfaceVariant,
            borderRadius: buttonRadius,
            boxShadow: isEnabled ? PlanoraTheme.floatingShadowFor(context) : null,
          ),
          child: InkWell(
            onTap: isEnabled ? onPressed : null,
            borderRadius: buttonRadius,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axis: Axis.horizontal,
                      child: child,
                    ),
                  );
                },
                child: isLoading
                    ? Row(
                        key: const ValueKey('loading'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            loadingLabel,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ],
                      )
                    : Row(
                        key: const ValueKey('idle'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, color: Colors.white, size: 19),
                          const SizedBox(width: 8),
                          Text(
                            label,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
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
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(context),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: primary, size: 20),
          ),
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
        style: OutlinedButton.styleFrom(
          foregroundColor: PlanoraTheme.error,
          backgroundColor: PlanoraTheme.error.withValues(alpha: 0.04),
          side: BorderSide(color: PlanoraTheme.error.withValues(alpha: 0.28)),
        ),
        onPressed: () {
          widget.onLoggedOut();
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Logout'),
      ),
    );
  }

  Widget buildStaggeredItem(int index, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + (index * 45)),
      curve: Curves.easeOutCubic,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: animatedChild,
          ),
        );
      },
      child: child,
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
                onRefresh: refreshProfile,
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
                    buildStaggeredItem(0, buildProfileCard(context)),
                    const SizedBox(height: 16),
                    buildStaggeredItem(1, buildStatsCard(context)),
                    const SizedBox(height: 18),
                    buildStaggeredItem(2, buildAccountSection(context)),
                    const SizedBox(height: 18),
                    buildStaggeredItem(3, buildWorkspaceSection(context)),
                    const SizedBox(height: 18),
                    buildStaggeredItem(4, buildMoreSection(context)),
                    const SizedBox(height: 16),
                    buildStaggeredItem(5, buildLogoutButton(context)),
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

class _ProfileActionItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
