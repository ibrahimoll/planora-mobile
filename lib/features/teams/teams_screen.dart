import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/planora_theme.dart';
import '../auth/data/project_api.dart';
import '../auth/models/project_models.dart';
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
  final searchController = TextEditingController();

  int selectedTab = 0;
  String searchQuery = '';
  bool isLoading = true;
  String? errorMessage;

  List<TeamModel> teams = [];
  List<TeamInvitationModel> invitations = [];
  final membersByTeamId = <int, List<TeamMemberModel>>{};
  final projectsByTeamId = <int, List<ProjectModel>>{};
  final statsByTeamId = <int, _TeamStats>{};

  @override
  void initState() {
    super.initState();
    selectedTab = widget.openInvitations ? 1 : 0;
    loadTeams();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<TeamInvitationModel> get pendingInvitations =>
      invitations.where((item) => item.isPending).toList();

  int get totalMembers =>
      statsByTeamId.values.fold(0, (sum, item) => sum + item.memberCount);

  int get totalProjects =>
      statsByTeamId.values.fold(0, (sum, item) => sum + item.projectCount);

  int get totalTasks =>
      statsByTeamId.values.fold(0, (sum, item) => sum + item.taskCount);

  List<TeamModel> get visibleTeams {
    final query = searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return teams;
    }

    return teams.where((team) {
      final members = membersByTeamId[team.teamId] ?? const <TeamMemberModel>[];
      final projects = projectsByTeamId[team.teamId] ?? const <ProjectModel>[];
      final stats = statsByTeamId[team.teamId];

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

  Future<void> loadTeams({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final loadedTeams = await widget.teamsApi.getTeams();
      final loadedInvitations = await widget.teamsApi.getMyInvitations();

      if (!mounted) {
        return;
      }

      setState(() {
        teams = loadedTeams;
        invitations = loadedInvitations;
        membersByTeamId.clear();
        projectsByTeamId.clear();
        statsByTeamId.clear();
        isLoading = false;
        errorMessage = null;
      });

      await loadTeamDetails(loadedTeams);
    } catch (error, stackTrace) {
      debugPrint('Teams load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        errorMessage = _apiMessage(
          error,
          fallback: 'Could not load teams. Pull down or tap retry.',
        );
      });
    }
  }

  Future<void> loadTeamDetails(List<TeamModel> loadedTeams) async {
    for (final team in loadedTeams) {
      try {
        final members = await widget.teamsApi.getTeamMembers(team.teamId);

        var projects = <ProjectModel>[];
        try {
          projects = await widget.projectsApi.getTeamProjects(team.teamId);
        } catch (error, stackTrace) {
          debugPrint('Team projects load failed: $error');
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
            debugPrint('Team task load failed: $error');
            debugPrintStack(stackTrace: stackTrace);
          }
        }

        if (!mounted) {
          return;
        }

        setState(() {
          membersByTeamId[team.teamId] = members;
          projectsByTeamId[team.teamId] = projects;
          statsByTeamId[team.teamId] = _TeamStats(
            memberCount: members.length,
            projectCount: projects.length,
            taskCount: taskCount,
            completedTaskCount: completedTaskCount,
          );
        });
      } catch (error, stackTrace) {
        debugPrint('Team details load failed: $error');
        debugPrintStack(stackTrace: stackTrace);

        if (!mounted) {
          return;
        }

        setState(() {
          membersByTeamId[team.teamId] = const [];
          projectsByTeamId[team.teamId] = const [];
          statsByTeamId[team.teamId] = const _TeamStats(
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
      onRefresh: () => loadTeams(showLoading: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(0, 0, 0, widget.showBackButton ? 28 : 112),
        children: [
          _Entrance(
            index: 0,
            child: _TeamsHero(
              showBackButton: widget.showBackButton,
              onBackPressed: () => Navigator.of(context).maybePop(),
              onCreatePressed: openCreateTeamSheet,
              teamCount: teams.length,
              memberCount: totalMembers,
              projectCount: totalProjects,
              taskCount: totalTasks,
              pendingInviteCount: pendingInvitations.length,
            ),
          ),
          const SizedBox(height: 14),
          _Entrance(
            index: 1,
            child: _SearchField(
              controller: searchController,
              onChanged: (value) => setState(() => searchQuery = value),
              onClear: clearSearch,
            ),
          ),
          const SizedBox(height: 14),
          _Entrance(
            index: 2,
            child: _TeamTabs(
              selectedIndex: selectedTab,
              invitationCount: pendingInvitations.length,
              onChanged: (index) => setState(() => selectedTab = index),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: selectedTab == 0
                ? Column(
                    key: const ValueKey('teams'),
                    children: buildTeamContent(),
                  )
                : Column(
                    key: const ValueKey('invitations'),
                    children: [buildInvitationContent()],
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
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void clearSearch() {
    searchController.clear();
    setState(() => searchQuery = '');
  }

  List<Widget> buildTeamContent() {
    if (isLoading && teams.isEmpty) {
      return const [
        _TeamLoadingCard(),
        SizedBox(height: 12),
        _TeamLoadingCard(),
        SizedBox(height: 12),
        _TeamLoadingCard(),
      ];
    }

    if (errorMessage != null && teams.isEmpty) {
      return [
        _StateCard(
          icon: Icons.wifi_off_rounded,
          title: 'Teams could not load',
          message: errorMessage!,
          actionText: 'Retry',
          onAction: () => loadTeams(),
        ),
      ];
    }

    if (visibleTeams.isEmpty) {
      return [
        _StateCard(
          icon: Icons.groups_2_outlined,
          title: searchQuery.trim().isEmpty ? 'No teams yet' : 'No teams found',
          message: searchQuery.trim().isEmpty
              ? 'Create a workspace for members, plans, and delivery work.'
              : 'Try another team, member, plan, or role name.',
          actionText: searchQuery.trim().isEmpty ? 'Create Team' : null,
          onAction: searchQuery.trim().isEmpty ? openCreateTeamSheet : null,
        ),
      ];
    }

    return [
      _SectionHint(count: visibleTeams.length),
      const SizedBox(height: 10),
      for (int index = 0; index < visibleTeams.length; index++) ...[
        _Entrance(
          index: index + 3,
          child: buildSlidableTeamCard(visibleTeams[index]),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  Widget buildSlidableTeamCard(TeamModel team) {
    final canManage = canManageTeam(team);
    final canDelete = canDeleteTeam(team);

    return Slidable(
      key: ValueKey('team-${team.teamId}'),
      closeOnScroll: true,
      startActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: canManage ? 0.52 : 0.26,
        children: [
          SlidableAction(
            onPressed: (_) => openTeamDetailsSheet(team),
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
            icon: Icons.visibility_outlined,
            label: 'Open',
            borderRadius: BorderRadius.circular(18),
          ),
          if (canManage)
            SlidableAction(
              onPressed: (_) => openInviteMemberSheet(team),
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
        extentRatio: canDelete ? 0.52 : 0.26,
        children: [
          if (canManage)
            SlidableAction(
              onPressed: (_) => openRenameTeamSheet(team),
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              icon: Icons.edit_outlined,
              label: 'Rename',
              borderRadius: BorderRadius.circular(18),
            ),
          if (canDelete)
            SlidableAction(
              onPressed: (_) => confirmDeleteTeam(team),
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
        members: membersByTeamId[team.teamId] ?? const [],
        projects: projectsByTeamId[team.teamId] ?? const [],
        stats: statsByTeamId[team.teamId],
        currentMember: currentMemberForTeam(team),
        canManage: canManage,
        onTap: () => openTeamDetailsSheet(team),
        onInvitePressed: canManage ? () => openInviteMemberSheet(team) : null,
        onMenuPressed: () => openTeamActionsSheet(team),
      ),
    );
  }

  Widget buildInvitationContent() {
    if (isLoading && invitations.isEmpty) {
      return const _TeamLoadingCard();
    }

    if (pendingInvitations.isEmpty) {
      return const _StateCard(
        icon: Icons.mail_outline_rounded,
        title: 'No invitations',
        message: 'Team invitations will show here when someone invites you.',
      );
    }

    return Column(
      children: [
        for (int index = 0; index < pendingInvitations.length; index++) ...[
          _Entrance(
            index: index,
            child: _InvitationCard(
              invitation: pendingInvitations[index],
              onAccept: () =>
                  respondToInvitation(pendingInvitations[index], accept: true),
              onReject: () =>
                  respondToInvitation(pendingInvitations[index], accept: false),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Future<void> openCreateTeamSheet() async {
    await openTeamNameSheet(
      title: 'Create team',
      subtitle: 'Name the workspace where members and plans live.',
      initialName: '',
      buttonLabel: 'Create Team',
      loadingLabel: 'Creating...',
      onSubmit: (name) async {
        await widget.teamsApi.createTeam(name);
        showMessage('Team created.');
      },
    );
  }

  Future<void> openRenameTeamSheet(TeamModel team) async {
    await openTeamNameSheet(
      title: 'Rename team',
      subtitle: 'Keep the team name clear and easy to recognize.',
      initialName: team.name,
      buttonLabel: 'Save Changes',
      loadingLabel: 'Saving...',
      onSubmit: (name) async {
        await widget.teamsApi.updateTeam(teamId: team.teamId, name: name);
        showMessage('Team updated.');
      },
    );
  }

  Future<void> openTeamNameSheet({
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
                showMessage('Team name must be at least 2 letters.');
                return;
              }

              if (isSubmitting) {
                return;
              }

              setSheetState(() => isSubmitting = true);
              var success = false;

              try {
                await onSubmit(name);
                success = true;
              } catch (error, stackTrace) {
                debugPrint('Team name submit failed: $error');
                debugPrintStack(stackTrace: stackTrace);
                showMessage(_apiMessage(error, fallback: 'Could not save team.'));
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => isSubmitting = false);
                }
              }

              if (!success || !mounted || !sheetContext.mounted) {
                return;
              }

              Navigator.of(sheetContext).pop();
              widget.onTeamsChanged?.call();
              await loadTeams(showLoading: false);
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

  Future<void> openTeamActionsSheet(TeamModel team) async {
    final currentMember = currentMemberForTeam(team);
    final canManage = canManageTeam(team);
    final canDelete = canDeleteTeam(team);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _BottomSheetShell(
          title: team.name,
          subtitle: currentMember == null
              ? 'Team workspace'
              : 'Your role: ${currentMember.roleLabel}',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionTile(
                icon: Icons.dashboard_customize_outlined,
                title: 'Team details',
                subtitle: 'Members, roles, plans, and task progress',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  openTeamDetailsSheet(team);
                },
              ),
              if (canManage) ...[
                _ActionTile(
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'Invite member',
                  subtitle: 'Add someone by username',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    openInviteMemberSheet(team);
                  },
                ),
                _ActionTile(
                  icon: Icons.edit_outlined,
                  title: 'Rename team',
                  subtitle: 'Update this workspace name',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    openRenameTeamSheet(team);
                  },
                ),
              ],
              _ActionTile(
                icon: Icons.refresh_rounded,
                title: 'Refresh',
                subtitle: 'Reload members and plans',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  loadTeams(showLoading: false);
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
                    confirmDeleteTeam(team);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> openTeamDetailsSheet(TeamModel team) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final members = membersByTeamId[team.teamId] ?? const <TeamMemberModel>[];
        final projects = projectsByTeamId[team.teamId] ?? const <ProjectModel>[];
        final stats = statsByTeamId[team.teamId];
        final currentMember = currentMemberForTeam(team);
        final canManage = canManageTeam(team);
        final canEditRoles = canEditMemberRoles(team);

        return _BottomSheetShell(
          title: team.name,
          subtitle: currentMember == null
              ? 'Team workspace'
              : 'Your role: ${currentMember.roleLabel}',
          maxHeightFactor: 0.90,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TeamOverviewPanel(team: team, currentMember: currentMember),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _SheetStat(label: 'Members', value: '${stats?.memberCount ?? members.length}'),
                    const SizedBox(width: 8),
                    _SheetStat(label: 'Plans', value: '${stats?.projectCount ?? projects.length}'),
                    const SizedBox(width: 8),
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
                          openInviteMemberSheet(team);
                        }
                      : null,
                ),
                const SizedBox(height: 8),
                if (members.isEmpty)
                  const _MutedText('Members are loading or unavailable.')
                else
                  for (final member in members)
                    _MemberRow(
                      member: member,
                      canEditRole: canEditRoles &&
                          member.role != 'owner' &&
                          member.userId != widget.currentUserId,
                      canRemove: canManage &&
                          member.role != 'owner' &&
                          member.userId != widget.currentUserId,
                      onChangeRole: () => openChangeRoleSheet(
                        team: team,
                        member: member,
                        parentContext: sheetContext,
                      ),
                      onRemove: () => confirmRemoveMember(team: team, member: member),
                    ),
                const SizedBox(height: 18),
                const _SheetSectionHeader(title: 'Team plans'),
                const SizedBox(height: 8),
                if (projects.isEmpty)
                  const _MutedText('No team plans yet.')
                else
                  for (final project in projects.take(8))
                    _ProjectRow(project: project),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> openInviteMemberSheet(TeamModel team) async {
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
                showMessage('Enter a valid username first.');
                return;
              }

              if (isSubmitting) {
                return;
              }

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
                showMessage(
                  _apiMessage(error, fallback: 'Could not send invitation.'),
                );
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => isSubmitting = false);
                }
              }

              if (!success || !mounted || !sheetContext.mounted) {
                return;
              }

              Navigator.of(sheetContext).pop();
              showMessage('Invitation sent.');
              await loadTeams(showLoading: false);
            }

            return _BottomSheetShell(
              title: 'Invite to ${team.name}',
              subtitle: 'Send an invitation by username and assign a role.',
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
                  _RoleSelector(
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

  Future<void> openChangeRoleSheet({
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
              if (isSubmitting) {
                return;
              }

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
                showMessage(_apiMessage(error, fallback: 'Could not update role.'));
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => isSubmitting = false);
                }
              }

              if (!success || !mounted || !sheetContext.mounted) {
                return;
              }

              Navigator.of(sheetContext).pop();
              if (parentContext.mounted) {
                Navigator.of(parentContext).pop();
              }
              showMessage('Member role updated.');
              await loadTeams(showLoading: false);
              if (mounted) {
                openTeamDetailsSheet(team);
              }
            }

            return _BottomSheetShell(
              title: 'Change role',
              subtitle: 'Update ${member.displayName} permissions.',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MemberPreview(member: member),
                  const SizedBox(height: 14),
                  _RoleSelector(
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

  Future<void> confirmRemoveMember({
    required TeamModel team,
    required TeamMemberModel member,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Remove member?',
        message: 'Remove ${member.displayName} from ${team.name}?',
        destructiveLabel: 'Remove',
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.teamsApi.removeMember(teamId: team.teamId, userId: member.userId);

      if (!mounted) {
        return;
      }

      showMessage('Member removed.');
      await loadTeams(showLoading: false);
    } catch (error, stackTrace) {
      debugPrint('Remove member failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      showMessage(_apiMessage(error, fallback: 'Could not remove member.'));
    }
  }

  Future<bool?> confirmDeleteTeam(TeamModel team) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Delete team?',
        message: 'This will remove "${team.name}" if your account has permission.',
        destructiveLabel: 'Delete',
      ),
    );

    if (confirmed == true) {
      await deleteTeam(team);
    }

    return confirmed;
  }

  Future<void> deleteTeam(TeamModel team) async {
    final oldTeams = List<TeamModel>.from(teams);
    final oldMembers = Map<int, List<TeamMemberModel>>.from(membersByTeamId);
    final oldProjects = Map<int, List<ProjectModel>>.from(projectsByTeamId);
    final oldStats = Map<int, _TeamStats>.from(statsByTeamId);

    setState(() {
      teams.removeWhere((item) => item.teamId == team.teamId);
      membersByTeamId.remove(team.teamId);
      projectsByTeamId.remove(team.teamId);
      statsByTeamId.remove(team.teamId);
    });

    try {
      await widget.teamsApi.deleteTeam(team.teamId);

      if (!mounted) {
        return;
      }

      showMessage('Team deleted.');
      widget.onTeamsChanged?.call();
    } catch (error, stackTrace) {
      debugPrint('Delete team failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        teams = oldTeams;
        membersByTeamId
          ..clear()
          ..addAll(oldMembers);
        projectsByTeamId
          ..clear()
          ..addAll(oldProjects);
        statsByTeamId
          ..clear()
          ..addAll(oldStats);
      });

      showMessage(_apiMessage(error, fallback: 'Could not delete team.'));
    }
  }

  Future<void> respondToInvitation(
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

      showMessage(accept ? 'Invitation accepted.' : 'Invitation rejected.');
      widget.onTeamsChanged?.call();
      await loadTeams(showLoading: false);
    } catch (error, stackTrace) {
      debugPrint('Invitation response failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      showMessage(_apiMessage(error, fallback: 'Could not update invitation.'));
    }
  }

  TeamMemberModel? currentMemberForTeam(TeamModel team) {
    final id = widget.currentUserId;

    if (id == null) {
      return null;
    }

    final members = membersByTeamId[team.teamId] ?? const <TeamMemberModel>[];

    for (final member in members) {
      if (member.userId == id) {
        return member;
      }
    }

    return null;
  }

  bool canManageTeam(TeamModel team) {
    final role = currentMemberForTeam(team)?.role;
    return role == 'owner' || role == 'admin';
  }

  bool canEditMemberRoles(TeamModel team) {
    return currentMemberForTeam(team)?.role == 'owner';
  }

  bool canDeleteTeam(TeamModel team) {
    return currentMemberForTeam(team)?.role == 'owner';
  }

  void showMessage(String message) {
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

class _Entrance extends StatelessWidget {
  const _Entrance({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = 250 + (index * 40).clamp(0, 240);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: animatedChild,
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
  });

  final bool showBackButton;
  final VoidCallback onBackPressed;
  final VoidCallback onCreatePressed;
  final int teamCount;
  final int memberCount;
  final int projectCount;
  final int taskCount;
  final int pendingInviteCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF17112F), const Color(0xFF0B0820)]
              : [Colors.white, const Color(0xFFF6F2FF)],
        ),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2450) : const Color(0xFFE7DFFF),
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: isDark ? 0.18 : 0.10),
            blurRadius: 28,
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
                _CircleIconButton(
                  icon: Icons.arrow_back_rounded,
                  onPressed: onBackPressed,
                ),
                const SizedBox(width: 10),
              ],
              _GradientSquareIcon(icon: Icons.groups_2_rounded, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Teams',
                      style: TextStyle(
                        fontSize: 29,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF141724),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Manage people, plans, roles, and shared workspaces.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white60 : const Color(0xFF6D7390),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _GradientIconButton(icon: Icons.add_rounded, onPressed: onCreatePressed),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroStatPill(icon: Icons.groups_outlined, label: 'Teams', value: teamCount),
              _HeroStatPill(icon: Icons.person_outline_rounded, label: 'Members', value: memberCount),
              _HeroStatPill(icon: Icons.folder_copy_outlined, label: 'Plans', value: projectCount),
              _HeroStatPill(icon: Icons.check_box_outlined, label: 'Tasks', value: taskCount),
              if (pendingInviteCount > 0)
                _HeroStatPill(icon: Icons.mail_outline_rounded, label: 'Invites', value: pendingInviteCount),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStatPill extends StatelessWidget {
  const _HeroStatPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      width: 138,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2450) : const Color(0xFFECEAF6),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white60 : const Color(0xFF667085),
              ),
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF151827),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
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
    final iconColor = isDark ? Colors.white54 : const Color(0xFF8C93AB);

    return _CardShell(
      borderRadius: 20,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        cursorColor: Theme.of(context).colorScheme.primary,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : const Color(0xFF151827),
        ),
        decoration: InputDecoration(
          hintText: 'Search teams, members, plans, roles...',
          hintStyle: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white38 : const Color(0xFF9AA1B8),
          ),
          prefixIcon: Icon(Icons.search_rounded, color: iconColor),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              if (value.text.trim().isEmpty) {
                return const SizedBox.shrink();
              }

              return IconButton(
                onPressed: onClear,
                icon: Icon(Icons.close_rounded, size: 20, color: iconColor),
              );
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        ),
      ),
    );
  }
}

class _TeamTabs extends StatelessWidget {
  const _TeamTabs({
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
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14122A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2450) : const Color(0xFFE8EAF2),
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
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? primary.withValues(alpha: isDark ? 0.28 : 0.12)
                : Colors.transparent,
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
                    color: selected
                        ? primary
                        : (isDark ? Colors.white60 : const Color(0xFF6D7390)),
                  ),
                ),
              ),
              if (badge != null && badge! > 0) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(99),
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

class _SectionHint extends StatelessWidget {
  const _SectionHint({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Icon(
          Icons.tune_rounded,
          size: 16,
          color: isDark ? Colors.white38 : const Color(0xFF8A91AA),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$count team${count == 1 ? '' : 's'} loaded • tap a team to manage it',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white38 : const Color(0xFF8A91AA),
            ),
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
    final completion = _progress(doneCount, taskCount);
    final activeProjects = projects.where((item) => item.isActive).length;

    return _CardShell(
      borderRadius: 24,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _GradientSquareIcon(icon: _teamIcon(team.name), size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
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
                                const SizedBox(width: 8),
                                _RoleBadge(label: currentMember!.roleLabel),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$activeProjects active plans • $doneCount/$taskCount tasks done',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white54 : const Color(0xFF6D7390),
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
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: isDark ? Colors.white54 : const Color(0xFF68708A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: completion,
                    minHeight: 5,
                    backgroundColor: isDark ? const Color(0xFF2C2845) : const Color(0xFFE9EBF4),
                    valueColor: AlwaysStoppedAnimation<Color>(primary),
                  ),
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        members.isEmpty
                            ? 'Members loading'
                            : members.take(3).map((member) => member.displayName).join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white38 : const Color(0xFF8A91AA),
                        ),
                      ),
                    ),
                    _MiniStat(icon: Icons.group_outlined, value: memberCount),
                    const SizedBox(width: 12),
                    _MiniStat(icon: Icons.folder_copy_outlined, value: projectCount),
                    const SizedBox(width: 12),
                    _MiniStat(icon: Icons.check_box_outlined, value: taskCount),
                  ],
                ),
                if (canManage) ...[
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      Expanded(
                        child: _InlineActionButton(
                          icon: Icons.person_add_alt_1_rounded,
                          label: 'Invite',
                          onTap: onInvitePressed,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InlineActionButton(
                          icon: Icons.dashboard_customize_outlined,
                          label: 'Manage',
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
  const _TeamOverviewPanel({required this.team, required this.currentMember});

  final TeamModel team;
  final TeamMemberModel? currentMember;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF21183D), const Color(0xFF131127)]
              : [const Color(0xFFF7F2FF), Colors.white],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF302A56) : const Color(0xFFE8DFFF),
        ),
      ),
      child: Row(
        children: [
          _GradientSquareIcon(icon: _teamIcon(team.name), size: 50),
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
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF151827),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  currentMember == null
                      ? 'Team workspace'
                      : 'Your role: ${currentMember!.roleLabel}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white60 : const Color(0xFF667085),
                  ),
                ),
              ],
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
      borderRadius: 24,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _GradientSquareIcon(icon: Icons.mail_outline_rounded, size: 48),
                const SizedBox(width: 12),
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
                        'Invited as ${_roleLabel(invitation.role)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : const Color(0xFF6D7390),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _OutlineActionButton(label: 'Decline', onTap: onReject),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PrimaryMiniButton(label: 'Accept', onTap: onAccept),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.child,
    this.borderRadius = 22,
  });

  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14122A) : Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2450) : const Color(0xFFE9EAF2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.045),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _GradientSquareIcon extends StatelessWidget {
  const _GradientSquareIcon({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.34;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.20),
            blurRadius: 16,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.52),
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
          colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.26),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 28),
      ),
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

    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.white,
          foregroundColor: isDark ? Colors.white : const Color(0xFF1E2233),
        ),
        icon: Icon(icon, size: 20),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: isDark ? Colors.white45 : const Color(0xFF667085),
        ),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white70 : const Color(0xFF3E4459),
          ),
        ),
      ],
    );
  }
}

