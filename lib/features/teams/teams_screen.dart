import 'package:flutter/material.dart';

class TeamsScreen extends StatefulWidget {
  final Object? teamsApi;
  final Object? projectsApi;
  final Object? tasksApi;
  final bool showBackButton;
  final VoidCallback? onTeamsChanged;

  const TeamsScreen({
    super.key,
    this.teamsApi,
    this.projectsApi,
    this.tasksApi,
    this.showBackButton = false,
    this.onTeamsChanged,
  });

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  int _selectedTabIndex = 0;
  String _searchQuery = '';

  final List<_TeamDemoData> _teams = const [
    _TeamDemoData(
      name: 'Planora Team',
      subtitle: 'Workspace for Planora AI development',
      badge: 'Owner',
      icon: Icons.rocket_launch_outlined,
      iconColor: Color(0xFF7C3AED),
      iconBackground: Color(0xFFF0EAFF),
      members: 12,
      projects: 8,
      tasks: 54,
      avatars: [Color(0xFF8D5A3B), Color(0xFFC98252), Color(0xFF6C4634)],
      extraMembers: 5,
    ),
    _TeamDemoData(
      name: 'Design Team',
      subtitle: 'UI/UX design and user experience',
      icon: Icons.business_center_outlined,
      iconColor: Color(0xFF3B82F6),
      iconBackground: Color(0xFFEAF2FF),
      members: 5,
      projects: 4,
      tasks: 23,
      avatars: [Color(0xFFC98252), Color(0xFF6C4634)],
      extraMembers: 3,
    ),
    _TeamDemoData(
      name: 'Development Team',
      subtitle: 'Building the future of Planora',
      icon: Icons.code_rounded,
      iconColor: Color(0xFF22C55E),
      iconBackground: Color(0xFFEAFBF0),
      members: 8,
      projects: 6,
      tasks: 38,
      avatars: [Color(0xFF8D5A3B), Color(0xFF6C4634), Color(0xFFC98252)],
      extraMembers: 4,
    ),
    _TeamDemoData(
      name: 'Marketing Team',
      subtitle: 'Spreading the word about Planora',
      icon: Icons.campaign_outlined,
      iconColor: Color(0xFFF59E0B),
      iconBackground: Color(0xFFFFF6E6),
      members: 4,
      projects: 3,
      tasks: 15,
      avatars: [Color(0xFFC98252), Color(0xFF6C4634)],
      extraMembers: 2,
    ),
  ];

  List<_TeamDemoData> get _visibleTeams {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _teams;
    }

    return _teams.where((team) {
      return team.name.toLowerCase().contains(query) ||
          team.subtitle.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        widget.showBackButton ? 22 : 0,
        widget.showBackButton ? 22 : 0,
        widget.showBackButton ? 22 : 0,
        110,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            showBackButton: widget.showBackButton,
            onBackPressed: () => Navigator.of(context).maybePop(),
            onCreatePressed: _showCreateTeamMessage,
          ),
          const SizedBox(height: 18),
          _SearchAndFilterRow(
            onChanged: (value) => setState(() => _searchQuery = value),
            onFilterPressed: () => _showMessage('Filters coming soon.'),
          ),
          const SizedBox(height: 22),
          _Tabs(
            selectedIndex: _selectedTabIndex,
            invitationCount: 2,
            onChanged: (index) => setState(() => _selectedTabIndex = index),
          ),
          const SizedBox(height: 18),
          if (_selectedTabIndex == 0)
            ..._visibleTeams.map(
              (team) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _TeamCard(
                  team: team,
                  onTap: () => _showMessage('${team.name} opened.'),
                  onMenuPressed: () =>
                      _showMessage('Team options coming soon.'),
                ),
              ),
            )
          else
            const _InvitationsCard(),
          const SizedBox(height: 4),
          _CreateTeamBanner(onPressed: _showCreateTeamMessage),
        ],
      ),
    );

    if (!widget.showBackButton) {
      return content;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFF),
      body: SafeArea(child: content),
    );
  }

  void _showCreateTeamMessage() {
    _showMessage('Create team flow will be connected here.');
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.showBackButton,
    required this.onBackPressed,
    required this.onCreatePressed,
  });

  final bool showBackButton;
  final VoidCallback onBackPressed;
  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showBackButton) ...[
          _SmallIconButton(
            icon: Icons.arrow_back_rounded,
            onPressed: onBackPressed,
          ),
          const SizedBox(width: 12),
        ],
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Teams',
                style: TextStyle(
                  fontSize: 28,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: Color(0xFF141724),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Manage your teams and collaborate',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6C7391),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
            ),
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.26),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: onCreatePressed,
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  const _SmallIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE6E8F2)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onPressed,
          child: Icon(icon, color: const Color(0xFF68708C)),
        ),
      ),
    );
  }
}

