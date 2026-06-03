import 'package:flutter/material.dart';

import '../../core/storage/token_storage.dart';
import '../../core/theme/planora_theme.dart';
import '../auth/models/auth_models.dart';

class HomeScreen extends StatefulWidget {
  final UserResponse user;
  final VoidCallback onThemeToggle;
  final VoidCallback? onLoggedOut;

  const HomeScreen({
    super.key,
    required this.user,
    required this.onThemeToggle,
    this.onLoggedOut,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;
  bool hasUnreadNotifications = false;

  final double projectProgress = 0.72;

  final int onTrackProjects = 12;
  final int inProgressProjects = 6;
  final int atRiskProjects = 3;
  final int completedProjects = 24;

  Future<void> logout(BuildContext context) async {
    await TokenStorage.clearAccessToken();

    if (!context.mounted) return;

    if (widget.onLoggedOut != null) {
      widget.onLoggedOut!();
      return;
    }

    Navigator.of(context).pop();
  }

  String get displayName {
    final fullName = widget.user.fullName.trim();

    if (fullName.isNotEmpty) {
      return fullName;
    }

    return widget.user.username;
  }

  String get firstName {
    final parts = displayName.split(RegExp(r'\s+'));

    if (parts.isEmpty) {
      return widget.user.username;
    }

    return parts.first;
  }

  String get greeting {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return 'Good morning';
    }

    if (hour >= 12 && hour < 17) {
      return 'Good afternoon';
    }

    if (hour >= 17 && hour < 21) {
      return 'Good evening';
    }

    return 'Good night';
  }

  String getInitials() {
    final source = displayName.trim();

    if (source.isEmpty) {
      return 'P';
    }

    final parts = source.split(RegExp(r'\s+'));

    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }

    return source[0].toUpperCase();
  }

  Widget buildHeader(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    final secondaryTextColor = isDark
        ? PlanoraTheme.darkTextMuted
        : PlanoraTheme.textSecondary;

    return Row(
      children: [
        buildAvatar(context),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $firstName 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                'Ready to plan something amazing?',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: secondaryTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        buildSearchButton(context),
        const SizedBox(width: 10),
        buildNotificationButton(context),
      ],
    );
  }

  Widget buildAvatar(BuildContext context) {
    final profilePic = widget.user.profilePic;
    final hasProfilePic = profilePic != null && profilePic.trim().isNotEmpty;

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          builder: (context) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.dark_mode_outlined),
                      title: const Text('Toggle theme'),
                      onTap: () {
                        Navigator.pop(context);
                        widget.onThemeToggle();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.logout_rounded),
                      title: const Text('Logout'),
                      onTap: () {
                        Navigator.pop(context);
                        logout(context);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: hasProfilePic
              ? null
              : PlanoraTheme.primaryGradientFor(context),
          boxShadow: PlanoraTheme.cardShadowFor(context),
        ),
        child: CircleAvatar(
          backgroundColor: Colors.transparent,
          backgroundImage: hasProfilePic ? NetworkImage(profilePic) : null,
          child: hasProfilePic
              ? null
              : Text(
                  getInitials(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
      ),
    );
  }