class _InlineActionButton extends StatelessWidget {
  const _InlineActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: isDark ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: primary.withValues(alpha: 0.10)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: primary),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: primary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryMiniButton extends StatelessWidget {
  const _PrimaryMiniButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  const _OutlineActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white70 : const Color(0xFF4B5563),
          side: BorderSide(
            color: isDark ? const Color(0xFF302A56) : const Color(0xFFE5E7EB),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
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
        color: primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: primary,
        ),
      ),
    );
  }
}

class _BottomSheetShell extends StatelessWidget {
  const _BottomSheetShell({
    required this.title,
    required this.subtitle,
    required this.child,
    this.maxHeightFactor,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final double? maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxHeight = mediaQuery.size.height * (maxHeightFactor ?? 0.78);

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 430, maxHeight: maxHeight),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111026) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? const Color(0xFF302A56) : const Color(0xFFE9EAF2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : const Color(0xFFE1E4EF),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF151827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white54 : const Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      ),
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

    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.done,
      style: TextStyle(
        fontWeight: FontWeight.w800,
        color: isDark ? Colors.white : const Color(0xFF151827),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: isDark ? const Color(0xFF17152E) : const Color(0xFFF8F7FC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF302A56) : const Color(0xFFE5E7EB),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF302A56) : const Color(0xFFE5E7EB),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.4,
          ),
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
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({required this.selectedRole, required this.onChanged});

  final String selectedRole;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoleChoice(
          label: 'Member',
          value: 'member',
          selectedRole: selectedRole,
          onChanged: onChanged,
        ),
        const SizedBox(width: 10),
        _RoleChoice(
          label: 'Admin',
          value: 'admin',
          selectedRole: selectedRole,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _RoleChoice extends StatelessWidget {
  const _RoleChoice({
    required this.label,
    required this.value,
    required this.selectedRole,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String selectedRole;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == selectedRole;
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: selected
                ? primary.withValues(alpha: isDark ? 0.24 : 0.10)
                : (isDark ? const Color(0xFF17152E) : const Color(0xFFF8F7FC)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? primary.withValues(alpha: 0.32)
                  : (isDark ? const Color(0xFF302A56) : const Color(0xFFE5E7EB)),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: selected
                    ? primary
                    : (isDark ? Colors.white70 : const Color(0xFF667085)),
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
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF17152E) : const Color(0xFFF8F7FC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? const Color(0xFF302A56) : const Color(0xFFE9EAF2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: effectiveColor, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF151827),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white45 : const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white38 : const Color(0xFF98A2B3),
              ),
            ],
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF17152E) : const Color(0xFFF8F7FC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF302A56) : const Color(0xFFE9EAF2),
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                color: isDark ? Colors.white : const Color(0xFF151827),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white45 : const Color(0xFF667085),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetSectionHeader extends StatelessWidget {
  const _SheetSectionHeader({this.title, this.actionLabel, this.onAction});

  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: Text(
            title ?? '',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF151827),
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel!,
              style: TextStyle(color: primary, fontWeight: FontWeight.w900),
            ),
          ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.canEditRole,
    required this.canRemove,
    required this.onChangeRole,
    required this.onRemove,
  });

  final TeamMemberModel member;
  final bool canEditRole;
  final bool canRemove;
  final VoidCallback onChangeRole;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF17152E) : const Color(0xFFF8F7FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF302A56) : const Color(0xFFE9EAF2),
        ),
      ),
      child: Row(
        children: [
          _InitialsAvatar(label: member.initials, color: _avatarColor(member.userId), size: 36),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF151827),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  member.user?.username ?? 'User #${member.userId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white45 : const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
          _RoleBadge(label: member.roleLabel),
          if (canEditRole || canRemove)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: isDark ? Colors.white54 : const Color(0xFF667085),
              ),
              onSelected: (value) {
                if (value == 'role') {
                  onChangeRole();
                }
                if (value == 'remove') {
                  onRemove();
                }
              },
              itemBuilder: (context) => [
                if (canEditRole)
                  const PopupMenuItem(value: 'role', child: Text('Change role')),
                if (canRemove)
                  const PopupMenuItem(value: 'remove', child: Text('Remove')),
              ],
            ),
        ],
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF17152E) : const Color(0xFFF8F7FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF302A56) : const Color(0xFFE9EAF2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.folder_copy_outlined, color: primary, size: 19),
          ),
          const SizedBox(width: 11),
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
                    color: isDark ? Colors.white : const Color(0xFF151827),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${project.statusLabel} • ${project.deadlineLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white45 : const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
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
        color: isDark ? const Color(0xFF17152E) : const Color(0xFFF8F7FC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _InitialsAvatar(label: member.initials, color: _avatarColor(member.userId), size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF151827),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Current role: ${member.roleLabel}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white45 : const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.label, required this.color, required this.size});

  final String label;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MutedText extends StatelessWidget {
  const _MutedText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? Colors.white45 : const Color(0xFF8A91AA),
          fontWeight: FontWeight.w700,
        ),
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
      borderRadius: 24,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: primary),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF151827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                height: 1.35,
                color: isDark ? Colors.white54 : const Color(0xFF667085),
                fontWeight: FontWeight.w700,
              ),
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 14),
              _PrimaryMiniButton(label: actionText!, onTap: onAction!),
            ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _CardShell(
      borderRadius: 24,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFEDEAF6),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LoadingLine(widthFactor: 0.72),
                  const SizedBox(height: 8),
                  _LoadingLine(widthFactor: 0.46),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingLine extends StatelessWidget {
  const _LoadingLine({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 11,
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : const Color(0xFFEDEAF6),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.destructiveLabel,
  });

  final String title;
  final String message;
  final String destructiveLabel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.12),
            foregroundColor: const Color(0xFFEF4444),
          ),
          child: Text(destructiveLabel),
        ),
      ],
    );
  }
}