class _SearchAndFilterRow extends StatelessWidget {
  const _SearchAndFilterRow({
    required this.onChanged,
    required this.onFilterPressed,
  });

  final ValueChanged<String> onChanged;
  final VoidCallback onFilterPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xFFE6E8F2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: TextField(
              onChanged: onChanged,
              cursorColor: const Color(0xFF7C3AED),
              decoration: const InputDecoration(
                hintText: 'Search teams...',
                hintStyle: TextStyle(
                  color: Color(0xFF98A0B8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Color(0xFF8A91AA),
                  size: 22,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFE6E8F2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: onFilterPressed,
              child: const Icon(
                Icons.tune_rounded,
                color: Color(0xFF68708C),
                size: 23,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.selectedIndex,
    required this.invitationCount,
    required this.onChanged,
  });

  final int selectedIndex;
  final int invitationCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 35,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE7E9F2), width: 1)),
      ),
      child: Row(
        children: [
          _TabButton(
            label: 'My Teams',
            selected: selectedIndex == 0,
            onTap: () => onChanged(0),
          ),
          const SizedBox(width: 34),
          _TabButton(
            label: 'Invitations',
            selected: selectedIndex == 1,
            badge: invitationCount,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF7C3AED) : const Color(0xFF6C7391);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: SizedBox(
        width: 112,
        child: Stack(
          children: [
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: color,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECE7FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$badge',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.team,
    required this.onTap,
    required this.onMenuPressed,
  });

  final _TeamDemoData team;
  final VoidCallback onTap;
  final VoidCallback onMenuPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE8EAF4)),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 13),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: team.iconBackground,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(team.icon, color: team.iconColor, size: 31),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    team.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      height: 1.15,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.25,
                                      color: Color(0xFF171B2E),
                                    ),
                                  ),
                                ),
                                if (team.badge != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEDE8FF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      team.badge!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF7C3AED),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 7),
                            Text(
                              team.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6C7391),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _AvatarStack(
                              colors: team.avatars,
                              extraCount: team.extraMembers,
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: onMenuPressed,
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: Color(0xFF626B87),
                        size: 21,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFE9EBF4),
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        icon: Icons.group_outlined,
                        value: team.members,
                        label: 'Members',
                      ),
                    ),
                    Expanded(
                      child: _StatItem(
                        icon: Icons.folder_copy_outlined,
                        value: team.projects,
                        label: 'Projects',
                      ),
                    ),
                    Expanded(
                      child: _StatItem(
                        icon: Icons.check_box_outlined,
                        value: team.tasks,
                        label: 'Tasks',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.colors, required this.extraCount});

  final List<Color> colors;
  final int extraCount;

  @override
  Widget build(BuildContext context) {
    const double size = 26;
    const double overlap = 18;
    final width = (colors.length * overlap) + (extraCount > 0 ? 33 : 12);

    return SizedBox(
      height: size,
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int index = 0; index < colors.length; index++)
            Positioned(
              left: index * overlap,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: colors[index],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 15),
              ),
            ),
          if (extraCount > 0)
            Positioned(
              left: colors.length * overlap,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EBFF),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  '+$extraCount',
                  style: const TextStyle(
                    color: Color(0xFF7C3AED),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: const Color(0xFF69718D)),
            const SizedBox(width: 5),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF24283B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6C7391),
          ),
        ),
      ],
    );
  }
}

class _CreateTeamBanner extends StatelessWidget {
  const _CreateTeamBanner({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF4EDFF), Color(0xFFF8F5FF)],
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFEDE7FF)),
      ),
      child: Row(
        children: [
          Container(
            width: 49,
            height: 49,
            decoration: const BoxDecoration(
              color: Color(0xFFE6DAFF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_add_alt_1_rounded,
              color: Color(0xFF7C3AED),
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Create a new team',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF171B2E),
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Invite your team members and start\ncollaborating together.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6C7391),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 96,
            height: 40,
            child: Material(
              color: const Color(0xFF7C3AED),
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: onPressed,
                child: const Center(
                  child: Text(
                    'Create Team',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvitationsCard extends StatelessWidget {
  const _InvitationsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE8EAF4)),
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Column(
        children: [
          Icon(Icons.mail_outline_rounded, size: 42, color: Color(0xFF7C3AED)),
          SizedBox(height: 12),
          Text(
            'No invitations yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF171B2E),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Team invitations will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6C7391),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamDemoData {
  const _TeamDemoData({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.members,
    required this.projects,
    required this.tasks,
    required this.avatars,
    required this.extraMembers,
    this.badge,
  });

  final String name;
  final String subtitle;
  final String? badge;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final int members;
  final int projects;
  final int tasks;
  final List<Color> avatars;
  final int extraMembers;
}
