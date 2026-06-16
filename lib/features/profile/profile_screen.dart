import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/planora_theme.dart';
import '../auth/models/auth_models.dart';
import '../tasks/data/tasks_api.dart';
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
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
      ),
      boxShadow: PlanoraTheme.cardShadowFor(context),
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Scaffold(
      backgroundColor: isDark ? PlanoraTheme.darkBackground : PlanoraTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refreshProfile,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildStaggeredItem(0, buildHeader(context)),
                    const SizedBox(height: 18),
                    if (errorMessage != null) ...[
                      buildStaggeredItem(1, buildErrorBanner(context, errorMessage!)),
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
                            subtitle: '$projectCount active projects',
                            onTap: () => showMessage('Open projects from the tab bar.'),
                          ),
                          ProfileTileData(
                            icon: Icons.task_alt_rounded,
                            title: 'Completed Tasks',
                            subtitle: '$completedTaskCount tasks completed',
                            onTap: () => showMessage('Open tasks from the tab bar.'),
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
                            icon: Icons.shield_outlined,
                            title: 'Privacy',
                            subtitle: 'Your data stays protected',
                            onTap: () => showInfoSheet(
                              title: 'Privacy',
                              icon: Icons.shield_outlined,
                              body:
                                  'Planora keeps your account data private and only uses it to power your workspace, tasks, teams, and profile experience.',
                            ),
                          ),
                          ProfileTileData(
                            icon: Icons.help_outline_rounded,
                            title: 'Help & Support',
                            subtitle: 'Get help using Planora',
                            onTap: () => showInfoSheet(
                              title: 'Help & Support',
                              icon: Icons.help_outline_rounded,
                              body:
                                  'For now, contact the Planora team directly if something is broken or unclear. More in-app support tools are coming later.',
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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
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
            decoration: cardDecoration(context).copyWith(
              borderRadius: BorderRadius.circular(999),
            ),
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
                    const SizedBox(height: 4),
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
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
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
            return buildInitialsAvatar(context, label: initials, radius: radius);
          },
        ),
      );
    }

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
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: isLoadingStats
              ? SizedBox(
                  key: ValueKey('$label-loading'),
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : Text(
                  '$value',
                  key: ValueKey('$label-$value'),
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
                fontWeight: FontWeight.w800,
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
    return Container(
      width: double.infinity,
      decoration: cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          for (var index = 0; index < tiles.length; index++) ...[
            buildProfileTile(context, tiles[index]),
            if (index != tiles.length - 1)
              Divider(
                height: 1,
                indent: 72,
                color: PlanoraTheme.isDark(context)
                    ? PlanoraTheme.darkBorder
                    : PlanoraTheme.border,
              ),
          ],
        ],
      ),
    );
  }

  Widget buildProfileTile(BuildContext context, ProfileTileData item) {
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.icon, size: 20, color: primary),
              ),
              const SizedBox(width: 14),
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
                            color: PlanoraTheme.isDark(context)
                                ? PlanoraTheme.darkTextPrimary
                                : PlanoraTheme.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
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
              const SizedBox(width: 10),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.06),
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

  Widget buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: widget.onLoggedOut,
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Log Out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: PlanoraTheme.error,
          side: BorderSide(color: PlanoraTheme.error.withValues(alpha: 0.28)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Future<void> showEditProfileSheet() async {
    final usernameController = TextEditingController(text: user.username);
    final fullNameController = TextEditingController(text: user.fullName);
    final usernameFocus = FocusNode();
    final fullNameFocus = FocusNode();
    final initialUsername = user.username.trim();
    final initialFullName = user.fullName.trim();
    bool isSaving = false;
    String? fullNameError;
    String? usernameError;
    String? sheetError;

    bool validUsername(String value) {
      return RegExp(r'^[A-Za-z0-9_]{3,50}$').hasMatch(value.trim());
    }

    bool hasChanges() {
      return usernameController.text.trim() != initialUsername ||
          fullNameController.text.trim() != initialFullName;
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
        duration: Duration(milliseconds: 300),
        reverseDuration: Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final fullName = fullNameController.text.trim();
            final username = usernameController.text.trim();
            final fullNameValid = fullName.isNotEmpty;
            final usernameValid = validUsername(username);
            final changed = hasChanges();
            final canSave =
                !isSaving && changed && fullNameValid && usernameValid;
            final buttonLabel = isSaving
                ? 'Saving...'
                : !changed
                    ? 'No Changes Yet'
                    : (!fullNameValid || !usernameValid)
                        ? 'Fix Details'
                        : 'Save Changes';

            void refreshFieldState(String _) {
              setSheetState(() {
                fullNameError = null;
                usernameError = null;
                sheetError = null;
              });
            }

            Future<void> saveProfile() async {
              final nextFullName = fullNameController.text.trim();
              final nextUsername = usernameController.text.trim();

              if (!hasChanges()) return;

              if (nextFullName.isEmpty) {
                setSheetState(() {
                  fullNameError = 'Full name is required.';
                  usernameError = null;
                  sheetError = null;
                });
                fullNameFocus.requestFocus();
                return;
              }

              if (!validUsername(nextUsername)) {
                setSheetState(() {
                  fullNameError = null;
                  usernameError =
                      'Use 3-50 letters, numbers, or underscores only.';
                  sheetError = null;
                });
                usernameFocus.requestFocus();
                return;
              }

              FocusManager.instance.primaryFocus?.unfocus();
              setSheetState(() {
                isSaving = true;
                fullNameError = null;
                usernameError = null;
                sheetError = null;
              });

              try {
                final updatedUser = await _profileApi.updateProfile(
                  username: nextUsername,
                  fullName: nextFullName,
                );

                if (!mounted || !sheetContext.mounted) return;

                setState(() {
                  user = updatedUser;
                });
                widget.onUserUpdated?.call(updatedUser);
                Navigator.of(sheetContext).pop();
                showMessage('Profile updated successfully.');
              } on ApiException catch (error) {
                if (!sheetContext.mounted) return;
                setSheetState(() {
                  isSaving = false;
                  sheetError = error.message;
                });
              } catch (error, stackTrace) {
                debugPrint('Profile update failed: $error');
                debugPrintStack(stackTrace: stackTrace);
                if (!sheetContext.mounted) return;
                setSheetState(() {
                  isSaving = false;
                  sheetError = 'Could not update profile.';
                });
              }
            }

            return buildSheetSurface(
              sheetContext,
              title: 'Edit Profile',
              icon: Icons.edit_outlined,
              isBusy: isSaving,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildCompactProfileRow(sheetContext),
                  const SizedBox(height: 16),
                  Text(
                    'Personal details',
                    style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
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
                  const SizedBox(height: 16),
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
                    onChanged: refreshFieldState,
                    onSubmitted: (_) => usernameFocus.requestFocus(),
                  ),
                  const SizedBox(height: 14),
                  buildSheetLabel(sheetContext, 'Username'),
                  const SizedBox(height: 8),
                  buildSheetTextField(
                    sheetContext,
                    controller: usernameController,
                    focusNode: usernameFocus,
                    hintText: 'Choose a username',
                    icon: Icons.alternate_email_rounded,
                    errorText: usernameError,
                    enabled: !isSaving,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.username],
                    onChanged: refreshFieldState,
                    onSubmitted: (_) => saveProfile(),
                  ),
                  const SizedBox(height: 7),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, right: 4),
                    child: Text(
                      '3-50 characters. Letters, numbers, and underscores only.',
                      softWrap: true,
                      style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                            color: mutedColor(sheetContext),
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                    ),
                  ),
                  if (sheetError != null) ...[
                    const SizedBox(height: 12),
                    buildInlineError(sheetContext, sheetError!),
                  ],
                  const SizedBox(height: 18),
                  buildGradientActionButton(
                    sheetContext,
                    isEnabled: canSave,
                    isLoading: isSaving,
                    label: buttonLabel,
                    loadingLabel: 'Saving...',
                    icon: canSave ? Icons.check_rounded : Icons.lock_outline_rounded,
                    onPressed: saveProfile,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
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

  Widget buildCompactProfileRow(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PlanoraTheme.isDark(context)
            ? PlanoraTheme.darkSurfaceVariant.withValues(alpha: 0.72)
            : PlanoraTheme.lavenderCard.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: PlanoraTheme.isDark(context)
              ? PlanoraTheme.darkBorder
              : PlanoraTheme.lavenderBorder,
        ),
      ),
      child: Row(
        children: [
          buildProfileAvatar(context, radius: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: mutedColor(context),
                        fontWeight: FontWeight.w700,
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
    String? sheetError;

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
        duration: Duration(milliseconds: 300),
        reverseDuration: Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> updatePassword() async {
              final oldPassword = oldPasswordController.text;
              final newPassword = newPasswordController.text;
              final confirmPassword = confirmPasswordController.text;

              if (oldPassword.isEmpty) {
                setSheetState(() => sheetError = 'Current password is required.');
                return;
              }

              if (!strongPassword(newPassword)) {
                setSheetState(
                  () => sheetError =
                      'New password must be 8+ characters with an uppercase letter and a special character.',
                );
                return;
              }

              if (newPassword != confirmPassword) {
                setSheetState(() => sheetError = 'Passwords do not match.');
                return;
              }

              FocusManager.instance.primaryFocus?.unfocus();
              setSheetState(() {
                isSaving = true;
                sheetError = null;
              });

              try {
                await _profileApi.changePassword(
                  oldPassword: oldPassword,
                  newPassword: newPassword,
                );

                if (!sheetContext.mounted) return;
                Navigator.of(sheetContext).pop();
                showMessage('Password updated successfully.');
              } on ApiException catch (error) {
                if (!sheetContext.mounted) return;
                setSheetState(() {
                  isSaving = false;
                  sheetError = error.message;
                });
              } catch (error, stackTrace) {
                debugPrint('Password update failed: $error');
                debugPrintStack(stackTrace: stackTrace);
                if (!sheetContext.mounted) return;
                setSheetState(() {
                  isSaving = false;
                  sheetError = 'Could not update password.';
                });
              }
            }

            return buildSheetSurface(
              sheetContext,
              title: 'Change Password',
              icon: Icons.lock_reset_rounded,
              isBusy: isSaving,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildPasswordIntroCard(sheetContext),
                  const SizedBox(height: 16),
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
                    suffixIcon: IconButton(
                      onPressed: isSaving
                          ? null
                          : () => setSheetState(() => obscureOld = !obscureOld),
                      icon: Icon(
                        obscureOld
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  buildSheetLabel(sheetContext, 'New password'),
                  const SizedBox(height: 8),
                  buildSheetTextField(
                    sheetContext,
                    controller: newPasswordController,
                    hintText: 'Create a strong password',
                    icon: Icons.password_rounded,
                    obscureText: obscureNew,
                    enabled: !isSaving,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.next,
                    suffixIcon: IconButton(
                      onPressed: isSaving
                          ? null
                          : () => setSheetState(() => obscureNew = !obscureNew),
                      icon: Icon(
                        obscureNew
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use 8+ characters with an uppercase letter and a special character.',
                    style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                          color: mutedColor(sheetContext),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 14),
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
                    onSubmitted: (_) => updatePassword(),
                    suffixIcon: IconButton(
                      onPressed: isSaving
                          ? null
                          : () => setSheetState(
                                () => obscureConfirm = !obscureConfirm,
                              ),
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  if (sheetError != null) ...[
                    const SizedBox(height: 12),
                    buildInlineError(sheetContext, sheetError!),
                  ],
                  const SizedBox(height: 18),
                  buildGradientActionButton(
                    sheetContext,
                    isEnabled: !isSaving,
                    isLoading: isSaving,
                    label: 'Update Password',
                    loadingLabel: 'Updating...',
                    icon: Icons.lock_reset_rounded,
                    onPressed: updatePassword,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            Icons.security_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Choose a strong password that you do not use anywhere else.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mutedColor(context),
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
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
        duration: Duration(milliseconds: 300),
        reverseDuration: Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      builder: (sheetContext) {
        return buildSheetSurface(
          sheetContext,
          title: 'Settings',
          icon: Icons.settings_outlined,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildSettingsTile(
                sheetContext,
                icon: PlanoraTheme.isDark(context)
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                title: 'Appearance',
                subtitle: PlanoraTheme.isDark(context)
                    ? 'Dark mode is enabled'
                    : 'Light mode is enabled',
                trailing: Switch.adaptive(
                  value: PlanoraTheme.isDark(context),
                  onChanged: (_) {
                    Navigator.of(sheetContext).pop();
                    widget.onThemeToggle();
                  },
                ),
              ),
              const SizedBox(height: 10),
              buildSettingsTile(
                sheetContext,
                icon: Icons.verified_user_outlined,
                title: 'Account status',
                subtitle: accountBadgeLabel,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PlanoraTheme.isDark(context)
            ? PlanoraTheme.darkSurfaceVariant
            : PlanoraTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: mutedColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Future<void> showInfoSheet({
    required String title,
    required IconData icon,
    required String body,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: sheetBarrierColor(context),
      enableDrag: true,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 300),
        reverseDuration: Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      builder: (sheetContext) {
        return buildSheetSurface(
          sheetContext,
          title: title,
          icon: icon,
          child: Text(
            body,
            style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                  color: mutedColor(sheetContext),
                  fontWeight: FontWeight.w600,
                  height: 1.55,
                ),
          ),
        );
      },
    );
  }

  Widget buildSheetSurface(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
    bool isBusy = false,
  }) {
    final isDark = PlanoraTheme.isDark(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final mediaSize = MediaQuery.sizeOf(context);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 430,
            maxHeight: mediaSize.height * 0.90,
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            builder: (context, value, animatedChild) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, (1 - value) * 12),
                  child: Transform.scale(
                    scale: 0.985 + (value * 0.015),
                    alignment: Alignment.bottomCenter,
                    child: animatedChild,
                  ),
                ),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? PlanoraTheme.darkSurface : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.50 : 0.16),
                      blurRadius: 28,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isDark
                                ? PlanoraTheme.darkBorder
                                : PlanoraTheme.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              icon,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: isBusy
                                ? null
                                : () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      child,
                    ],
                  ),
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
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: mutedColor(context),
            fontWeight: FontWeight.w900,
          ),
    );
  }

  Widget buildSheetTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    FocusNode? focusNode,
    String? errorText,
    bool obscureText = false,
    bool enabled = true,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    Iterable<String>? autofillHints,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    Widget? suffixIcon,
  }) {
    final isDark = PlanoraTheme.isDark(context);
    final primary = Theme.of(context).colorScheme.primary;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: isDark ? PlanoraTheme.darkTextPrimary : PlanoraTheme.textPrimary,
          ),
      decoration: InputDecoration(
        hintText: hintText,
        errorText: errorText,
        filled: true,
        fillColor: isDark ? PlanoraTheme.darkSurfaceVariant : PlanoraTheme.surfaceVariant,
        prefixIcon: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primary, size: 19),
          ),
        ),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: PlanoraTheme.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: PlanoraTheme.error, width: 1.4),
        ),
      ),
    );
  }

  Widget buildInlineError(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PlanoraTheme.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: PlanoraTheme.error),
          const SizedBox(width: 8),
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
    final disabledBackground = isDark
        ? PlanoraTheme.darkSurfaceVariant
        : const Color(0xFFF3F0FF);
    final disabledForeground = isDark
        ? PlanoraTheme.darkTextSecondary
        : PlanoraTheme.textSecondary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: isEnabled ? PlanoraTheme.primaryGradientFor(context) : null,
        color: isEnabled ? null : disabledBackground,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isEnabled ? PlanoraTheme.floatingShadowFor(context) : [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: isEnabled && !isLoading ? onPressed : null,
          borderRadius: BorderRadius.circular(18),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: isLoading
                  ? Row(
                      key: const ValueKey('loading'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          loadingLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      key: ValueKey(label),
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 19,
                          color: isEnabled ? Colors.white : disabledForeground,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: TextStyle(
                            color: isEnabled ? Colors.white : disabledForeground,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
            ),
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