  Widget buildSearchButton(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        // Later this will open the search screen.
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
          ),
          boxShadow: PlanoraTheme.cardShadowFor(context),
        ),
        child: Icon(
          Icons.search_rounded,
          size: 21,
          color: isDark
              ? PlanoraTheme.darkTextPrimary
              : PlanoraTheme.textPrimary,
        ),
      ),
    );
  }

  Widget buildNotificationButton(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        // Later this will open the notifications screen.
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
              ),
              boxShadow: PlanoraTheme.cardShadowFor(context),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 21,
              color: isDark
                  ? PlanoraTheme.darkTextPrimary
                  : PlanoraTheme.textPrimary,
            ),
          ),
          if (hasUnreadNotifications)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildProjectOverviewCard(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
        ),
        boxShadow: PlanoraTheme.cardShadowFor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildOverviewHeader(context),
          const SizedBox(height: 18),
          Row(
            children: [
              buildCircularProgress(context),
              const SizedBox(width: 22),
              Expanded(child: buildOverviewLegend(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildOverviewHeader(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            'Project Overview',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: isDark
                  ? PlanoraTheme.darkTextPrimary
                  : PlanoraTheme.textPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This Month',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? PlanoraTheme.darkTextMuted
                      : PlanoraTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: isDark
                    ? PlanoraTheme.darkTextMuted
                    : PlanoraTheme.textSecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildCircularProgress(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: CircularProgressIndicator(
              value: projectProgress,
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              color: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(projectProgress * 100).round()}%',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                'On Track',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildOverviewLegend(BuildContext context) {
    return Column(
      children: [
        buildLegendRow(
          context: context,
          label: 'On Track',
          value: onTrackProjects,
          color: Theme.of(context).colorScheme.primary,
        ),
        buildLegendRow(
          context: context,
          label: 'In Progress',
          value: inProgressProjects,
          color: Colors.blueAccent,
        ),
        buildLegendRow(
          context: context,
          label: 'At Risk',
          value: atRiskProjects,
          color: Colors.orangeAccent,
        ),
        buildLegendRow(
          context: context,
          label: 'Completed',
          value: completedProjects,
          color: Colors.green,
        ),
      ],
    );
  }

  Widget buildLegendRow({
    required BuildContext context,
    required String label,
    required int value,
    required Color color,
  }) {
    final isDark = PlanoraTheme.isDark(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark
                    ? PlanoraTheme.darkTextMuted
                    : PlanoraTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '$value',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark
                  ? PlanoraTheme.darkTextPrimary
                  : PlanoraTheme.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSectionHeader({
    required BuildContext context,
    required String title,
    String? actionText,
    VoidCallback? onActionTap,
  }) {
    final isDark = PlanoraTheme.isDark(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: isDark
                  ? PlanoraTheme.darkTextPrimary
                  : PlanoraTheme.textPrimary,
            ),
          ),
        ),
        if (actionText != null)
          TextButton(
            onPressed: onActionTap,
            child: Text(
              actionText,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }

  Widget buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildSectionHeader(context: context, title: 'Quick Actions'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: buildQuickActionCard(
                context: context,
                icon: Icons.add_rounded,
                label: 'New Project',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: buildQuickActionCard(
                context: context,
                icon: Icons.check_box_outlined,
                label: 'New Task',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: buildQuickActionCard(
                context: context,
                icon: Icons.groups_2_outlined,
                label: 'Invite Team',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: buildQuickActionCard(
                context: context,
                icon: Icons.description_outlined,
                label: 'View Reports',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildQuickActionCard({
    required BuildContext context,
    required IconData icon,
    required String label,
  }) {
    final isDark = PlanoraTheme.isDark(context);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        // Later this will navigate to each feature.
      },
      child: Container(
        height: 82,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
          ),
          boxShadow: PlanoraTheme.cardShadowFor(context),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 23, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: isDark
                    ? PlanoraTheme.darkTextPrimary
                    : PlanoraTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildProjectsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildSectionHeader(
          context: context,
          title: 'My Projects',
          actionText: 'See All',
          onActionTap: () {},
        ),
        const SizedBox(height: 10),
        buildProjectTile(
          context: context,
          icon: Icons.language_rounded,
          title: 'Website Redesign',
          progress: 0.75,
          percentageText: '75%',
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 10),
        buildProjectTile(
          context: context,
          icon: Icons.phone_iphone_rounded,
          title: 'Mobile App Development',
          progress: 0.60,
          percentageText: '60%',
          color: Colors.blueAccent,
        ),
        const SizedBox(height: 10),
        buildProjectTile(
          context: context,
          icon: Icons.campaign_rounded,
          title: 'Marketing Campaign',
          progress: 0.30,
          percentageText: '30%',
          color: Colors.green,
        ),
      ],
    );
  }

  Widget buildProjectTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required double progress,
    required String percentageText,
    required Color color,
  }) {
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
        ),
        boxShadow: PlanoraTheme.cardShadowFor(context),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? PlanoraTheme.darkTextPrimary
                        : PlanoraTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    color: color,
                    backgroundColor: color.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            percentageText,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.more_horiz_rounded,
            color: isDark
                ? PlanoraTheme.darkTextMuted
                : PlanoraTheme.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget buildUpcomingTasksSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildSectionHeader(
          context: context,
          title: 'Upcoming Tasks',
          actionText: 'See All',
          onActionTap: () {},
        ),
        const SizedBox(height: 10),
        buildTaskTile(context),
      ],
    );
  }

  Widget buildTaskTile(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
        ),
        boxShadow: PlanoraTheme.cardShadowFor(context),
      ),
      child: Row(
        children: [
          Icon(
            Icons.radio_button_unchecked_rounded,
            color: isDark
                ? PlanoraTheme.darkTextMuted
                : PlanoraTheme.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Design homepage wireframe',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? PlanoraTheme.darkTextPrimary
                        : PlanoraTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: isDark
                          ? PlanoraTheme.darkTextMuted
                          : PlanoraTheme.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'May 24, 2024',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isDark
                            ? PlanoraTheme.darkTextMuted
                            : PlanoraTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'High',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBottomNavigation(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    final items = [
      (Icons.home_rounded, 'Home'),
      (Icons.folder_copy_outlined, 'Projects'),
      (Icons.check_box_outlined, 'Tasks'),
      (Icons.calendar_month_outlined, 'Calendar'),
      (Icons.person_outline_rounded, 'Profile'),
    ];

    return SafeArea(
      top: false,
      child: Container(
        height: 72,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
          ),
          boxShadow: PlanoraTheme.cardShadowFor(context),
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isSelected = selectedIndex == index;

            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  setState(() {
                    selectedIndex = index;
                  });
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.$1,
                      size: 22,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : isDark
                          ? PlanoraTheme.darkTextMuted
                          : PlanoraTheme.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : isDark
                            ? PlanoraTheme.darkTextMuted
                            : PlanoraTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: buildBottomNavigation(context),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: PlanoraTheme.onboardingBackgroundFor(context),
        ),
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  children: [
                    buildHeader(context),
                    const SizedBox(height: 24),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            buildProjectOverviewCard(context),
                            const SizedBox(height: 22),
                            buildQuickActions(context),
                            const SizedBox(height: 22),
                            buildProjectsSection(context),
                            const SizedBox(height: 22),
                            buildUpcomingTasksSection(context),
                          ],
                        ),
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
}
