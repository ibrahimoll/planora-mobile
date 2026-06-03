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

        SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $firstName👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),

              SizedBox(height: 3),

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

        SizedBox(width: 10),

        buildHeaderIconButton(
          context: context,
          icon: Icons.notifications_none_rounded,
          onTap: () {},
        ),
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

  Widget buildHeaderIconButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = PlanoraTheme.isDark(context);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
          ),
          boxShadow: PlanoraTheme.cardShadowFor(context),
        ),
        child: Icon(icon, size: 21),
      ),
    );
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
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    buildHeader(context),
                    const SizedBox(height: 24),

                    Expanded(
                      child: Center(
                        child: Text(
                          isDark
                              ? 'Dark home dashboard coming next'
                              : 'Light home dashboard coming next',
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
