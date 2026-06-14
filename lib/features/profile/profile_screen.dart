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

  String get initials {
    final source = displayName.trim();

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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 44,
          height: 44,
          decoration: cardDecoration(
            context,
          ).copyWith(borderRadius: BorderRadius.circular(999)),
          child: Icon(icon, size: 21),
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
          IconButton(
            tooltip: 'Edit profile',
            onPressed: showEditProfileSheet,
            icon: Icon(Icons.chevron_right_rounded, color: mutedColor(context)),
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
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        gradient: PlanoraTheme.primaryGradientFor(context),
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: mutedColor(context),
            fontWeight: FontWeight.w800,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: mutedColor(context),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          decoration: cardDecoration(context),
          child: Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                buildMenuTile(context, item: items[index]),
                if (index != items.length - 1) buildDivider(context),
              ],
            ],
          ),
        ),
      ],
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

  static const List<ProfileInfoSection> _helpSupportSections = [
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
      title: 'Projects, tasks, and teams',
      body:
          'For project, task, team, invitation, or comment issues, include the project name, task title, team member involved if relevant, and whether the issue happened while creating, editing, deleting, assigning, or loading data.',
    ),
    ProfileInfoSection(
      title: 'AI planning issues',
      body:
          'For AI chat or AI planning issues, include what you asked Planora AI to do and what result you expected. Do not send passwords, private keys, financial secrets, or sensitive personal data in support messages or AI prompts.',
    ),
    ProfileInfoSection(
      title: 'Attachments and notifications',
      body:
          'For attachment problems, mention the file type and the action that failed. For notification issues, mention whether the problem is missing notifications, delayed notifications, or notifications that do not open the expected screen.',
    ),
    ProfileInfoSection(
      title: 'Basic troubleshooting',
      body:
          'Before reporting a bug, try refreshing the screen, checking your internet connection, closing and reopening the app, and signing in again if the session appears expired.',
    ),
    ProfileInfoSection(
      title: 'Known beta limitations',
      body:
          'Some settings are currently informational only. Advanced email preferences, per-channel notification settings, billing management, subscription management, and full account deletion are not fully exposed in the mobile app yet.',
    ),
    ProfileInfoSection(
      title: 'Contact',
      body:
          'Contact Planora support through the official support channel provided by the app or project owner. If this is a test build, send the report directly to the beta owner or developer.',
    ),
  ];

  static const List<ProfileInfoSection> _privacyPolicySections = [
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
      title: 'How we use information',
      body:
          'Planora uses this information to authenticate users, load your profile, manage projects and tasks, support team collaboration, send in-app notifications, handle attachments, and provide AI-assisted planning responses based on the content you choose to submit.',
    ),
    ProfileInfoSection(
      title: 'AI-assisted planning',
      body:
          'When you use AI planning or chat features, the information you enter may be used to generate task suggestions, project breakdowns, summaries, or productivity recommendations. Do not include passwords, private keys, financial secrets, or sensitive personal information in AI messages, project descriptions, task details, or comments.',
    ),
    ProfileInfoSection(
      title: 'Team collaboration and shared content',
      body:
          'Content added to shared workspaces, teams, projects, tasks, comments, invitations, and attachments may be visible to other authorized users who are part of the same workspace or collaboration flow.',
    ),
    ProfileInfoSection(
      title: 'Local device storage',
      body:
          'Planora may store authentication tokens and remembered login identifiers locally using secure device storage so the app can keep you signed in and restore your session safely.',
    ),
    ProfileInfoSection(
      title: 'Security',
      body:
          'Planora uses the configured backend API and secure local storage patterns to protect account access. No app can guarantee absolute security, so users should keep their credentials private and avoid sharing sensitive secrets inside workspace content.',
    ),
    ProfileInfoSection(
      title: 'Data retention',
      body:
          'Planora keeps account, workspace, project, task, team, comment, attachment, notification, and AI planning data for as long as needed to provide the app experience, maintain collaboration history, troubleshoot issues, or satisfy operational requirements.',
    ),
    ProfileInfoSection(
      title: 'Your choices',
      body:
          'You can update supported profile information from the Profile page and change your password through the password screen. Features such as full account deletion, advanced privacy settings, and per-channel notification preferences are not currently exposed in the mobile app.',
    ),
    ProfileInfoSection(
      title: 'Contact',
      body:
          'For privacy questions or support requests, contact Planora support through the official support channel provided by the app or project owner.',
    ),
    ProfileInfoSection(
      title: 'Legal review note',
      body:
          'This policy is provided for transparency inside Planora. For production release, review it with a qualified legal professional.',
    ),
  ];

  static const List<ProfileInfoSection> _termsSections = [
    ProfileInfoSection(title: 'Last updated', body: 'June 14, 2026'),
    ProfileInfoSection(
      title: 'Acceptance of terms',
      body:
          'By using Planora, you agree to use the app responsibly for lawful project planning, task management, team collaboration, and AI-assisted productivity workflows.',
    ),
    ProfileInfoSection(
      title: 'Account responsibility',
      body:
          'You are responsible for keeping your login credentials secure and for all activity performed through your account. If you believe your account is no longer secure, change your password and contact support through the official support channel.',
    ),
    ProfileInfoSection(
      title: 'Workspace and team content',
      body:
          'You are responsible for the projects, tasks, teams, invitations, comments, attachments, and other content you create or share in Planora. Only upload or share content that you own or have permission to use.',
    ),
    ProfileInfoSection(
      title: 'AI-generated suggestions',
      body:
          'Planora may generate AI-assisted suggestions, project plans, task breakdowns, or productivity guidance. AI output should be reviewed before use and should not be treated as guaranteed, professional, legal, financial, medical, or security advice.',
    ),
    ProfileInfoSection(
      title: 'Acceptable use',
      body:
          'Do not use Planora to upload illegal content, abuse other users, share malware, expose secrets, violate intellectual property rights, disrupt the service, or attempt unauthorized access to accounts, systems, projects, teams, or backend data.',
    ),
    ProfileInfoSection(
      title: 'Attachments and shared files',
      body:
          'Attachments and shared files should only include content that is safe, relevant, and permitted to be shared with the intended workspace or team members.',
    ),
    ProfileInfoSection(
      title: 'Service availability',
      body:
          'Planora depends on mobile app services, the configured backend API, storage, and network availability. Some features may be unavailable during maintenance, outages, development changes, or unsupported backend states.',
    ),
    ProfileInfoSection(
      title: 'Limitation of responsibility',
      body:
          'Planora is provided to help organize work and improve productivity. You remain responsible for reviewing your plans, tasks, shared content, and decisions before relying on them.',
    ),
    ProfileInfoSection(
      title: 'Updates to these terms',
      body:
          'These terms may be updated as Planora evolves. Continued use of the app after updates means you accept the revised terms shown in the app.',
    ),
    ProfileInfoSection(
      title: 'Contact',
      body:
          'For questions about these terms, contact Planora support through the official support channel provided by the app or project owner.',
    ),
    ProfileInfoSection(
      title: 'Legal review note',
      body:
          'This policy is provided for transparency inside Planora. For production release, review it with a qualified legal professional.',
    ),
  ];

  Widget buildMoreSection(BuildContext context) {
    return buildProfileSection(
      context,
      title: 'More',
      items: [
        _ProfileActionItem(
          icon: Icons.help_outline_rounded,
          title: 'Help & Support',
          subtitle: 'Get help and contact support',
          onTap: () => openProfileInfoPage(
            title: 'Help & Support',
            icon: Icons.help_outline_rounded,
            body:
                'For support, include your account email, the project or task name, and the exact action that failed. The mobile app now logs API failures with debugPrint to make reports easier to diagnose.',
          ),
        ),
        _ProfileActionItem(
          icon: Icons.shield_outlined,
          title: 'Privacy Policy',
          subtitle: 'How Planora handles your data',
          onTap: () => openProfileInfoPage(
            title: 'Privacy Policy',
            icon: Icons.shield_outlined,
            sections: _privacyPolicySections,
          ),
        ),
        _ProfileActionItem(
          icon: Icons.description_outlined,
          title: 'Terms of Service',
          subtitle: 'Rules for using Planora',
          onTap: () => openProfileInfoPage(
            title: 'Terms of Service',
            icon: Icons.description_outlined,
            sections: _termsSections,
          ),
        ),
      ],
    );
  }

  Widget buildMenuTile(
    BuildContext context, {
    required _ProfileActionItem item,
  }) {
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
                              } catch (error, stackTrace) {
                                debugPrint('Profile update failed: $error');
                                debugPrintStack(stackTrace: stackTrace);

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
                    buildProfileCard(context),
                    const SizedBox(height: 16),
                    buildStatsCard(context),
                    const SizedBox(height: 18),
                    buildAccountSection(context),
                    const SizedBox(height: 18),
                    buildWorkspaceSection(context),
                    const SizedBox(height: 18),
                    buildMoreSection(context),
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

class ProfileInfoScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? body;
  final List<ProfileInfoSection>? sections;

  const ProfileInfoScreen({
    super.key,
    required this.title,
    required this.icon,
    this.body,
    this.sections,
  }) : assert(body != null || sections != null);

  Color mutedColor(BuildContext context) {
    return PlanoraTheme.isDark(context)
        ? PlanoraTheme.darkTextMuted
        : PlanoraTheme.textSecondary;
  }

  List<Widget> buildContent(BuildContext context) {
    final infoSections = sections;

    if (infoSections == null || infoSections.isEmpty) {
      return [
        Text(
          body ?? '',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: mutedColor(context),
            fontWeight: FontWeight.w700,
            height: 1.45,
          ),
        ),
      ];
    }

    return [
      for (var index = 0; index < infoSections.length; index++) ...[
        if (index > 0) const SizedBox(height: 18),
        Text(
          infoSections[index].title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        Text(
          infoSections[index].body,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: mutedColor(context),
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: PlanoraTheme.onboardingBackgroundFor(context),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? PlanoraTheme.darkSurface
                          : PlanoraTheme.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark
                            ? PlanoraTheme.darkBorder
                            : PlanoraTheme.border,
                      ),
                      boxShadow: PlanoraTheme.cardShadowFor(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.11),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            icon,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 16),
                        ...buildContent(context),
                      ],
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

class ProfileInfoSection {
  final String title;
  final String body;

  const ProfileInfoSection({required this.title, required this.body});
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
