import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/auth/data/project_api.dart';
import 'package:mobile/features/auth/models/project_models.dart';
import 'package:mobile/features/projects/project_detail_screen.dart';
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
  String? _errorMessage;

  List<TeamModel> _teams = [];
  List<TeamInvitationModel> _invitations = [];
  final Map<int, List<TeamMemberModel>> _membersByTeamId = {};
  final Map<int, List<ProjectModel>> _projectsByTeamId = {};
  final Map<int, _TeamStats> _statsByTeamId = {};

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

  List<TeamInvitationModel> get _pendingInvitations {
    return _invitations.where((item) => item.isPending).toList();
  }

  List<TeamModel> get _visibleTeams {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _teams;
    }

    return _teams.where((team) {
      final members =
          _membersByTeamId[team.teamId] ?? const <TeamMemberModel>[];
      final projects = _projectsByTeamId[team.teamId] ?? const <ProjectModel>[];
      final stats = _statsByTeamId[team.teamId];

      return team.name.toLowerCase().contains(query) ||
          team.teamId.toString().contains(query) ||
          (stats?.taskCount.toString().contains(query) ?? false) ||
          members.any(
            (member) =>
                member.displayName.toLowerCase().contains(query) ||
                member.roleLabel.toLowerCase().contains(query) ||
                (member.user?.username ?? '').toLowerCase().contains(query) ||
                (member.user?.email ?? '').toLowerCase().contains(query),
          ) ||
          projects.any(
            (project) =>
                project.title.toLowerCase().contains(query) ||
                project.statusLabel.toLowerCase().contains(query) ||
                project.deadlineLabel.toLowerCase().contains(query),
          );
    }).toList();
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
        _membersByTeamId.clear();
        _projectsByTeamId.clear();
        _statsByTeamId.clear();
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
        _errorMessage = error is ApiException
            ? 'Could not load teams: ${error.message}'
            : 'Could not load teams. Pull down or tap retry.';
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
    final background = isDark
        ? const Color(0xFF0B0820)
        : const Color(0xFFFAFAFF);

    final content = RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: () => _loadTeams(showLoading: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(0, 0, 0, widget.showBackButton ? 28 : 112),
        children: [
          _TeamsHeader(
            showBackButton: widget.showBackButton,
            onBackPressed: () => Navigator.of(context).maybePop(),
            onCreatePressed: _openCreateTeamSheet,
          ),
          const SizedBox(height: 14),
          _SearchField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            onClear: _clearSearch,
          ),
          const SizedBox(height: 14),
          _TeamTabs(
            selectedIndex: _selectedTabIndex,
            invitationCount: _pendingInvitations.length,
            onChanged: (index) => setState(() => _selectedTabIndex = index),
          ),
          const SizedBox(height: 14),
          if (_selectedTabIndex == 0)
            ..._buildTeamContent()
          else
            _buildInvitationContent(),
        ],
      ),
    );

    if (!widget.showBackButton) {
      // The main tab shell already paints the page background. Returning the
      // content directly prevents a second dark panel from creating visible
      // left/right color bands around the Teams tab.
      return content;
    }

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
          child: content,
        ),
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  List<Widget> _buildTeamContent() {
    if (_isLoading && _teams.isEmpty) {
      return const [
        _TeamLoadingCard(),
        SizedBox(height: 12),
        _TeamLoadingCard(),
        SizedBox(height: 12),
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
              : 'Try another team, member, project, or role name.',
          actionText: _searchQuery.trim().isEmpty ? 'Create Team' : null,
          onAction: _searchQuery.trim().isEmpty ? _openCreateTeamSheet : null,
        ),
      ];
    }

    return [
      _SwipeHint(),
      const SizedBox(height: 10),
      for (final team in _visibleTeams) ...[
        _buildSlidableTeamCard(team),
        const SizedBox(height: 12),
      ],
    ];
  }

  Widget _buildSlidableTeamCard(TeamModel team) {
    return Slidable(
      key: ValueKey('team-${team.teamId}'),
      closeOnScroll: true,
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.28,
        dismissible: DismissiblePane(
          closeOnCancel: true,
          confirmDismiss: () async {
            final confirmed = await _confirmDeleteTeam(
              team,
              executeDelete: false,
            );
            if (confirmed == true) {
              await _deleteTeam(team);
            }
            return false;
          },
          onDismissed: () {},
        ),
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
          const SizedBox(height: 12),
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
              title: 'Create team',
              subtitle:
                  'Name the workspace where members, plans, and tasks live.',
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

    if (name.length < 2) {
      _showMessage('Team name must be at least 2 letters.');
      return;
    }

    if (isSubmitting) {
      return;
    }

    setSheetState(() => setSubmitting(true));

    var wasCreated = false;

    try {
      await widget.teamsApi.createTeam(name);
      wasCreated = true;
    } catch (error, stackTrace) {
      debugPrint('Create team failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage(
        _genericApiMessage(
          error,
          fallback: 'Could not create team. Try again.',
        ),
      );
    } finally {
      setSheetState(() => setSubmitting(false));
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
          subtitle: 'Choose what to do with this team.',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionTile(
                icon: Icons.info_outline_rounded,
                title: 'Team details',
                subtitle: 'Members, plans, and task activity',
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
                subtitle: 'Reload members, plans, and tasks',
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
      builder: (sheetContext) {
        return _BottomSheetShell(
          title: team.name,
          subtitle: currentMember == null
              ? 'Team workspace'
              : 'Your role: ${currentMember.roleLabel}',
          maxHeightFactor: 0.88,
          child: Expanded(
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
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _SheetStat(
                        label: 'Members',
                        value: '${stats?.memberCount ?? members.length}',
                      ),
                      const SizedBox(width: 9),
                      _SheetStat(
                        label: 'Plans',
                        value: '${stats?.projectCount ?? projects.length}',
                      ),
                      const SizedBox(width: 9),
                      _SheetStat(
                        label: 'Tasks',
                        value: '${stats?.taskCount ?? 0}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SheetSectionHeader(
                    title: 'Members',
                    actionLabel: 'Invite',
                    onAction: () {
                      Navigator.of(sheetContext).pop();
                      _openInviteMemberSheet(team);
                    },
                  ),
                  const SizedBox(height: 9),
                  if (members.isEmpty)
                    const _SmallMutedText('Members are loading or unavailable.')
                  else
                    for (final member in members) _MemberRow(member: member),
                  const SizedBox(height: 16),
                  const _SheetSectionHeader(title: 'Team plans'),
                  const SizedBox(height: 9),
                  if (projects.isEmpty)
                    const _SmallMutedText('No team plans yet.')
                  else
                    for (final project in projects.take(8))
                      _ProjectMiniRow(
                        project: project,
                        onTap: () async {
                          Navigator.of(sheetContext).pop();
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ProjectDetailScreen(project: project),
                            ),
                          );
                          if (mounted) {
                            _loadTeams(showLoading: false);
                          }
                        },
                      ),
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
              subtitle: 'Send an invitation by Planora username.',
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

                            setSheetState(() => isSubmitting = true);
                            var wasSent = false;

                            try {
                              await widget.teamsApi.inviteUser(
                                teamId: team.teamId,
                                username: username,
                              );
                            