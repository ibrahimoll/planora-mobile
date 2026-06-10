import 'package:flutter/material.dart';
import 'package:mobile/features/auth/data/project_api.dart';
import 'package:mobile/features/auth/models/project_models.dart';
import 'package:mobile/features/tasks/data/tasks_api.dart';
import 'package:mobile/features/tasks/models/task_models.dart';
import 'package:mobile/features/teams/data/teams_api.dart';

class TeamsScreen extends StatefulWidget {
  final TeamsApi teamsApi;
  final ProjectsApi projectsApi;
  final TasksApi tasksApi;
  final bool showBackButton;
  final VoidCallback? onTeamsChanged;
  final int? currentUserId;

  const TeamsScreen({
    super.key,
    this.teamsApi = const TeamsApi(),
    this.projectsApi = const ProjectsApi(),
    this.tasksApi = const TasksApi(),
    this.showBackButton = false,
    this.onTeamsChanged,
    this.currentUserId,
  });

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  int _selectedTabIndex = 0;
  String _searchQuery = '';

  bool _isLoading = true;
  bool _isCreatingTeam = false;
  String? _errorMessage;

  List<TeamModel> _teams = [];
  List<TeamInvitationModel> _invitations = [];
  final Map<int, List<TeamMemberModel>> _membersByTeamId = {};
  final Map<int, _TeamStats> _statsByTeamId = {};

  List<TeamModel> get _visibleTeams {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _teams;
    }

