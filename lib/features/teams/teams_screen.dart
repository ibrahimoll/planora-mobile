import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/planora_theme.dart';
import '../auth/data/project_api.dart';
import '../auth/models/project_models.dart';
import '../projects/project_detail_screen.dart';
import '../tasks/data/tasks_api.dart';
import '../tasks/models/task_models.dart';
import 'data/teams_api.dart';

class TeamsScreen extends StatefulWidget {
  final TeamsApi teamsApi;
  final ProjectsApi projectsApi;
  final TasksApi tasksApi;
  final bool showBackButton;
  final bool openInvitations;
  final VoidCallback? onTeamsChanged;
  final int? currentUserId;

  const TeamsScreen({
    super.key,
    this.teamsApi = const TeamsApi(),
    this.projectsApi = const ProjectsApi(),
    this.tasksApi = const TasksApi(),
    this.showBackButton = false,
    this.openInvitations = false,
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
    _selectedTabIndex = widget.openInvitations ? 1 : 0;
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

  int get _totalMembers {
    return _statsByTeamId.values.fold<int>(0, (sum, item) => sum + item.memberCount);
  }

  int get _totalProjects {
    return _statsByTeamId.values.fold<int>(0, (sum, item) => sum + item.projectCount);
  }

  int get _totalTasks {
    return _statsByTeamId.values.fold<int>(0, (sum, item) => sum + item.taskCount);
  }

  int get _completedTasks {
    return _statsByTeamId.values.fold<int>(0, (sum, item) => sum + item.completedTaskCount);
  }

  double get _teamCompletion {
    if (_totalTasks == 0) return 0;
    return (_completedTasks / _totalTasks).clamp(0.0, 1.0);
  }

  List<TeamModel> get _visibleTeams {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _teams;

    return _teams.where((team) {
      final members = _membersByTeamId[team.teamId] ?? const <TeamMemberModel>[];
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
      if (!mounted) return;

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
      if (!mounted) return;

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
            completedTaskCount += tasks.where((item) => item.task.isCompleted).length;
          } catch (error, stackTrace) {
            debugPrint(
              'Team task load failed for team ${team.teamId}, project ${project.projectId}: $error',
            );
            debugPrintStack(stackTrace: stackTrace);
          }
        }

        if (!mounted) return;

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
        if (!mounted) return;

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
    final content = RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: () => _loadTeams(showLoading: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.fromLTRB(0, 0, 0, widget.showBackButton ? 28 : 112),
        children: [
          _AnimatedEntrance(
            index: 0,
            child: _TeamsHero(
              showBackButton: widget.showBackButton,
              onBackPressed: () => Navigator.of(context).maybePop(),
              onCreatePressed: _openCreateTeamSheet,
              teamCount: _teams.length,
              memberCount: _totalMembers,
              projectCount: _totalProjects,
              taskCount: _totalTasks,
              pendingInviteCount: _pendingInvitations.length,
              completion: _teamCompletion,
            ),
          ),
          const SizedBox(height: 14),
          _AnimatedEntrance(
            index: 1,
            child: _SearchField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              onClear: _clearSearch,
            ),
          ),
          const SizedBox(height: 14),
          _AnimatedEntrance(
            index: 2,
            child: _TeamTabs(
              selectedIndex: _selectedTabIndex,
              invitationCount: _pendingInvitations.length,
              onChanged: (index) => setState(() => _selectedTabIndex = index),
            ),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _selectedTabIndex == 0
                ? Column(
                    key: const ValueKey('teams-list'),
                    children: _buildTeamContent(),
                  )
                : Column(
                    key: const ValueKey('invitations-list'),
                    children: [_buildInvitationContent()],
                  ),
          ),
        ],
      ),
    );

    if (!widget.showBackButton) {
      return Material(type: MaterialType.transparency, child: content);
    }

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: PlanoraTheme.onboardingBackgroundFor(context)),
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: content,
              ),
            ),
          ),
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
          title: _searchQuery.trim().isEmpty ? 'No teams yet' : 'No teams found',
          message: _searchQuery.trim().isEmpty
              ? 'Create your first team and manage members, plans, and tasks from one workspace.'
              : 'Try another team, member, project, or role name.',
          actionText: _searchQuery.trim().isEmpty ? 'Create Team' : null,
          onAction: _searchQuery.trim().isEmpty ? _openCreateTeamSheet : null,
        ),
      ];
    }

    return [
      const _SwipeHint(),
      const SizedBox(height: 10),
      for (int index = 0; index < _visibleTeams.length; index++) ...[
        _AnimatedEntrance(index: index + 3, child: _buildSlidableTeamCard(_visibleTeams[index])),
        const SizedBox(height: 12),
      ],
    ];
  }

  Widget _buildSlidableTeamCard(TeamModel team) {
    final currentMember = _currentMemberForTeam(team);
    final canManage = _canManageTeam(team);
    final canDelete = _canDeleteTeam(team);

    return Slidable(
      key: ValueKey('team-${team.teamId}'),
      closeOnScroll: true,
      startActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: canManage ? 0.56 : 0.28,
        children: [
          SlidableAction(
            onPressed: (_) => _openTeamDetailsSheet(team),
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            icon: Icons.visibility_outlined,
            label: 'Open',
            borderRadius: BorderRadius.circular(18),
          ),
          if (canManage)
            SlidableAction(
              onPressed: (_) => _openInviteMemberSheet(team),
              backgroundColor: const Color(0xFF06B6D4),
              foregroundColor: Colors.white,
              icon: Icons.person_add_alt_1_rounded,
              label: 'Invite',
              borderRadius: BorderRadius.circular(18),
            ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: canDelete ? 0.56 : 0.28,
        children: [
          if (canManage)
            SlidableAction(
              onPressed: (_) => _openRenameTeamSheet(team),
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              icon: Icons.edit_outlined,
              label: 'Edit',
              borderRadius: BorderRadius.circular(18),
            ),
          if (canDelete)
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
        projects: _projectsByTeamId[team.teamId] ?? const [],
        stats: _statsByTeamId[team.teamId],
        currentMember: currentMember,
        canManage: canManage,
        onTap: () => _openTeamDetailsSheet(team),
        onInvitePressed: canManage ? () => _openInviteMemberSheet(team) : null,
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
        for (int index = 0; index < _pendingInvitations.length; index++) ...[
          _AnimatedEntrance(
            index: index,
            child: _InvitationCard(
              invitation: _pendingInvitations[index],
              onAccept: () => _respondToInvitation(_pendingInvitations[index], accept: true),
              onReject: () => _respondToInvitation(_pendingInvitations[index], accept: false),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Future<void> _openCreateTeamSheet() async {
    await _openTeamNameSheet(
      title: 'Create team',
      subtitle: 'Name the workspace where members, plans, and tasks live.',
      initialName: '',
      buttonLabel: 'Create Team',
      loadingLabel: 'Creating...',
      onSubmit: (name) async {
        await widget.teamsApi.createTeam(name);
        _showMessage('Team created.');
      },
    );
  }

  Future<void> _openRenameTeamSheet(TeamModel team) async {
    await _openTeamNameSheet(
      title: 'Rename team',
      subtitle: 'Keep the name clear for members and projects.',
      initialName: team.name,
      buttonLabel: 'Save Changes',
      loadingLabel: 'Saving...',
      onSubmit: (name) async {
        await widget.teamsApi.updateTeam(teamId: team.teamId, name: name);
        _showMessage('Team updated.');
      },
    );
  }

  Future<void> _openTeamNameSheet({
    required String title,
    required String subtitle,
    required String initialName,
    required String buttonLabel,
    required String loadingLabel,
    required Future<void> Function(String name) onSubmit,
  }) async {
    final controller = TextEditingController(text: initialName);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submit() async {
              final name = controller.text.trim();
              if (name.length < 2) {
                _showMessage('Team name must be at least 2 letters.');
                return;
              }
              if (isSubmitting) return;

              setSheetState(() => isSubmitting = true);
              var success = false;
              try {
                await onSubmit(name);
                success = true;
              } catch (error, stackTrace) {
                debugPrint('Team name submit failed: $error');
                debugPrintStack(stackTrace: stackTrace);
                _showMessage(_genericApiMessage(error, fallback: 'Could not save team.'));
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => isSubmitting = false);
                }
              }

              if (!success || !mounted || !sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
              widget.onTeamsChanged?.call();
              await _loadTeams(showLoading: false);
            }

            return _BottomSheetShell(
              title: title,
              subtitle: subtitle,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SheetTextField(
                    controller: controller,
                    label: 'Team name',
                    hintText: 'Example: Product Team',
                    icon: Icons.groups_2_outlined,
                    onSubmitted: (_) => submit(),
                  ),
                  const SizedBox(height: 16),
                  _PrimarySheetButton(
                    label: isSubmitting ? loadingLabel : buttonLabel,
                    isLoading: isSubmitting,
                    onPressed: isSubmitting ? null : submit,
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

  Future<void> _openTeamActionsSheet(TeamModel team) async {
    final currentMember = _currentMemberForTeam(team);
    final canManage = _canManageTeam(team);
    final canDelete = _canDeleteTeam(team);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _BottomSheetShell(
          title: team.name,
          subtitle: currentMember == null ? 'Team workspace' : 'Your role: ${currentMember.roleLabel}',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionTile(
                icon: Icons.dashboard_customize_outlined,
                title: 'Team details',
                subtitle: 'Members, plans, roles, and progress',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openTeamDetailsSheet(team);
                },
              ),
              if (canManage) ...[
                _ActionTile(
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'Invite member',
                  subtitle: 'Send an invitation by username',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openInviteMemberSheet(team);
                  },
                ),
                _ActionTile(
                  icon: Icons.edit_outlined,
                  title: 'Rename team',
                  subtitle: 'Update the team workspace name',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openRenameTeamSheet(team);
                  },
                ),
              ],
              _ActionTile(
                icon: Icons.refresh_rounded,
                title: 'Refresh team',
                subtitle: 'Reload members, plans, and task stats',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _loadTeams(showLoading: false);
                },
              ),
              if (canDelete)
                _ActionTile(
                  icon: Icons.delete_outline_rounded,
                  title: 'Delete team',
                  subtitle: 'Only the owner can delete this team',
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
    final currentMember = _currentMemberForTeam(team);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final members = _membersByTeamId[team.teamId] ?? const <TeamMemberModel>[];
            final projects = _projectsByTeamId[team.teamId] ?? const <ProjectModel>[];
            final stats = _statsByTeamId[team.teamId];
            final canManage = _canManageTeam(team);
            final canEditRoles = _canEditMemberRoles(team);

            return _BottomSheetShell(
              title: team.name,
              subtitle: currentMember == null ? 'Team workspace' : 'Your role: ${currentMember.roleLabel}',
              maxHeightFactor: 0.90,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TeamOverviewPanel(team: team, currentMember: currentMember, stats: stats),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _SheetStat(label: 'Members', value: '${stats?.memberCount ?? members.length}'),
                        const SizedBox(width: 9),
                        _SheetStat(label: 'Plans', value: '${stats?.projectCount ?? projects.length}'),
                        const SizedBox(width: 9),
                        _SheetStat(label: 'Tasks', value: '${stats?.taskCount ?? 0}'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _SheetSectionHeader(
                      title: 'Members',
                      actionLabel: canManage ? 'Invite' : null,
                      onAction: canManage
                          ? () {
                              Navigator.of(sheetContext).pop();
                              _openInviteMemberSheet(team);
                            }
                          : null,
                    ),
                    const SizedBox(height: 9),
                    if (members.isEmpty)
                      const _SmallMutedText('Members are loading or unavailable.')
                    else
                      for (final member in members)
                        _MemberRow(
                          member: member,
                          canManage: canManage,
                          canEditRole: canEditRoles && member.role != 'owner' && member.userId != widget.currentUserId,
                          canRemove: canManage && member.role != 'owner' && member.userId != widget.currentUserId,
                          onChangeRole: () => _openChangeRoleSheet(team: team, member: member, parentContext: sheetContext),
                          onRemove: () => _confirmRemoveMember(team: team, member: member),
                        ),
                    const SizedBox(height: 16),
                    const _SheetSectionHeader(title: 'Team plans'),
                    const SizedBox(height: 9),
                    if (projects.isEmpty)
                      const _SmallMutedText('No team plans yet.')
                    else
                      for (final project in projects.take(10))
                        _ProjectMiniRow(
                          project: project,
                          onTap: () async {
                            Navigator.of(sheetContext).pop();
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ProjectDetailScreen(
                                  project: project,
                                  onProjectChanged: () => _loadTeams(showLoading: false),
                                ),
                              ),
                            );
                            if (mounted) _loadTeams(showLoading: false);
                          },
                        ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openInviteMemberSheet(TeamModel team) async {
    final usernameController = TextEditingController();
    var selectedRole = 'member';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submit() async {
              final username = usernameController.text.trim();
              if (username.length < 3) {
                _showMessage('Enter a valid username first.');
                return;
              }
              if (isSubmitting) return;

              setSheetState(() => isSubmitting = true);
              var success = false;
              try {
                await widget.teamsApi.inviteUser(
                  teamId: team.teamId,
                  username: username,
                  role: selectedRole,
                );
                success = true;
              } catch (error, stackTrace) {
                debugPrint('Invite member failed: $error');
                debugPrintStack(stackTrace: stackTrace);
                _showMessage(_genericApiMessage(error, fallback: 'Could not send invitation.'));
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => isSubmitting = false);
                }
              }

              if (!success || !mounted || !sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
              _showMessage('Invitation sent.');
              await _loadTeams(showLoading: false);
            }

            return _BottomSheetShell(
              title: 'Invite to ${team.name}',
              subtitle: 'Send an invitation by username and choose a role.',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SheetTextField(
                    controller: usernameController,
                    label: 'Username',
                    hintText: 'Enter username',
                    icon: Icons.alternate_email_rounded,
                    onSubmitted: (_) => submit(),
                  ),
                  const SizedBox(height: 14),
                  _RolePicker(
                    selectedRole: selectedRole,
                    onChanged: (role) => setSheetState(() => selectedRole = role),
                  ),
                  const SizedBox(height: 16),
                  _PrimarySheetButton(
                    label: isSubmitting ? 'Sending...' : 'Send Invite',
                    isLoading: isSubmitting,
                    onPressed: isSubmitting ? null : submit,
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    usernameController.dispose();
  }

  Future<void> _openChangeRoleSheet({
    required TeamModel team,
    required TeamMemberModel member,
    required BuildContext parentContext,
  }) async {
    var selectedRole = member.role == 'admin' ? 'admin' : 'member';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submit() async {
              if (isSubmitting) return;
              setSheetState(() => isSubmitting = true);
              var success = false;
              try {
                await widget.teamsApi.updateMemberRole(
                  teamId: team.teamId,
                  userId: member.userId,
                  role: selectedRole,
                );
                success = true;
              } catch (error, stackTrace) {
                debugPrint('Change role failed: $error');
                debugPrintStack(stackTrace: stackTrace);
                _showMessage(_genericApiMessage(error, fallback: 'Could not update role.'));
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => isSubmitting = false);
                }
              }

              if (!success || !mounted || !sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
              if (parentContext.mounted) Navigator.of(parentContext).pop();
              _showMessage('Member role updated.');
              await _loadTeams(showLoading: false);
              if (mounted) _openTeamDetailsSheet(team);
            }

            return _BottomSheetShell(
              title: 'Change role',
              subtitle: 'Update ${member.displayName} permissions.',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MemberPreview(member: member),
                  const SizedBox(height: 14),
                  _RolePicker(
                    selectedRole: selectedRole,
                    onChanged: (role) => setSheetState(() => selectedRole = role),
                  ),
                  const SizedBox(height: 16),
                  _PrimarySheetButton(
                    label: isSubmitting ? 'Saving...' : 'Save Role',
                    isLoading: isSubmitting,
                    onPressed: isSubmitting ? null : submit,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<bool?> _confirmDeleteTeam(TeamModel team, {bool executeDelete = true}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF14122A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text('Delete team?'),
          content: Text(
            'This will remove "${team.name}" if your account has permission. Team plans may also be affected.',
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

    if (confirmed == true && executeDelete) {
      await _deleteTeam(team);
    }
    return confirmed;
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
      if (!mounted) return;
      _showMessage('Team deleted.');
      widget.onTeamsChanged?.call();
    } catch (error, stackTrace) {
      debugPrint('Delete team failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;

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

  Future<void> _confirmRemoveMember({
    required TeamModel team,
    required TeamMemberModel member,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF14122A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text('Remove member?'),
          content: Text('Remove ${member.displayName} from ${team.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await widget.teamsApi.removeMember(teamId: team.teamId, userId: member.userId);
      if (!mounted) return;
      _showMessage('Member removed.');
      await _loadTeams(showLoading: false);
    } catch (error, stackTrace) {
      debugPrint('Remove member failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage(_genericApiMessage(error, fallback: 'Could not remove member.'));
    }
  }

  Future<void> _respondToInvitation(TeamInvitationModel invitation, {required bool accept}) async {
    try {
      if (accept) {
        await widget.teamsApi.acceptInvitation(invitation.invitationId);
      } else {
        await widget.teamsApi.rejectInvitation(invitation.invitationId);
      }

      if (!mounted) return;
      _showMessage(accept ? 'Invitation accepted.' : 'Invitation rejected.');
      widget.onTeamsChanged?.call();
      await _loadTeams(showLoading: false);
    } catch (error, stackTrace) {
      debugPrint('Invitation response failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage(_genericApiMessage(error, fallback: 'Could not update invitation.'));
    }
  }

  TeamMemberModel? _currentMemberForTeam(TeamModel team) {
    final id = widget.currentUserId;
    if (id == null) return null;

    final members = _membersByTeamId[team.teamId] ?? const <TeamMemberModel>[];
    for (final member in members) {
      if (member.userId == id) return member;
    }
    return null;
  }

  bool _canManageTeam(TeamModel team) {
    final role = _currentMemberForTeam(team)?.role;
    return role == 'owner' || role == 'admin';
  }

  bool _canEditMemberRoles(TeamModel team) {
    return _currentMemberForTeam(team)?.role == 'owner';
  }

  bool _canDeleteTeam(TeamModel team) {
    return _currentMemberForTeam(team)?.role == 'owner';
  }

  String _teamDeleteErrorMessage(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 403) {
        return 'Only team owners can delete this team.';
      }
      final message = error.message.trim();
      if (message.isNotEmpty && message != 'Something went wrong. Please try again.') {
        return message;
      }
    }
    return 'Could not delete team. Try again.';
  }

  String _genericApiMessage(Object error, {required String fallback}) {
    if (error is ApiException) {
      final message = error.message.trim();
      if (message.isNotEmpty && message != 'Something went wrong. Please try again.') {
        return message;
      }
    }
    return fallback;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
  }
}

class _AnimatedEntrance extends StatelessWidget {
  const _AnimatedEntrance({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + (index * 55).clamp(0, 320)),
      curve: Curves.easeOutCubic,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: Transform.scale(
              scale: 0.97 + (value * 0.03),
              child: animatedChild,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class _TeamsHero extends StatelessWidget {
  const _TeamsHero({
    required this.showBackButton,
    required this.onBackPressed,
    required this.onCreatePressed,
    required this.teamCount,
    required this.memberCount,
    required this.projectCount,
    required this.taskCount,
    required this.pendingInviteCount,
    required this.completion,
  });

  final bool showBackButton;
  final VoidCallback onBackPressed;
  final VoidCallback onCreatePressed;
  final int teamCount;
  final int memberCount;
  final int projectCount;
  final int taskCount;
  final int pendingInviteCount;
  final double completion;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF17112F), const Color(0xFF0B0820)]
              : [Colors.white, const Color(0xFFF5F0FF)],
        ),
        border: Border.all(color: primary.withValues(alpha: isDark ? 0.20 : 0.12)),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: isDark ? 0.18 : 0.12),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showBackButton) ...[
                _CircleIconButton(icon: Icons.arrow_back_rounded, onPressed: onBackPressed),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(Icons.groups_2_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Teams',
                            style: TextStyle(
                              fontSize: 28,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF141724),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Collaborate, assign roles, invite members, and track team plans.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white60 : const Color(0xFF6C7391),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _GradientIconButton(icon: Icons.add_rounded, onPressed: onCreatePressed),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: completion),
                duration: const Duration(milliseconds: 850),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return SizedBox(
                    width: 86,
                    height: 86,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: value,
                          strokeWidth: 8,
                          strokeCap: StrokeCap.round,
                          backgroundColor: primary.withValues(alpha: 0.12),
                          color: primary,
                        ),
                        Text(
                          '${(value * 100).round()}%',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeroChip(icon: Icons.groups_outlined, label: 'Teams', value: teamCount),
                    _HeroChip(icon: Icons.person_outline_rounded, label: 'Members', value: memberCount),
                    _HeroChip(icon: Icons.folder_copy_outlined, label: 'Plans', value: projectCount),
                    _HeroChip(icon: Icons.check_box_outlined, label: 'Tasks', value: taskCount),
                    if (pendingInviteCount > 0)
                      _HeroChip(icon: Icons.mail_outline_rounded, label: 'Invites', value: pendingInviteCount),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged, required this.onClear});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white60 : const Color(0xFF8A91AA);

    return _CardShell(
      height: 54,
      borderRadius: 18,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        cursorColor: Theme.of(context).colorScheme.primary,
        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827), fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          hintText: 'Search teams, members, plans, roles...',
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : const Color(0xFF98A0B8),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: iconColor, size: 22),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              if (value.text.trim().isEmpty) return const SizedBox.shrink();
              return IconButton(
                onPressed: onClear,
                icon: Icon(Icons.close_rounded, color: iconColor, size: 20),
              );
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
      ),
    );
  }
}

class _TeamTabs extends StatelessWidget {
  const _TeamTabs({required this.selectedIndex, required this.invitationCount, required this.onChanged});

  final int selectedIndex;
  final int invitationCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14122A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF312A56) : const Color(0xFFE7E9F2)),
      ),
      child: Row(
        children: [
          _TabButton(label: 'My Teams', selected: selectedIndex == 0, onTap: () => onChanged(0)),
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
  const _TabButton({required this.label, required this.selected, required this.onTap, this.badge});

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
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? primary.withValues(alpha: isDark ? 0.26 : 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
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
                    color: selected ? primary : (isDark ? Colors.white70 : const Color(0xFF6C7391)),
                  ),
                ),
              ),
              if (badge != null && badge! > 0) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: primary.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                  child: Text('$badge', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: primary)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(Icons.swipe_rounded, size: 16, color: isDark ? Colors.white38 : const Color(0xFF8A91AA)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Swipe for quick actions. Tap a team to manage members and plans.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: isDark ? Colors.white38 : const Color(0xFF8A91AA)),
          ),
        ),
      ],
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.team,
    required this.members,
    required this.projects,
    required this.stats,
    required this.currentMember,
    required this.canManage,
    required this.onTap,
    required this.onMenuPressed,
    this.onInvitePressed,
  });

  final TeamModel team;
  final List<TeamMemberModel> members;
  final List<ProjectModel> projects;
  final _TeamStats? stats;
  final TeamMemberModel? currentMember;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback onMenuPressed;
  final VoidCallback? onInvitePressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final memberCount = stats?.memberCount ?? members.length;
    final projectCount = stats?.projectCount ?? projects.length;
    final taskCount = stats?.taskCount ?? 0;
    final doneCount = stats?.completedTaskCount ?? 0;
    final completion = taskCount == 0 ? 0.0 : doneCount / taskCount;
    final previewMembers = members.take(4).toList();
    final activeProjects = projects.where((item) => item.isActive).length;

    return _CardShell(
      borderRadius: 26,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 15, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primary.withValues(alpha: 0.95), const Color(0xFF06B6D4)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.22),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(_teamIcon(team.name), color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
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
                                    height: 1.1,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : const Color(0xFF171B2E),
                                  ),
                                ),
                              ),
                              if (currentMember != null) ...[
                                const SizedBox(width: 7),
                                _RoleBadge(label: currentMember!.roleLabel),
                              ],
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '$activeProjects active plans • ${(completion * 100).round()}% tasks complete',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white54 : const Color(0xFF6C7391),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                      onPressed: onMenuPressed,
                      icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white54 : const Color(0xFF626B87), size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: completion.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 6,
                        backgroundColor: isDark ? const Color(0xFF2C2845) : const Color(0xFFE9EBF4),
                        valueColor: AlwaysStoppedAnimation<Color>(primary),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    _AvatarStack(
                      members: previewMembers,
                      extraCount: memberCount > previewMembers.length ? memberCount - previewMembers.length : 0,
                    ),
                    const Spacer(),
                    _MiniStat(icon: Icons.group_outlined, value: memberCount, label: 'Members'),
                    const SizedBox(width: 13),
                    _MiniStat(icon: Icons.folder_copy_outlined, value: projectCount, label: 'Plans'),
                    const SizedBox(width: 13),
                    _MiniStat(icon: Icons.check_box_outlined, value: taskCount, label: 'Tasks'),
                  ],
                ),
                if (canManage) ...[
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      Expanded(
                        child: _InlineActionButton(
                          icon: Icons.person_add_alt_1_rounded,
                          label: 'Invite member',
                          onTap: onInvitePressed,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InlineActionButton(
                          icon: Icons.dashboard_customize_outlined,
                          label: 'Manage team',
                          onTap: onTap,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamOverviewPanel extends StatelessWidget {
  const _TeamOverviewPanel({required this.team, required this.currentMember, required this.stats});

  final TeamModel team;
  final TeamMemberModel? currentMember;
  final _TeamStats? stats;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final taskCount = stats?.taskCount ?? 0;
    final completion = taskCount == 0 ? 0.0 : (stats?.completedTaskCount ?? 0) / taskCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary.withValues(alpha: isDark ? 0.30 : 0.13), const Color(0xFF06B6D4).withValues(alpha: isDark ? 0.16 : 0.07)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primary, const Color(0xFF06B6D4)]),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(_teamIcon(team.name), color: Colors.white),
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
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: isDark ? Colors.white : const Color(0xFF111827)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentMember == null ? 'Team workspace' : 'Your role: ${currentMember!.roleLabel}',
                      style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: completion.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: isDark ? const Color(0xFF2C2845) : Colors.white,
                  valueColor: AlwaysStoppedAnimation<Color>(primary),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            '${(completion * 100).round()}% team tasks completed',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF4B5563)),
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
    const double size = 26;
    const double overlap = 17;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (members.isEmpty) {
      return Text(
        'No members loaded',
        style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : const Color(0xFF8A91AA), fontWeight: FontWeight.w700),
      );
    }

    final width = (members.length * overlap) + (extraCount > 0 ? 32 : 12);

    return SizedBox(
      height: size,
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int index = 0; index < members.length; index++)
            Positioned(
              left: index * overlap,
              child: _InitialsAvatar(label: members[index].initials, color: _avatarColor(members[index].userId), size: size),
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
                  border: Border.all(color: isDark ? const Color(0xFF14122A) : Colors.white, width: 2),
                ),
                child: Text(
                  '+$extraCount',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 9, fontWeight: FontWeight.w900),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({required this.invitation, required this.onAccept, required this.onReject});

  final TeamInvitationModel invitation;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    return _CardShell(
      borderRadius: 24,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                  child: Icon(Icons.mail_outline_rounded, color: primary),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Team #${invitation.teamId}',
                        style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF171B2E)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Invited as ${_roleLabel(invitation.role)}',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF6C7391), fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _OutlineActionButton(label: 'Reject', color: const Color(0xFFEF4444), onTap: onReject)),
                const SizedBox(width: 10),
                Expanded(child: _FilledActionButton(label: 'Accept', color: primary, onTap: onAccept)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamLoadingCard extends StatelessWidget {
  const _TeamLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const _CardShell(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            _SkeletonBox(size: 52),
            SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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

class _StateCard extends StatelessWidget {
  const _StateCard({required this.icon, required this.title, required this.message, this.actionText, this.onAction});

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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(color: primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(22)),
              child: Icon(icon, size: 34, color: primary),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF171B2E)),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white60 : const Color(0xFF6C7391)),
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 16),
              _FilledActionButton(label: actionText!, color: primary, onTap: onAction!),
            ],
          ],
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, this.height, this.borderRadius = 20});

  final Widget child;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14122A) : Colors.white,
        border: Border.all(color: isDark ? const Color(0xFF312A56) : const Color(0xFFE8EAF4)),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.045),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _CardShell(
      height: 46,
      borderRadius: 16,
      child: SizedBox(
        width: 46,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Icon(icon, color: isDark ? Colors.white70 : const Color(0xFF68708C), size: 23),
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
        gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFF7C3AED).withValues(alpha: 0.28), blurRadius: 20, offset: const Offset(0, 10)),
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

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: isDark ? Colors.white54 : const Color(0xFF69718D)),
        const SizedBox(width: 4),
        Text('$value', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF24283B))),
      ],
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.label, required this.color, this.size = 34});

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
        border: Border.all(color: isDark ? const Color(0xFF14122A) : Colors.white, width: 2),
      ),
      child: Text(
        text.length > 2 ? text.substring(0, 2).toUpperCase() : text.toUpperCase(),
        style: TextStyle(color: Colors.white, fontSize: size <= 26 ? 9 : 12, fontWeight: FontWeight.w900),
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
      decoration: BoxDecoration(color: primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: primary)),
    );
  }
}