@immutable
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

IconData _teamIcon(String name) {
  final normalized = name.toLowerCase();

  if (normalized.contains('qa') || normalized.contains('test')) {
    return Icons.fact_check_outlined;
  }

  if (normalized.contains('design') || normalized.contains('creative')) {
    return Icons.palette_outlined;
  }

  if (normalized.contains('dev') || normalized.contains('code')) {
    return Icons.code_rounded;
  }

  return Icons.groups_2_rounded;
}

String _roleLabel(String role) {
  switch (role) {
    case 'admin':
      return 'Admin';
    case 'owner':
      return 'Owner';
    case 'member':
      return 'Member';
    default:
      return role;
  }
}

double _progress(int completed, int total) {
  if (total <= 0) {
    return 0;
  }

  return (completed / total).clamp(0, 1).toDouble();
}

Color _avatarColor(int seed) {
  const colors = [
    Color(0xFF7C3AED),
    Color(0xFF06B6D4),
    Color(0xFF2563EB),
    Color(0xFFDB2777),
    Color(0xFF059669),
    Color(0xFFF97316),
  ];

  return colors[seed.abs() % colors.length];
}

String _apiMessage(Object error, {required String fallback}) {
  if (error is ApiException) {
    final message = error.message.trim();

    if (message.isNotEmpty && message != 'Something went wrong. Please try again.') {
      return message;
    }
  }

  return fallback;
}