    return _teams.where((team) {
      return team.name.toLowerCase().contains(query);
    }).toList();
  }

  List<TeamInvitationModel> get _pendingInvitations {
    return _invitations.where((item) => item.isPending).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final teams = await widget.teamsApi.getTeams();
      final invitations = await widget.teamsApi.getMyInvitations();

      if (!mounted) {
        return;
      }

      setState(() {
        _teams = teams;
        _invitations = invitations;
        _isLoading = false;
        _errorMessage = null;
      });

      await _loadTeamDetails(teams);
    } catch (error, stackTrace) {
      debugPrint('Teams page load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load teams. Pull down or tap retry.';
      });
    }
  }

  Future<void> _loadTeamDetails(List<TeamModel> teams) async {
    for (final team in teams) {
      try {
        final members = await widget.teamsApi.getTeamMembers(team.teamId);

        List<ProjectModel> projects = [];
        try {
          projects = await widget.projectsApi.getTeamProjects(team.teamId);
        } catch (error, stackTrace) {
          debugPrint('Team project load failed for ${team.teamId}: $error');
          debugPrintStack(stackTrace: stackTrace);
        }

        var taskCount = 0;
        for (final project in projects) {
          try {
            final tasks = await widget.tasksApi.getProjectTasks(
              project: TaskProjectSummary.fromProject(project),
            );
            taskCount += tasks.length;
          } catch (error, stackTrace) {
            debugPrint(
              'Team task load failed for team ${team.teamId}, project ${project.projectId}: $error',
            );
            debugPrintStack(stackTrace: stackTrace);
          }
        }

        if (!mounted) {
          return;
        }

        setState(() {
          _membersByTeamId[team.teamId] = members;
          _statsByTeamId[team.teamId] = _TeamStats(
            memberCount: members.length,
            projectCount: projects.length,
            taskCount: taskCount,
          );
        });
      } catch (error, stackTrace) {
        debugPrint('Team member/stat load failed for ${team.teamId}: $error');
        debugPrintStack(stackTrace: stackTrace);

        if (!mounted) {
          return;
        }

        setState(() {
          _statsByTeamId[team.teamId] = const _TeamStats(
            memberCount: 0,
            projectCount: 0,
            taskCount: 0,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = RefreshIndicator(
      color: const Color(0xFF7C3AED),
      onRefresh: () => _loadTeams(showLoading: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(0, 0, 0, widget.showBackButton ? 28 : 110),
        children: [
          _Header(
            showBackButton: widget.showBackButton,
            onBackPressed: () => Navigator.of(context).maybePop(),
            onCreatePressed: _openCreateTeamSheet,
          ),
          const SizedBox(height: 18),
          _SearchAndFilterRow(
            onChanged: (value) => setState(() => _searchQuery = value),
            onFilterPressed: _openFilterSheet,
          ),
          const SizedBox(height: 22),
          _Tabs(
            selectedIndex: _selectedTabIndex,
            invitationCount: _pendingInvitations.length,
            onChanged: (index) => setState(() => _selectedTabIndex = index),
          ),
          const SizedBox(height: 18),
          if (_selectedTabIndex == 0)
            ..._buildTeamContent()
          else ...[
            _buildInvitationContent(),
          ],
          const SizedBox(height: 4),
          _CreateTeamBanner(
            isLoading: _isCreatingTeam,
            onPressed: _openCreateTeamSheet,
          ),
        ],
      ),
    );

    if (!widget.showBackButton) {
      return content;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
          child: content,
        ),
      ),
    );
  }

  List<Widget> _buildTeamContent() {
    if (_isLoading && _teams.isEmpty) {
      return const [
        _TeamLoadingCard(),
        SizedBox(height: 14),
        _TeamLoadingCard(),
        SizedBox(height: 14),
        _TeamLoadingCard(),
      ];
    }

    if (_errorMessage != null && _teams.isEmpty) {
      return [
        _StateCard(
          icon: Icons.wifi_off_rounded,
          title: 'Teams could not load',
          message: _errorMessage!,
          actionText: 'Retry',
          onAction: () => _loadTeams(),
        ),
      ];
    }

    if (_visibleTeams.isEmpty) {
      return [
        _StateCard(
          icon: Icons.groups_2_outlined,
          title: _searchQuery.trim().isEmpty
              ? 'No teams yet'
              : 'No teams found',
          message: _searchQuery.trim().isEmpty
              ? 'Create your first team and start collaborating on Planora projects.'
              : 'Try a different search keyword.',
          actionText: _searchQuery.trim().isEmpty ? 'Create Team' : null,
          onAction: _searchQuery.trim().isEmpty ? _openCreateTeamSheet : null,
        ),
      ];
    }

    return [
      for (final team in _visibleTeams) ...[
        _TeamCard(
          team: team,
          members: _membersByTeamId[team.teamId] ?? const [],
          stats: _statsByTeamId[team.teamId],
          currentUserId: widget.currentUserId,
          onTap: () => _openTeamSheet(team),
          onMenuPressed: () => _openTeamActionsSheet(team),
        ),
        const SizedBox(height: 14),
      ],
    ];
  }

  Widget _buildInvitationContent() {
    if (_isLoading && _invitations.isEmpty) {
      return const _TeamLoadingCard();
    }

    if (_pendingInvitations.isEmpty) {
      return const _StateCard(
        icon: Icons.mail_outline_rounded,
        title: 'No invitations yet',
        message: 'Team invitations will appear here when someone invites you.',
      );
    }

    return Column(
      children: [
        for (final invitation in _pendingInvitations) ...[
          _InvitationCard(
            invitation: invitation,
            onAccept: () => _respondToInvitation(invitation, accept: true),
            onReject: () => _respondToInvitation(invitation, accept: false),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Future<void> _openCreateTeamSheet() async {
    final controller = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _BottomSheetShell(
              title: 'Create a new team',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Team name',
                      hintText: 'Example: Design Team',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) async {
                      await _submitCreateTeam(
                        sheetContext: sheetContext,
                        setSheetState: setSheetState,
                        controller: controller,
                        isSubmitting: isSubmitting,
                        setSubmitting: (value) => isSubmitting = value,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _PrimarySheetButton(
                    label: isSubmitting ? 'Creating...' : 'Create Team',
                    isLoading: isSubmitting,
                    onPressed: isSubmitting
                        ? null
                        : () => _submitCreateTeam(
                            sheetContext: sheetContext,
                            setSheetState: setSheetState,
                            controller: controller,
                            isSubmitting: isSubmitting,
                            setSubmitting: (value) => isSubmitting = value,
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    controller.dispose();
  }

  Future<void> _submitCreateTeam({
    required BuildContext sheetContext,
    required StateSetter setSheetState,
    required TextEditingController controller,
    required bool isSubmitting,
    required ValueChanged<bool> setSubmitting,
  }) async {
    final name = controller.text.trim();

    if (name.isEmpty) {
      _showMessage('Enter a team name first.');
      return;
    }

    if (isSubmitting) {
      return;
    }

    setSheetState(() {
      setSubmitting(true);
    });

    if (mounted) {
      setState(() {
        _isCreatingTeam = true;
      });
    }

    var wasCreated = false;

    try {
      await widget.teamsApi.createTeam(name);
      wasCreated = true;
    } catch (error, stackTrace) {
      debugPrint('Create team failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage('Could not create team. Try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingTeam = false;
        });
      }

      setSheetState(() {
        setSubmitting(false);
      });
    }

    if (!wasCreated || !mounted) {
      return;
    }

    Navigator.of(sheetContext).pop();
    _showMessage('Team created.');
    widget.onTeamsChanged?.call();
    await _loadTeams(showLoading: false);
  }

  Future<void> _openTeamActionsSheet(TeamModel team) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _BottomSheetShell(
          title: team.name,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionTile(
                icon: Icons.person_add_alt_1_rounded,
                title: 'Invite member',
                subtitle: 'Invite by username',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openInviteMemberSheet(team);
                },
              ),
              _ActionTile(
                icon: Icons.refresh_rounded,
                title: 'Refresh team',
                subtitle: 'Reload members, projects, and tasks',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _loadTeams(showLoading: false);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openTeamSheet(TeamModel team) async {
    final members = _membersByTeamId[team.teamId] ?? const <TeamMemberModel>[];
    final stats = _statsByTeamId[team.teamId];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _BottomSheetShell(
          title: team.name,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _SheetStat(
                    label: 'Members',
                    value: '${stats?.memberCount ?? members.length}',
                  ),
                  _SheetStat(
                    label: 'Projects',
                    value: '${stats?.projectCount ?? 0}',
                  ),
                  _SheetStat(label: 'Tasks', value: '${stats?.taskCount ?? 0}'),
                ],
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Members',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 8),
              if (members.isEmpty)
                const _SmallMutedText('Members are loading or unavailable.')
              else
                for (final member in members.take(8))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _InitialsAvatar(
                      label: member.initials,
                      color: _avatarColor(member.userId),
                    ),
                    title: Text(
                      member.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(member.roleLabel),
                  ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openInviteMemberSheet(TeamModel team) async {
    final controller = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _BottomSheetShell(
              title: 'Invite to ${team.name}',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      hintText: 'Enter username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PrimarySheetButton(
                    label: isSubmitting ? 'Sending...' : 'Send Invite',
                    isLoading: isSubmitting,
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final username = controller.text.trim();

                            if (username.isEmpty) {
                              _showMessage('Enter a username first.');
                              return;
                            }

                            setSheetState(() {
                              isSubmitting = true;
                            });

                            var wasSent = false;

                            try {
                              await widget.teamsApi.inviteUser(
                                teamId: team.teamId,
                                username: username,
                              );
                              wasSent = true;
                            } catch (error, stackTrace) {
                              debugPrint('Invite member failed: $error');
                              debugPrintStack(stackTrace: stackTrace);
                              _showMessage('Could not send invitation.');
                            } finally {
                              setSheetState(() {
                                isSubmitting = false;
                              });
                            }

                            if (!wasSent || !mounted) {
                              return;
                            }

                            Navigator.of(sheetContext).pop();
                            _showMessage('Invitation sent.');
                            await _loadTeams(showLoading: false);
                          },
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    controller.dispose();
  }

  Future<void> _respondToInvitation(
    TeamInvitationModel invitation, {
    required bool accept,
  }) async {
    try {
      if (accept) {
        await widget.teamsApi.acceptInvitation(invitation.invitationId);
      } else {
        await widget.teamsApi.rejectInvitation(invitation.invitationId);
      }

      if (!mounted) {
        return;
      }

      _showMessage(accept ? 'Invitation accepted.' : 'Invitation rejected.');
      widget.onTeamsChanged?.call();
      await _loadTeams(showLoading: false);
    } catch (error, stackTrace) {
      debugPrint('Invitation response failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage('Could not update invitation.');
    }
  }

  void _openFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _BottomSheetShell(
          title: 'Filter teams',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionTile(
                icon: Icons.groups_2_outlined,
                title: 'All teams',
                subtitle: 'Showing all teams you belong to',
                onTap: () => Navigator.of(context).pop(),
              ),
              _ActionTile(
                icon: Icons.mail_outline_rounded,
                title: 'Invitations',
                subtitle: 'View pending invitations',
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _selectedTabIndex = 1;
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

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
        _GradientIconButton(
          icon: Icons.add_rounded,
          onPressed: onCreatePressed,
        ),
      ],
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
          child: _CardShell(
            height: 48,
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
        _SmallIconButton(icon: Icons.tune_rounded, onPressed: onFilterPressed),
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
                  if (badge != null && badge! > 0) ...[
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
    required this.members,
    required this.stats,
    required this.currentUserId,
    required this.onTap,
    required this.onMenuPressed,
  });

  final TeamModel team;
  final List<TeamMemberModel> members;
  final _TeamStats? stats;
  final int? currentUserId;
  final VoidCallback onTap;
  final VoidCallback onMenuPressed;

  TeamMemberModel? get _currentMember {
    final id = currentUserId;

    if (id == null) {
      return null;
    }

    for (final member in members) {
      if (member.userId == id) {
        return member;
      }
    }

    return null;
  }

  IconData get _icon {
    final normalized = team.name.toLowerCase();

    if (normalized.contains('design')) {
      return Icons.business_center_outlined;
    }

    if (normalized.contains('dev') || normalized.contains('code')) {
      return Icons.code_rounded;
    }

    if (normalized.contains('market')) {
      return Icons.campaign_outlined;
    }

    return Icons.rocket_launch_outlined;
  }

  Color get _iconColor {
    final normalized = team.name.toLowerCase();

    if (normalized.contains('design')) {
      return const Color(0xFF3B82F6);
    }

    if (normalized.contains('dev') || normalized.contains('code')) {
      return const Color(0xFF22C55E);
    }

    if (normalized.contains('market')) {
      return const Color(0xFFF59E0B);
    }

    return const Color(0xFF7C3AED);
  }

  Color get _iconBackground {
    final normalized = team.name.toLowerCase();

    if (normalized.contains('design')) {
      return const Color(0xFFEAF2FF);
    }

    if (normalized.contains('dev') || normalized.contains('code')) {
      return const Color(0xFFEAFBF0);
    }

    if (normalized.contains('market')) {
      return const Color(0xFFFFF6E6);
    }

    return const Color(0xFFF0EAFF);
  }

  @override
  Widget build(BuildContext context) {
    final currentMember = _currentMember;
    final memberCount = stats?.memberCount ?? members.length;
    final projectCount = stats?.projectCount ?? 0;
    final taskCount = stats?.taskCount ?? 0;
    final previewMembers = members.take(3).toList();
    final extraMembers = memberCount > previewMembers.length
        ? memberCount - previewMembers.length
        : 0;

    return _CardShell(
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
                        color: _iconBackground,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(_icon, color: _iconColor, size: 31),
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
                                if (currentMember != null) ...[
                                  const SizedBox(width: 8),
                                  _RoleBadge(label: currentMember.roleLabel),
                                ],
                              ],
                            ),
                            const SizedBox(height: 7),
                            Text(
                              'Workspace for team projects',
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
                              members: previewMembers,
                              extraCount: extraMembers,
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
                        value: memberCount,
                        label: 'Members',
                      ),
                    ),
                    Expanded(
                      child: _StatItem(
                        icon: Icons.folder_copy_outlined,
                        value: projectCount,
                        label: 'Projects',
                      ),
                    ),
                    Expanded(
                      child: _StatItem(
                        icon: Icons.check_box_outlined,
                        value: taskCount,
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
  const _AvatarStack({required this.members, required this.extraCount});

  final List<TeamMemberModel> members;
  final int extraCount;

  @override
  Widget build(BuildContext context) {
    const double size = 26;
    const double overlap = 18;
    final width = (members.length * overlap) + (extraCount > 0 ? 33 : 12);

    if (members.isEmpty) {
      return const SizedBox(
        height: size,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'No members loaded',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF8A91AA),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: size,
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int index = 0; index < members.length; index++)
            Positioned(
              left: index * overlap,
              child: _InitialsAvatar(
                label: members[index].initials,
                color: _avatarColor(members[index].userId),
                size: size,
              ),
            ),
          if (extraCount > 0)
            Positioned(
              left: members.length * overlap,
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

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.invitation,
    required this.onAccept,
    required this.onReject,
  });

  final TeamInvitationModel invitation;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFF0EAFF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.mail_outline_rounded,
                color: Color(0xFF7C3AED),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Team #${invitation.teamId}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF171B2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Role: ${invitation.role}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6C7391),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            _TinyActionButton(
              label: 'No',
              color: const Color(0xFFEF4444),
              onTap: onReject,
            ),
            const SizedBox(width: 8),
            _TinyActionButton(
              label: 'Yes',
              color: const Color(0xFF7C3AED),
              onTap: onAccept,
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateTeamBanner extends StatelessWidget {
  const _CreateTeamBanner({required this.isLoading, required this.onPressed});

  final bool isLoading;
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
                  'Invite your team members and start collaborating together.',
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
                onTap: isLoading ? null : onPressed,
                child: Center(
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
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

class _TeamLoadingCard extends StatelessWidget {
  const _TeamLoadingCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFF0EAFF),
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonLine(width: 130),
                  SizedBox(height: 10),
                  _SkeletonLine(width: 190),
                  SizedBox(height: 10),
                  _SkeletonLine(width: 90),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 10,
      decoration: BoxDecoration(
        color: const Color(0xFFEDEFF7),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionText,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          children: [
            Icon(icon, size: 42, color: const Color(0xFF7C3AED)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF171B2E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6C7391),
              ),
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 16),
              _TinyActionButton(
                label: actionText!,
                color: const Color(0xFF7C3AED),
                onTap: onAction!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, this.height});

  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
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
      child: child,
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  const _SmallIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      height: 48,
      child: SizedBox(
        width: 48,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onPressed,
            child: Icon(icon, color: const Color(0xFF68708C), size: 23),
          ),
        ),
      ),
    );
  }
}

class _GradientIconButton extends StatelessWidget {
  const _GradientIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          onTap: onPressed,
          child: Icon(icon, color: Colors.white, size: 30),
        ),
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

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({
    required this.label,
    required this.color,
    this.size = 34,
  });

  final String label;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final text = label.trim().isEmpty ? '?' : label.trim();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        text.length > 2
            ? text.substring(0, 2).toUpperCase()
            : text.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: size <= 28 ? 10 : 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE8FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF7C3AED),
        ),
      ),
    );
  }
}

class _TinyActionButton extends StatelessWidget {
  const _TinyActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomSheetShell extends StatelessWidget {
  const _BottomSheetShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding + 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6E8F2),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF171B2E),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF7C3AED)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _PrimarySheetButton extends StatelessWidget {
  const _PrimarySheetButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Material(
        color: onPressed == null
            ? const Color(0xFFC4B5FD)
            : const Color(0xFF7C3AED),
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onPressed,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SheetStat extends StatelessWidget {
  const _SheetStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: _CardShell(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Color(0xFF171B2E),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: Color(0xFF6C7391),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallMutedText extends StatelessWidget {
  const _SmallMutedText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF6C7391),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TeamStats {
  const _TeamStats({
    required this.memberCount,
    required this.projectCount,
    required this.taskCount,
  });

  final int memberCount;
  final int projectCount;
  final int taskCount;
}

Color _avatarColor(int seed) {
  const colors = [
    Color(0xFF8B5CF6),
    Color(0xFFF97316),
    Color(0xFF0EA5E9),
    Color(0xFF10B981),
    Color(0xFFEF4444),
    Color(0xFF6366F1),
  ];

  return colors[seed.abs() % colors.length];
}