class _InlineActionButton extends StatelessWidget {
  const _InlineActionButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: primary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilledActionButton extends StatelessWidget {
  const _FilledActionButton({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  const _OutlineActionButton({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}

class _BottomSheetShell extends StatelessWidget {
  const _BottomSheetShell({required this.title, required this.child, this.subtitle, this.maxHeightFactor});

  final String title;
  final String? subtitle;
  final Widget child;
  final double? maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding + 16),
      child: FractionallySizedBox(
        heightFactor: maxHeightFactor,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0B0820) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.24), blurRadius: 32, offset: const Offset(0, 14))],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  mainAxisSize: maxHeightFactor == null ? MainAxisSize.min : MainAxisSize.max,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : const Color(0xFFE6E8F2), borderRadius: BorderRadius.circular(99)),
                    ),
                    const SizedBox(height: 15),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF171B2E)),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          subtitle!,
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (maxHeightFactor == null) child else Expanded(child: child),
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.color});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemColor = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14122A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF312A56) : const Color(0xFFE5E7EB)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: itemColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)),
          child: Icon(icon, color: itemColor, size: 20),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: color ?? (isDark ? Colors.white : const Color(0xFF111827)))),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF64748B))),
        trailing: Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
        onTap: onTap,
      ),
    );
  }
}

