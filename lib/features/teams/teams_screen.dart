import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:mobile/core/network/api_exception.dart';
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
  final TextEditingController _searchController = TextEditingController();

  int _selectedTabIndex = 0;
  String _searchQuery = '';

  bool _isLoading = true;
  bool _isCreatingTeam = false;
  String? _errorMessage;

  List<TeamModel> _teams = [];
  List<TeamInvitationModel> _invitations = [];
  final Map<int, List<TeamMemberModel>> _membersByTeamId = {};
  final Map<int, List<ProjectModel>> _projectsByTeamId = {};
  final Map<int, _TeamStats> _statsByTeamId = {};

  List<TeamModel> get _visibleTeams {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _teams;
    }

    return _teams.where((team) {
      final members = _membersByTeamId[team.teamId] ?? const <TeamMemberModel>[];
      final projects = _projectsByTeamId[team.teamId] ?? const <ProjectModel>[];

      return team.name.toLowerCase().contains(query) ||
          members.any(
            (member) =>
                member.displayName.toLowerCase().contains(query) ||
                member.roleLabel.toLowerCase().contains(query),
          ) ||
          projects.any(
            (project) =>
                project.title.toLowerCase().contains(query) ||
                project.statusLabel.toLowerCase().contains(query),
          );
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        _errorMessage = null;
        _isLoading = false;
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

        var projects = <ProjectModel>[];
        try {
          projects = await widget.projectsApi.getTeamProjects(team.teamId);
        } catch (error, stackTrace) {
          debugPrint('Team project load failed for ${team.teamId}: $error');
          debugPrintStack(stackTrace: stackTrace);
        }

        var taskCount = 0;
        var completedTaskCount = 0;

        for (final project in projects) {
          try {
            final tasks = await widget.tasksApi.getProjectTasks(
              project: TaskProjectSummary.fromProject(project),
            );
            taskCount += tasks.length;
            completedTaskCount += tasks
                .where((item) => item.task.isCompleted)
                .length;
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
          _projectsByTeamId[team.teamId] = projects;
          _statsByTeamId[team.teamId] = _TeamStats(
            memberCount: members.length,
            projectCount: projects.length,
            taskCount: taskCount,
            completedTaskCount: completedTaskCount,
          );
        });
      } catch (error, stackTrace) {
        debugPrint('Team member/stat load failed for ${team.teamId}: $error');
        debugPrintStack(stackTrace: stackTrace);

        if (!mounted) {
          return;
        }

        setState(() {
          _membersByTeamId[team.teamId] = const [];
          _projectsByTeamId[team.teamId] = const [];
          _statsByTeamId[team.teamId] = const _TeamStats(
            memberCount: 0,
            projectCount: 0,
            taskCount: 0,
            completedTaskCount: 0,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF050816) : const Color(0xFFFAFAFF);

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
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            onClear: _clearSearch,
          ),
          const SizedBox(height: 18),
          _Tabs(
            selectedIndex: _selectedTabIndex,
            invitationCount: _pendingInvitations.length,
            onChanged: (index) => setState(() => _selectedTabIndex = index),
          ),
          const SizedBox(height: 18),
          if (_selectedTabIndex == 0)
            ..._buildTeamContent()
          else
            _buildInvitationContent(),
          const SizedBox(height: 6),
          _CreateTeamBanner(
            isLoading: _isCreatingTeam,
            onPressed: _openCreateTeamSheet,
          ),
        ],
      ),
    );

    if (!widget.showBackButton) {
      return ColoredBox(color: background, child: content);
    }

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
          child: content,
        ),
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
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
          title: _searchQuery.trim().isEmpty ? 'No teams yet' : 'No teams found',
          message: _searchQuery.trim().isEmpty
              ? 'Create your first team and start collaborating on Planora projects.'
              : 'Try another team, member, project, or role name.',
          actionText: _searchQuery.trim().isEmpty ? 'Create Team' : null,
          onAction: _searchQuery.trim().isEmpty ? _openCreateTeamSheet : null,
        ),
      ];
    }

    return [
      for (final team in _visibleTeams) ...[
        _buildSlidableTeamCard(team),
        const SizedBox(height: 14),
      ],
    ];
  }

  Widget _buildSlidableTeamCard(TeamModel team) {
    return Slidable(
      key: ValueKey('team-${team.teamId}'),
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.32,
        children: [
          SlidableAction(
            onPressed: (_) => _confirmDeleteTeam(team),
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            borderRadius: BorderRadius.circular(18),
          ),
        ],
      ),
      child: _TeamCard(
        team: team,
        members: _membersByTeamId[team.teamId] ?? const [],
        stats: _statsByTeamId[team.teamId],
        currentUserId: widget.currentUserId,
        onTap: () => _openTeamDetailsSheet(team),
        onMenuPressed: () => _openTeamActionsSheet(team),
      ),
    );
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
                  _SheetTextField(
                    controller: controller,
                    label: 'Team name',
                    hintText: 'Example: QA Team',
                    icon: Icons.groups_2_outlined,
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

    if (!wasCreated || !mounted || !sheetContext.mounted) {
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
                icon: Icons.info_outline_rounded,
                title: 'Team details',
                subtitle: 'Members, projects, and task activity',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openTeamDetailsSheet(team);
                },
              ),
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
              _ActionTile(
                icon: Icons.delete_outline_rounded,
                title: 'Delete team',
                subtitle: 'Remove this team if you have permission',
                color: const Color(0xFFEF4444),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmDeleteTeam(team);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openTeamDetailsSheet(TeamModel team) async {
    final members = _membersByTeamId[team.teamId] ?? const <TeamMemberModel>[];
    final projects = _projectsByTeamId[team.teamId] ?? const <ProjectModel>[];
    final stats = _statsByTeamId[team.teamId];
    final currentMember = _currentMemberForTeam(team);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _BottomSheetShell(
          title: team.name,
          maxHeightFactor: 0.86,
          child: Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TeamOverviewPanel(
                    team: team,
                    currentMember: currentMember,
                    stats: stats,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _SheetStat(
                        label: 'Members',
                        value: '${stats?.memberCount ?? members.length}',
                      ),
                      const SizedBox(width: 10),
                      _SheetStat(
                        label: 'Projects',
                        value: '${stats?.projectCount ?? projects.length}',
                      ),
                      const SizedBox(width: 10),
                      _SheetStat(
                        label: 'Tasks',
                        value: '${stats?.taskCount ?? 0}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SheetSectionHeader(
                    title: 'Members',
                    actionLabel: 'Invite',
                    onAction: () {
                      Navigator.of(context).pop();
                      _openInviteMemberSheet(team);
                    },
                  ),
                  const SizedBox(height: 10),
                  if (members.isEmpty)
                    const _SmallMutedText('Members are loading or unavailable.')
                  else
                    for (final member in members)
                      _MemberRow(member: member),
                  const SizedBox(height: 18),
                  const _SheetSectionHeader(title: 'Team projects'),
                  const SizedBox(height: 10),
                  if (projects.isEmpty)
                    const _SmallMutedText('No team projects yet.')
                  else
                    for (final project in projects.take(6))
                      _ProjectMiniRow(project: project),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  TeamMemberModel? _currentMemberForTeam(TeamModel team) {
    final id = widget.currentUserId;

    if (id == null) {
      return null;
    }

    final members = _membersByTeamId[team.teamId] ?? const <TeamMemberModel>[];

    for (final member in members) {
      if (member.userId == id) {
        return member;
      }
    }

    return null;
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
                  _SheetTextField(
                    controller: controller,
                    label: 'Username',
                    hintText: 'Enter username',
                    icon: Icons.alternate_email_rounded,
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

                            if (!wasSent || !mounted || !sheetContext.mounted) {
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

  Future<void> _confirmDeleteTeam(TeamModel team) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text('Delete team?'),
          content: Text(
            'This will remove "${team.name}" if your account has permission. Team projects may also be affected.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _deleteTeam(team);
  }

  Future<void> _deleteTeam(TeamModel team) async {
    final oldTeams = List<TeamModel>.from(_teams);
    final oldMembers = Map<int, List<TeamMemberModel>>.from(_membersByTeamId);
    final oldProjects = Map<int, List<ProjectModel>>.from(_projectsByTeamId);
    final oldStats = Map<int, _TeamStats>.from(_statsByTeamId);

    setState(() {
      _teams.removeWhere((item) => item.teamId == team.teamId);
      _membersByTeamId.remove(team.teamId);
      _projectsByTeamId.remove(team.teamId);
      _statsByTeamId.remove(team.teamId);
    });

    try {
      await widget.teamsApi.deleteTeam(team.teamId);

      if (!mounted) {
        return;
      }

      _showMessage('Team deleted.');
      widget.onTeamsChanged?.call();
    } catch (error, stackTrace) {
      debugPrint('Delete team failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _teams = oldTeams;
        _membersByTeamId
          ..clear()
          ..addAll(oldMembers);
        _projectsByTeamId
          ..clear()
          ..addAll(oldProjects);
        _statsByTeamId
          ..clear()
          ..addAll(oldStats);
      });

      _showMessage(_teamDeleteErrorMessage(error));
    }
  }

  String _teamDeleteErrorMessage(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 403) {
        return 'Only team owners/admins can delete this team.';
      }

      final message = error.message.trim();
      if (message.isNotEmpty && message != 'Something went wrong. Please try again.') {
        return message;
      }
    }

    return 'Could not delete team. Try again.';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF141724);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF6C7391);

    return Row(
      children: [
        if (showBackButton) ...[
          _SmallIconButton(
            icon: Icons.arrow_back_rounded,
            onPressed: onBackPressed,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Teams',
                style: TextStyle(
                  fontSize: 28,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage members, plans, and collaboration',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: subtitleColor,
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
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white60 : const Color(0xFF8A91AA);

    return _CardShell(
      height: 52,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        cursorColor: const Color(0xFF7C3AED),
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF111827),
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: 'Search teams, members, projects...',
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : const Color(0xFF98A0B8),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: iconColor,
            size: 22,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              if (value.text.trim().isEmpty) {
                return const SizedBox.shrink();
              }

              return IconButton(
                onPressed: onClear,
                icon: Icon(Icons.close_rounded, color: iconColor, size: 20),
              );
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 15,
          ),
        ),
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE7E9F2),
        ),
      ),
      child: Row(
        children: [
          _TabButton(
            label: 'My Teams',
            selected: selectedIndex == 0,
            onTap: () => onChanged(0),
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? primary.withValues(alpha: isDark ? 0.22 : 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: selected
                        ? primary
                        : isDark
                        ? Colors.white70
                        : const Color(0xFF6C7391),
                  ),
                ),
              ),
              if (badge != null && badge! > 0) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$badge',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
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
      return Icons.design_services_outlined;
    }

    if (normalized.contains('dev') || normalized.contains('code')) {
      return Icons.code_rounded;
    }

    if (normalized.contains('qa') || normalized.contains('test')) {
      return Icons.fact_check_outlined;
    }

    if (normalized.contains('market')) {
      return Icons.campaign_outlined;
    }

    return Icons.groups_2_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final currentMember = _currentMember;
    final memberCount = stats?.memberCount ?? members.length;
    final projectCount = stats?.projectCount ?? 0;
    final taskCount = stats?.taskCount ?? 0;
    final previewMembers = members.take(3).toList();
    final extraMembers = memberCount > previewMembers.length
        ? memberCount - previewMembers.length
        : 0;

    return _CardShell(
      borderRadius: 22,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: isDark ? 0.20 : 0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(_icon, color: primary, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
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
                                    style: TextStyle(
                                      fontSize: 17,
                                      height: 1.15,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.25,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF171B2E),
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
                              'Tap to see team details',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white60
                                    : const Color(0xFF6C7391),
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
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      onPressed: onMenuPressed,
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: isDark ? Colors.white54 : const Color(0xFF626B87),
                        size: 22,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? const Color(0xFF263244) : const Color(0xFFE9EBF4),
                ),
                const SizedBox(height: 12),
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

class _TeamOverviewPanel extends StatelessWidget {
  const _TeamOverviewPanel({
    required this.team,
    required this.currentMember,
    required this.stats,
  });

  final TeamModel team;
  final TeamMemberModel? currentMember;
  final _TeamStats? stats;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final completion = stats == null || stats!.taskCount == 0
        ? 0.0
        : stats!.completedTaskCount / stats!.taskCount;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.groups_2_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentMember == null
                          ? 'Team workspace'
                          : 'Your role: ${currentMember!.roleLabel}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: completion.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: isDark ? const Color(0xFF334155) : Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(completion * 100).round()}% team tasks completed',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: isDark ? Colors.white70 : const Color(0xFF4B5563),
            ),
          ),
        ],
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
    const double size = 28;
    const double overlap = 19;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = (members.length * overlap) + (extraCount > 0 ? 36 : 12);

    if (members.isEmpty) {
      return SizedBox(
        height: size,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Members loading...',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white38 : const Color(0xFF8A91AA),
              fontWeight: FontWeight.w700,
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
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF111827) : Colors.white,
                    width: 2,
                  ),
                ),
                child: Text(
                  '+$extraCount',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _CardShell(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.mail_outline_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Team #${invitation.teamId}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF171B2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Role: ${invitation.role}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : const Color(0xFF6C7391),
                      fontWeight: FontWeight.w700,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      constraints: const BoxConstraints(minHeight: 94),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF161226), const Color(0xFF0F172A)]
              : [const Color(0xFFF4EDFF), const Color(0xFFF8F5FF)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF31234F) : const Color(0xFFEDE7FF),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_add_alt_1_rounded,
              color: primary,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Create a new team',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF171B2E),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Invite members and collaborate together.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white60 : const Color(0xFF6C7391),
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
              color: primary,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
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
                          'Create',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
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
            const _SkeletonBox(size: 58),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _SkeletonLine(width: 140),
                  SizedBox(height: 10),
                  _SkeletonLine(width: 210),
                  SizedBox(height: 14),
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

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEDEFF7),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      height: 10,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEDEFF7),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return _CardShell(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          children: [
            Icon(icon, size: 42, color: primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF171B2E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white60 : const Color(0xFF6C7391),
              ),
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 16),
              _TinyActionButton(
                label: actionText!,
                color: primary,
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
  const _CardShell({required this.child, this.height, this.borderRadius = 18});

  final Widget child;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE8EAF4),
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.045),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _CardShell(
      height: 48,
      child: SizedBox(
        width: 48,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onPressed,
            child: Icon(
              icon,
              color: isDark ? Colors.white70 : const Color(0xFF68708C),
              size: 23,
            ),
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
          colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
        ),
        borderRadius: BorderRadius.circular(16),
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
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isDark ? Colors.white60 : const Color(0xFF69718D),
            ),
            const SizedBox(width: 5),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF24283B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white60 : const Color(0xFF6C7391),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = label.trim().isEmpty ? '?' : label.trim();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? const Color(0xFF111827) : Colors.white,
          width: 2,
        ),
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
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          color: primary,
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
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
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
  const _BottomSheetShell({
    required this.title,
    required this.child,
    this.maxHeightFactor,
  });

  final String title;
  final Widget child;
  final double? maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding + 16),
      child: ConstrainedBox(
        constraints: maxHeightFactor == null
            ? const BoxConstraints()
            : BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * maxHeightFactor!,
              ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF050816) : Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
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
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE6E8F2),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF171B2E),
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
    this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemColor = color ?? Theme.of(context).colorScheme.primary;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: itemColor),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: color ?? (isDark ? Colors.white : const Color(0xFF111827)),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: isDark ? Colors.white60 : const Color(0xFF64748B)),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
      ),
      onTap: onTap,
    );
  }
}

