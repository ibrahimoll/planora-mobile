import 'package:flutter/material.dart';

import '../../core/theme/planora_theme.dart';
import '../auth/models/auth_models.dart';
import 'widgets/home_bottom_nav.dart';

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

  String get displayName {
    final fullName = widget.user.fullName.trim();
    return fullName.isNotEmpty ? fullName : widget.user.username;
  }

  String get firstName {
    final parts = displayName.split(RegExp(r'\s+'));
    return parts.isEmpty ? widget.user.username : parts.first;
  }

  String get greeting {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 21) return 'Good evening';

    return 'Good night';
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

  Color mutedColor(BuildContext context) {
    return PlanoraTheme.isDark(context)
        ? PlanoraTheme.darkTextMuted
        : PlanoraTheme.textSecondary;
  }

  BoxDecoration cardDecoration(BuildContext context, {double radius = 18}) {
    final isDark = PlanoraTheme.isDark(context);

    return BoxDecoration(
      color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
      ),
      boxShadow: PlanoraTheme.cardShadowFor(context),
    );
  }

  void openProfileActions(BuildContext context) {
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
                    if (widget.onLoggedOut != null) {
                      widget.onLoggedOut!();
                      return;
                    }
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildHeader(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final profilePic = widget.user.profilePic;
    final hasProfilePic = profilePic != null && profilePic.trim().isNotEmpty;

    return Row(
      children: [
        GestureDetector(
          onTap: () => openProfileActions(context),
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
              backgroundImage: hasProfilePic ? NetworkImage(profilePic!) : null,
              child: hasProfilePic
                  ? null
                  : Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $firstName 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? PlanoraTheme.darkTextPrimary
                          : PlanoraTheme.textPrimary,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                'Ready to plan something amazing?',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: mutedColor(context),
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        buildHeaderButton(context, Icons.search_rounded),
        const SizedBox(width: 10),
        Stack(
          clipBehavior: Clip.none,
          children: [
            buildHeaderButton(context, Icons.notifications_none_rounded),
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
      ],
    );
  }

  Widget buildHeaderButton(BuildContext context, IconData icon) {
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      width: 44,
      height: 44,
      decoration: cardDecoration(context),
      child: Icon(
        icon,
        size: 21,
        color: isDark ? PlanoraTheme.darkTextPrimary : PlanoraTheme.textPrimary,
      ),
    );
  }

  Widget buildProjectOverview(BuildContext context) {
    final progress = 0.72;
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(context, radius: 24),
      child: Column(
        children: [
          Row(
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
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'This Month',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: mutedColor(context),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: mutedColor(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 112,
                height: 112,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 9,
                        strokeCap: StrokeCap.round,
                        color: Theme.of(context).colorScheme.primary,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.12),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(progress * 100).round()}%',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
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
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  children: [
                    buildLegendRow(context, 'On Track', '12', Theme.of(context).colorScheme.primary),
                    buildLegendRow(context, 'In Progress', '6', Colors.blueAccent),
                    buildLegendRow(context, 'At Risk', '3', Colors.orangeAccent),
                    buildLegendRow(context, 'Completed', '24', Colors.green),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildLegendRow(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
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
                    color: mutedColor(context),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }

  Widget buildSectionTitle(BuildContext context, String title, {String? action}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: () {},
            child: Text(action, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
      ],
    );
  }

  Widget buildQuickActions(BuildContext context) {
    final actions = [
      (Icons.add_rounded, 'New Project'),
      (Icons.task_alt_rounded, 'New Task'),
      (Icons.group_add_rounded, 'Invite Team'),
      (Icons.analytics_outlined, 'Reports'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildSectionTitle(context, 'Quick Actions'),
        const SizedBox(height: 10),
        Row(
          children: List.generate(actions.length, (index) {
            final action = actions[index];
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == actions.length - 1 ? 0 : 10),
                child: Container(
                  height: 86,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  decoration: cardDecoration(context),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          gradient: PlanoraTheme.primaryGradientFor(context),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: PlanoraTheme.floatingShadowFor(context),
                        ),
                        child: Icon(action.$1, size: 18, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        action.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget buildProjects(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildSectionTitle(context, 'My Projects', action: 'See All'),
        const SizedBox(height: 10),
        buildProjectTile(context, Icons.public_rounded, 'Website Redesign', 0.75, '75%', Theme.of(context).colorScheme.primary),
        const SizedBox(height: 10),
        buildProjectTile(context, Icons.phone_iphone_rounded, 'Mobile App Development', 0.60, '60%', Colors.blueAccent),
        const SizedBox(height: 10),
        buildProjectTile(context, Icons.rocket_launch_rounded, 'Marketing Campaign', 0.30, '30%', Colors.green),
      ],
    );
  }

  Widget buildProjectTile(
    BuildContext context,
    IconData icon,
    String title,
    double progress,
    String percentage,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: cardDecoration(context),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, color.withValues(alpha: 0.68)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.24),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
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
          Text(percentage, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(width: 6),
          Icon(Icons.more_horiz_rounded, color: mutedColor(context)),
        ],
      ),
    );
  }

  Widget buildUpcomingTask(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildSectionTitle(context, 'Upcoming Tasks', action: 'See All'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: cardDecoration(context),
          child: Row(
            children: [
              Icon(Icons.radio_button_unchecked_rounded, color: mutedColor(context)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Design homepage wireframe',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 13, color: mutedColor(context)),
                        const SizedBox(width: 5),
                        Text(
                          'May 24, 2024',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: mutedColor(context),
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
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
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
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: HomeBottomNav(
        selectedIndex: selectedIndex,
        onTap: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
      ),
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
                            buildProjectOverview(context),
                            const SizedBox(height: 22),
                            buildQuickActions(context),
                            const SizedBox(height: 22),
                            buildProjects(context),
                            const SizedBox(height: 22),
                            buildUpcomingTask(context),
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