class _SheetTextField extends StatelessWidget {
  const _SheetTextField({required this.controller, required this.label, required this.hintText, required this.icon, this.onSubmitted});

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
      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827), fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, color: primary),
        filled: true,
        fillColor: isDark ? const Color(0xFF14122A) : Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: isDark ? const Color(0xFF312A56) : const Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
      ),
    );
  }
}

class _PrimarySheetButton extends StatelessWidget {
  const _PrimarySheetButton({required this.label, required this.isLoading, required this.onPressed});

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
      ),
    );
  }
}

class _RolePicker extends StatelessWidget {
  const _RolePicker({required this.selectedRole, required this.onChanged});

  final String selectedRole;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RoleChoice(
            label: 'Member',
            description: 'Can collaborate',
            selected: selectedRole == 'member',
            onTap: () => onChanged('member'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _RoleChoice(
            label: 'Admin',
            description: 'Can manage',
            selected: selectedRole == 'admin',
            onTap: () => onChanged('admin'),
          ),
        ),
      ],
    );
  }
}

class _RoleChoice extends StatelessWidget {
  const _RoleChoice({required this.label, required this.description, required this.selected, required this.onTap});

  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? primary.withValues(alpha: 0.12) : (isDark ? const Color(0xFF14122A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? primary : (isDark ? const Color(0xFF312A56) : const Color(0xFFE5E7EB))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, size: 18, color: selected ? primary : (isDark ? Colors.white38 : const Color(0xFF94A3B8))),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(fontWeight: FontWeight.w900, color: selected ? primary : (isDark ? Colors.white : const Color(0xFF111827)))),
              ],
            ),
            const SizedBox(height: 4),
            Text(description, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white54 : const Color(0xFF64748B))),
          ],
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF14122A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? const Color(0xFF312A56) : const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF111827))),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? Colors.white54 : const Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }
}