class _SheetTextField extends StatelessWidget {
  const _SheetTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return TextField(
      controller: controller,
      textInputAction: TextInputAction.done,
      onSubmitted: onSubmitted,
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF111827),
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, color: primary),
        filled: true,
        fillColor: isDark ? const Color(0xFF111827) : Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
      ),
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
    final primary = Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: 50,
      child: Material(
        color: onPressed == null ? const Color(0xFFC4B5FD) : primary,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: _CardShell(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: isDark ? Colors.white : const Color(0xFF171B2E),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: isDark ? Colors.white60 : const Color(0xFF6C7391),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetSectionHeader extends StatelessWidget {
  const _SheetSectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member});

  final TeamMemberModel member;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _InitialsAvatar(
        label: member.initials,
        color: _avatarColor(member.userId),
      ),
      title: Text(
        member.displayName,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: isDark ? Colors.white : const Color(0xFF111827),
        ),
      ),
      subtitle: Text(
        member.roleLabel,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white60 : const Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _ProjectMiniRow extends StatelessWidget {
  const _ProjectMiniRow({required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = switch (project.status) {
      'completed' => const Color(0xFF7C3AED),
      'in_progress' => const Color(0xFF22C55E),
      'on_hold' => const Color(0xFFF59E0B),
      'cancelled' => const Color(0xFFEF4444),
      _ => const Color(0xFF3B82F6),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.folder_rounded, color: statusColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  project.deadlineLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          _StatusPill(label: project.statusLabel, color: statusColor),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? Colors.white54 : const Color(0xFF6C7391),
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _TeamStats {
  final int memberCount;
  final int projectCount;
  final int taskCount;
  final int completedTaskCount;

  const _TeamStats({
    required this.memberCount,
    required this.projectCount,
    required this.taskCount,
    required this.completedTaskCount,
  });
}

Color _avatarColor(int seed) {
  const colors = [
    Color(0xFF7C3AED),
    Color(0xFF3B82F6),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF06B6D4),
  ];

  return colors[seed.abs() % colors.length];
}