class _SheetSectionHeader extends StatelessWidget {
  const _SheetSectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900))),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!, style: TextStyle(color: primary, fontWeight: FontWeight.w900)),
          ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.canManage,
    required this.canEditRole,
    required this.canRemove,
    required this.onChangeRole,
    required this.onRemove,
  });

  final TeamMemberModel member;
  final bool canManage;
  final bool canEditRole;
  final bool canRemove;
  final VoidCallback onChangeRole;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14122A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDark ? const Color(0xFF312A56) : const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          _InitialsAvatar(label: member.initials, color: _avatarColor(member.userId), size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF111827)),
                ),
                const SizedBox(height: 2),
                Text(
                  member.user?.username ?? 'User #${member.userId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          _RoleBadge(label: member.roleLabel),
          if (canEditRole || canRemove) ...[
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              tooltip: 'Member actions',
              icon: Icon(Icons.more_vert_rounded, size: 20, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
              onSelected: (value) {
                if (value == 'role') onChangeRole();
                if (value == 'remove') onRemove();
              },
              itemBuilder: (context) => [
                if (canEditRole) const PopupMenuItem(value: 'role', child: Text('Change role')),
                if (canRemove) const PopupMenuItem(value: 'remove', child: Text('Remove member')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MemberPreview extends StatelessWidget {
  const _MemberPreview({required this.member});

  final TeamMemberModel member;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14122A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF312A56) : const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          _InitialsAvatar(label: member.initials, color: _avatarColor(member.userId), size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.displayName, style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF111827))),
                const SizedBox(height: 2),
                Text(member.roleLabel, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectMiniRow extends StatelessWidget {
  const _ProjectMiniRow({required this.project, this.onTap});

  final ProjectModel project;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF14122A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isDark ? const Color(0xFF312A56) : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)),
              child: Icon(Icons.folder_rounded, size: 21, color: primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF111827)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${project.statusLabel} • ${project.deadlineLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
          ],
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
    return Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white54 : const Color(0xFF64748B)));
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
      decoration: BoxDecoration(color: isDark ? const Color(0xFF231D3E) : const Color(0xFFEDEFF7), borderRadius: BorderRadius.circular(16)),
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
      decoration: BoxDecoration(color: isDark ? const Color(0xFF231D3E) : const Color(0xFFEDEFF7), borderRadius: BorderRadius.circular(99)),
    );
  }
}

@immutable
class _TeamStats {
  final int memberCount;
  final int projectCount;
  final int taskCount;
  final int completedTaskCount;

  const _TeamStats({required this.memberCount, required this.projectCount, required this.taskCount, required this.completedTaskCount});
}

IconData _teamIcon(String name) {
  final normalized = name.toLowerCase();
  if (normalized.contains('design') || normalized.contains('ui') || normalized.contains('ux')) return Icons.design_services_outlined;
  if (normalized.contains('dev') || normalized.contains('code') || normalized.contains('tech')) return Icons.code_rounded;
  if (normalized.contains('qa') || normalized.contains('test')) return Icons.fact_check_outlined;
  if (normalized.contains('market')) return Icons.campaign_outlined;
  if (normalized.contains('admin') || normalized.contains('ops')) return Icons.admin_panel_settings_outlined;
  return Icons.groups_2_rounded;
}

String _roleLabel(String role) {
  switch (role) {
    case 'owner':
      return 'Owner';
    case 'admin':
      return 'Admin';
    case 'member':
      return 'Member';
    default:
      return role;
  }
}

Color _avatarColor(int seed) {
  const colors = [
    Color(0xFF3B82F6),
    Color(0xFF06B6D4),
    Color(0xFF22C55E),
    Color(0xFF8B5CF6),
    Color(0xFFF97316),
    Color(0xFFEC4899),
  ];
  return colors[seed.abs() % colors.length];
}
