import 'package:flutter/material.dart';

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

  List<TeamInvitationModel> get pendingInvitations {
    return invitations.where((item) => item.isPending).toList();
  }

  int get totalMembers {
    return statsByTeamId.values.fold(0, (sum, stats) => sum + stats.memberCount);
  }

  int get totalPlans {
    return statsByTeamId.values.fold(0, (sum, stats) => sum + stats.projectCount);
  }

  int get totalTasks {
    return statsByTeamId.values.fold(0, (sum, stats) => sum + stats.taskCount);
  }

  int get completedTasks {
    return statsByTeamId.values.fold(
      0,
      (sum, stats) => sum + stats.completedTaskCount,
    );
  }

  List<TeamModel> get visibleTeams {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return teams;

    return teams.where((team) {
      final members = membersByTeamId[team.teamId] ?? const <TeamMemberModel>[];
      final projects = projectsByTeamId[team.teamId] ?? const <ProjectModel>[];

      return team.name.toLowerCase().contains(query) ||
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
                project.statusLabel.toLowerCase().contains(query),
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

      if (!mounted) return;

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

      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = _apiMessage(error, fallback: 'Could not load teams.');
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
            completedTaskCount += tasks.where((item) => item.task.isCompleted).length;
          } catch (error, stackTrace) {
            debugPrint('Team task load failed: $error');
            debugPrintStack(stackTrace: stackTrace);
          }
        }

        if (!mounted) return;

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

        if (!mounted) return;

        setState(() {
          membersByTeamId[team.teamId] = const [];
          projectsByTeamId[team.teamId] = const [];
          statsByTeamId[team.teamId] = const _TeamStats();
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
        padding: EdgeInsets.fromLTRB(20, 18, 20, widget.showBackButton ? 28 : 112),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AnimatedIn(
                    index: 0,
                    child: _TeamsCommandHeader(
                      showBackButton: widget.showBackButton,
                      onBackPressed: () => Navigator.of(context).maybePop(),
                      onCreatePressed: openCreateTeamSheet,
                      teamCount: teams.length,
                      memberCount: totalMembers,
                      planCount: totalPlans,
                      taskCount: totalTasks,
                      completedTaskCount: completedTasks,
                      invitationCount: pendingInvitations.length,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _AnimatedIn(
                    index: 1,
                    child: _SearchField(
                      controller: searchController,
                      onChanged: (value) => setState(() => searchQuery = value),
                      onClear: clearSearch,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AnimatedIn(
                    index: 2,
                    child: _SegmentedTabs(
                      selectedIndex: selectedTab,
                      invitationCount: pendingInvitations.length,
                      onChanged: (index) => setState(() => selectedTab = index),
                    ),
                  ),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    child: selectedTab == 0
                        ? Column(
                            key: const ValueKey('teams'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: buildTeamContent(),
                          )
                        : Column(
                            key: const ValueKey('invitations'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: buildInvitationContent(),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (!widget.showBackButton) {
      return Material(type: MaterialType.transparency, child: content);
    }

    return Scaffold(
      backgroundColor: _pageBackground(context),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: PlanoraTheme.onboardingBackgroundFor(context)),
        child: SafeArea(bottom: false, child: content),
      ),
    );
  }

  List<Widget> buildTeamContent() {
    if (isLoading && teams.isEmpty) {
      return const [
        _LoadingTeamTile(),
        SizedBox(height: 12),
        _LoadingTeamTile(),
        SizedBox(height: 12),
        _LoadingTeamTile(),
      ];
    }

    if (errorMessage != null && teams.isEmpty) {
      return [
        _EmptyStateCard(
          icon: Icons.cloud_off_rounded,
          title: 'Teams could not load',
          message: errorMessage!,
          actionText: 'Retry',
          onAction: () => loadTeams(),
        ),
      ];
    }

    if (visibleTeams.isEmpty) {
      return [
        _EmptyStateCard(
          icon: Icons.groups_2_outlined,
          title: searchQuery.trim().isEmpty ? 'No teams yet' : 'No teams found',
          message: searchQuery.trim().isEmpty
              ? 'Create a focused team hub and attach people, plans, and tasks.'
              : 'Try another team, member, role, or plan name.',
          actionText: searchQuery.trim().isEmpty ? 'Create Team' : null,
          onAction: searchQuery.trim().isEmpty ? openCreateTeamSheet : null,
        ),
      ];
    }

    return [
      _SectionTitle(
        title: 'Team hubs',
        count: visibleTeams.length,
        subtitle: 'Tap a card to inspect members and attached plans.',
      ),
      const SizedBox(height: 10),
      for (int index = 0; index < visibleTeams.length; index++) ...[
        _AnimatedIn(
          index: index + 3,
          child: _PlanoraTeamCard(
            team: visibleTeams[index],
            members: membersByTeamId[visibleTeams[index].teamId] ?? const [],
            projects: projectsByTeamId[visibleTeams[index].teamId] ?? const [],
            stats: statsByTeamId[visibleTeams[index].teamId] ?? const _TeamStats(),
            currentMember: currentMemberForTeam(visibleTeams[index]),
            canManage: canManageTeam(visibleTeams[index]),
            onTap: () => openTeamDetailsSheet(visibleTeams[index]),
            onMenuPressed: () => openTeamActionsSheet(visibleTeams[index]),
            onInvitePressed: canManageTeam(visibleTeams[index])
                ? () => openInviteMemberSheet(visibleTeams[index])
                : null,
          ),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  List<Widget> buildInvitationContent() {
    if (isLoading && invitations.isEmpty) {
      return const [_LoadingTeamTile()];
    }

    if (pendingInvitations.isEmpty) {
      return const [
        _EmptyStateCard(
          icon: Icons.mail_outline_rounded,
          title: 'No invitations',
          message: 'Team invitations will appear here when someone invites you.',
        ),
      ];
    }

    return [
      _SectionTitle(
        title: 'Invitations',
        count: pendingInvitations.length,
        subtitle: 'Accept team access requests from here.',
      ),
      const SizedBox(height: 10),
      for (int index = 0; index < pendingInvitations.length; index++) ...[
        _AnimatedIn(
          index: index + 3,
          child: _InvitationCard(
            invitation: pendingInvitations[index],
            onAccept: () => respondToInvitation(pendingInvitations[index], accept: true),
            onReject: () => respondToInvitation(pendingInvitations[index], accept: false),
          ),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  void clearSearch() {
    searchController.clear();
    setState(() => searchQuery = '');
  }

  TeamMemberModel? currentMemberForTeam(TeamModel team) {
    final currentUserId = widget.currentUserId;
    if (currentUserId == null) return null;

    for (final member in membersByTeamId[team.teamId] ?? const <TeamMemberModel>[]) {
      if (member.userId == currentUserId) return member;
    }

    return null;
  }

  bool canManageTeam(TeamModel team) {
    final currentUserId = widget.currentUserId;
    if (currentUserId != null && team.createdBy == currentUserId) return true;
    final role = currentMemberForTeam(team)?.role;
    return role == 'owner' || role == 'admin';
  }

  void showMessage(String message) {
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

  Future<void> reloadAfterMutation(String message) async {
    await loadTeams(showLoading: false);
    widget.onTeamsChanged?.call();
    if (!mounted) return;
    showMessage(message);
  }

  Future<void> openCreateTeamSheet() async {
    await openTeamNameSheet(
      title: 'Create team hub',
      subtitle: 'Name the workspace your people and plans will live inside.',
      initialName: '',
      buttonLabel: 'Create Team',
      loadingLabel: 'Creating...',
      onSubmit: (name) async {
        await widget.teamsApi.createTeam(name);
        await reloadAfterMutation('Team created.');
      },
    );
  }

  Future<void> openRenameTeamSheet(TeamModel team) async {
    await openTeamNameSheet(
      title: 'Rename team',
      subtitle: 'Update the display name for this team hub.',
      initialName: team.name,
      buttonLabel: 'Save Name',
      loadingLabel: 'Saving...',
      onSubmit: (name) async {
        await widget.teamsApi.updateTeam(teamId: team.teamId, name: name);
        await reloadAfterMutation('Team renamed.');
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
    var isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> submit() async {
              if (isSubmitting) return;
              final name = controller.text.trim();
              if (name.length < 2) {
                showMessage('Team name must be at least 2 characters.');
                return;
              }

              setSheetState(() => isSubmitting = true);
              try {
                await onSubmit(name);
                if (!sheetContext.mounted) return;
                Navigator.of(sheetContext).pop();
              } catch (error, stackTrace) {
                debugPrint('Team name submit failed: $error');
                debugPrintStack(stackTrace: stackTrace);
                if (!sheetContext.mounted) return;
                showMessage(_apiMessage(error, fallback: 'Could not save team.'));
                setSheetState(() => isSubmitting = false);
              }
            }

            return _ModalShell(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 12,
                  bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SheetHandle(),
                    const SizedBox(height: 16),
                    _SheetTitle(title: title, subtitle: subtitle),
                    const SizedBox(height: 18),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Team name',
                        prefixIcon: Icon(Icons.groups_2_outlined),
                      ),
                      onSubmitted: (_) => submit(),
                    ),
                    const SizedBox(height: 18),
                    _GradientButton(
                      label: isSubmitting ? loadingLabel : buttonLabel,
                      onPressed: isSubmitting ? null : submit,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();
  }

  Future<void> openInviteMemberSheet(TeamModel team) async {
    final controller = TextEditingController();
    var role = 'member';
    var isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return _ModalShell(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 12,
                  bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SheetHandle(),
                    const SizedBox(height: 16),
                    _SheetTitle(
                      title: 'Invite member',
                      subtitle: 'Send a username invite to ${team.name}.',
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_add_alt_1_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: role,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'member', child: Text('Member')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      ],
                      onChanged: (value) {
                        setSheetState(() => role = value ?? 'member');
                      },
                    ),
                    const SizedBox(height: 18),
                    _GradientButton(
                      label: isSubmitting ? 'Sending...' : 'Send Invite',
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final username = controller.text.trim();
                              if (username.isEmpty) {
                                showMessage('Enter a username.');
                                return;
                              }

                              setSheetState(() => isSubmitting = true);
                              try {
                                await widget.teamsApi.inviteUser(
                                  teamId: team.teamId,
                                  username: username,
                                  role: role,
                                );
                                await reloadAfterMutation('Invitation sent.');
                                if (!sheetContext.mounted) return;
                                Navigator.of(sheetContext).pop();
                              } catch (error, stackTrace) {
                                debugPrint('Invite member failed: $error');
                                debugPrintStack(stackTrace: stackTrace);
                                if (!sheetContext.mounted) return;
                                showMessage(
                                  _apiMessage(
                                    error,
                                    fallback: 'Could not send invitation.',
                                  ),
                                );
                                setSheetState(() => isSubmitting = false);
                              }
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

    controller.dispose();
  }

  void openTeamActionsSheet(TeamModel team) {
    final canManage = canManageTeam(team);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ModalShell(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SheetHandle(),
                  const SizedBox(height: 12),
                  _ActionTile(
                    icon: Icons.open_in_new_rounded,
                    title: 'Open team hub',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      openTeamDetailsSheet(team);
                    },
                  ),
                  if (canManage) ...[
                    _ActionTile(
                      icon: Icons.person_add_alt_1_rounded,
                      title: 'Invite member',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        openInviteMemberSheet(team);
                      },
                    ),
                    _ActionTile(
                      icon: Icons.drive_file_rename_outline_rounded,
                      title: 'Rename team',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        openRenameTeamSheet(team);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void openTeamDetailsSheet(TeamModel team) {
    final members = membersByTeamId[team.teamId] ?? const <TeamMemberModel>[];
    final projects = projectsByTeamId[team.teamId] ?? const <ProjectModel>[];
    final stats = statsByTeamId[team.teamId] ?? const _TeamStats();
    final currentMember = currentMemberForTeam(team);
    final canManage = canManageTeam(team);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ModalShell(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.82,
            minChildSize: 0.48,
            maxChildSize: 0.94,
            builder: (context, controller) {
              return ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  const _SheetHandle(),
                  const SizedBox(height: 16),
                  _TeamDetailHeader(
                    team: team,
                    stats: stats,
                    currentMember: currentMember,
                    canManage: canManage,
                    onInvitePressed: () {
                      Navigator.pop(sheetContext);
                      openInviteMemberSheet(team);
                    },
                  ),
                  const SizedBox(height: 18),
                  _SheetSectionTitle(title: 'Members', count: members.length),
                  const SizedBox(height: 10),
                  if (members.isEmpty)
                    const _InlineEmpty(message: 'No members loaded yet.')
                  else
                    for (final member in members) _MemberRow(member: member),
                  const SizedBox(height: 18),
                  _SheetSectionTitle(title: 'Plans', count: projects.length),
                  const SizedBox(height: 10),
                  if (projects.isEmpty)
                    const _InlineEmpty(message: 'No team plans attached yet.')
                  else
                    for (final project in projects.take(8)) _ProjectRow(project: project),
                ],
              );
            },
          ),
        );
      },
    );
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

      await reloadAfterMutation(
        accept ? 'Invitation accepted.' : 'Invitation declined.',
      );
    } catch (error, stackTrace) {
      debugPrint('Invitation response failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      showMessage(_apiMessage(error, fallback: 'Could not update invitation.'));
    }
  }
}

class _TeamStats {
  final int memberCount;
  final int projectCount;
  final int taskCount;
  final int completedTaskCount;

  const _TeamStats({
    this.memberCount = 0,
    this.projectCount = 0,
    this.taskCount = 0,
    this.completedTaskCount = 0,
  });

  double get progress {
    if (taskCount <= 0) return 0;
    return (completedTaskCount / taskCount).clamp(0.0, 1.0).toDouble();
  }
}

class _TeamsCommandHeader extends StatelessWidget {
  final bool showBackButton;
  final VoidCallback onBackPressed;
  final VoidCallback onCreatePressed;
  final int teamCount;
  final int memberCount;
  final int planCount;
  final int taskCount;
  final int completedTaskCount;
  final int invitationCount;

  const _TeamsCommandHeader({
    required this.showBackButton,
    required this.onBackPressed,
    required this.onCreatePressed,
    required this.teamCount,
    required this.memberCount,
    required this.planCount,
    required this.taskCount,
    required this.completedTaskCount,
    required this.invitationCount,
  });

  @override
  Widget build(BuildContext context) {
    final progress = taskCount == 0 ? 0 : (completedTaskCount / taskCount * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: PlanoraTheme.primaryGradientFor(context),
        borderRadius: BorderRadius.circular(30),
        boxShadow: PlanoraTheme.floatingShadowFor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showBackButton) ...[
                _GlassIconButton(icon: Icons.arrow_back_rounded, onTap: onBackPressed),
                const SizedBox(width: 10),
              ],
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                ),
                child: const Icon(Icons.groups_2_rounded, color: Colors.white),
              ),
              const Spacer(),
              _HeaderBadge(
                icon: Icons.mail_outline_rounded,
                label: invitationCount == 0 ? 'No invites' : '$invitationCount invites',
              ),
              const SizedBox(width: 10),
              _GlassIconButton(icon: Icons.add_rounded, onTap: onCreatePressed),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Team command center',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
          ),
          const SizedBox(height: 7),
          Text(
            'Manage people, shared plans, and delivery progress without the clutter.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _HeaderMetric(
                    label: 'Teams',
                    value: '$teamCount',
                    icon: Icons.dashboard_customize_outlined,
                  ),
                ),
                Expanded(
                  child: _HeaderMetric(
                    label: 'People',
                    value: '$memberCount',
                    icon: Icons.people_alt_outlined,
                  ),
                ),
                Expanded(
                  child: _HeaderMetric(
                    label: 'Plans',
                    value: '$planCount',
                    icon: Icons.folder_copy_outlined,
                  ),
                ),
                Expanded(
                  child: _HeaderMetric(
                    label: 'Done',
                    value: '$progress%',
                    icon: Icons.check_circle_outline_rounded,
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

class _HeaderMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _HeaderMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.92), size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.76),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(context, radius: 22),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        cursorColor: Theme.of(context).colorScheme.primary,
        decoration: InputDecoration(
          hintText: 'Search team, member, role, or plan...',
          prefixIcon: Icon(Icons.search_rounded, color: _mutedColor(context)),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              if (value.text.trim().isEmpty) return const SizedBox.shrink();
              return IconButton(
                onPressed: onClear,
                icon: Icon(Icons.close_rounded, color: _mutedColor(context)),
              );
            },
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  final int selectedIndex;
  final int invitationCount;
  final ValueChanged<int> onChanged;

  const _SegmentedTabs({
    required this.selectedIndex,
    required this.invitationCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: _cardDecoration(context, radius: 22, shadow: false),
      child: Row(
        children: [
          _TabPill(
            label: 'My Teams',
            icon: Icons.grid_view_rounded,
            selected: selectedIndex == 0,
            onTap: () => onChanged(0),
          ),
          _TabPill(
            label: invitationCount > 0 ? 'Invites ($invitationCount)' : 'Invites',
            icon: Icons.mail_outline_rounded,
            selected: selectedIndex == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: selected ? PlanoraTheme.primaryGradientFor(context) : null,
              color: selected ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(17),
              boxShadow: selected ? PlanoraTheme.floatingShadowFor(context) : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: selected ? Colors.white : primary),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : _mutedColor(context),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.count,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: _textColor(context),
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(width: 8),
                  _CountBadge(label: '$count'),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _mutedColor(context),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanoraTeamCard extends StatelessWidget {
  final TeamModel team;
  final List<TeamMemberModel> members;
  final List<ProjectModel> projects;
  final _TeamStats stats;
  final TeamMemberModel? currentMember;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback onMenuPressed;
  final VoidCallback? onInvitePressed;

  const _PlanoraTeamCard({
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

  @override
  Widget build(BuildContext context) {
    final activePlans = projects.where((item) => item.isActive).length;
    final progressPercent = (stats.progress * 100).round();

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          decoration: _teamCardDecoration(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TeamIcon(name: team.name),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            team.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: _textColor(context),
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 7,
                            runSpacing: 6,
                            children: [
                              _SoftLabel(text: '$activePlans active plans'),
                              _SoftLabel(text: '$progressPercent% done'),
                              if (currentMember != null)
                                _SoftLabel(text: currentMember!.roleLabel),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Team actions',
                      onPressed: onMenuPressed,
                      icon: Icon(Icons.more_horiz_rounded, color: _mutedColor(context)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ProgressTrack(value: stats.progress),
                const SizedBox(height: 15),
                Row(
                  children: [
                    _AvatarStack(members: members),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        members.isEmpty
                            ? 'No members loaded'
                            : members.take(2).map((item) => item.displayName).join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: _mutedColor(context),
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    if (canManage && onInvitePressed != null) ...[
                      const SizedBox(width: 8),
                      _MiniActionButton(
                        label: 'Invite',
                        icon: Icons.person_add_alt_1_rounded,
                        onTap: onInvitePressed!,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _CardStat(icon: Icons.people_outline_rounded, value: '${stats.memberCount}', label: 'People'),
                    const SizedBox(width: 8),
                    _CardStat(icon: Icons.folder_copy_outlined, value: '${stats.projectCount}', label: 'Plans'),
                    const SizedBox(width: 8),
                    _CardStat(icon: Icons.check_box_outlined, value: '${stats.taskCount}', label: 'Tasks'),
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

class _TeamIcon extends StatelessWidget {
  final String name;

  const _TeamIcon({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: PlanoraTheme.primaryGradientFor(context),
        borderRadius: BorderRadius.circular(18),
        boxShadow: PlanoraTheme.floatingShadowFor(context),
      ),
      child: Icon(_teamIcon(name), color: Colors.white, size: 27),
    );
  }
}

class _SoftLabel extends StatelessWidget {
  final String text;

  const _SoftLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  final double value;

  const _ProgressTrack({required this.value});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 7,
        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  final List<TeamMemberModel> members;

  const _AvatarStack({required this.members});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const SizedBox(width: 34, height: 34, child: _EmptyAvatar());
    }

    final visible = members.take(3).toList();
    return SizedBox(
      width: 34.0 + ((visible.length - 1) * 22),
      height: 34,
      child: Stack(
        children: [
          for (int index = 0; index < visible.length; index++)
            Positioned(
              left: index * 22.0,
              child: _InitialAvatar(label: visible[index].initials),
            ),
        ],
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  final String label;

  const _InitialAvatar({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: PlanoraTheme.primaryGradientFor(context),
        shape: BoxShape.circle,
        border: Border.all(color: _surfaceColor(context), width: 2),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyAvatar extends StatelessWidget {
  const _EmptyAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person_outline_rounded,
        color: Theme.of(context).colorScheme.primary,
        size: 18,
      ),
    );
  }
}

class _CardStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _CardStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: _subtleFill(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borderColor(context)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                '$value $label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _textColor(context),
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

class _MiniActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _MiniActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: PlanoraTheme.primaryGradientFor(context),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  final TeamInvitationModel invitation;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _InvitationCard({
    required this.invitation,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _teamCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TeamIcon(name: 'invitation'),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Team invitation',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: _textColor(context),
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Role: ${_roleLabel(invitation.role)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: _mutedColor(context),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: onReject, child: const Text('Decline')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GradientButton(label: 'Accept', onPressed: onAccept),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamDetailHeader extends StatelessWidget {
  final TeamModel team;
  final _TeamStats stats;
  final TeamMemberModel? currentMember;
  final bool canManage;
  final VoidCallback onInvitePressed;

  const _TeamDetailHeader({
    required this.team,
    required this.stats,
    required this.currentMember,
    required this.canManage,
    required this.onInvitePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: PlanoraTheme.primaryGradientFor(context),
        borderRadius: BorderRadius.circular(28),
        boxShadow: PlanoraTheme.floatingShadowFor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentMember == null ? 'Shared team hub' : 'Your role: ${currentMember!.roleLabel}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              if (canManage)
                _GlassIconButton(icon: Icons.person_add_alt_1_rounded, onTap: onInvitePressed),
            ],
          ),
          const SizedBox(height: 18),
          _WhiteProgressTrack(value: stats.progress),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _WhiteMetric(label: 'People', value: '${stats.memberCount}')),
              const SizedBox(width: 10),
              Expanded(child: _WhiteMetric(label: 'Plans', value: '${stats.projectCount}')),
              const SizedBox(width: 10),
              Expanded(child: _WhiteMetric(label: 'Tasks', value: '${stats.taskCount}')),
            ],
          ),
        ],
      ),
    );
  }
}

class _WhiteProgressTrack extends StatelessWidget {
  final double value;

  const _WhiteProgressTrack({required this.value});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 7,
        backgroundColor: Colors.white.withValues(alpha: 0.16),
        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }
}

class _WhiteMetric extends StatelessWidget {
  final String label;
  final String value;

  const _WhiteMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetSectionTitle extends StatelessWidget {
  final String title;
  final int count;

  const _SheetSectionTitle({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _textColor(context),
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        _CountBadge(label: '$count'),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  final TeamMemberModel member;

  const _MemberRow({required this.member});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: _cardDecoration(context, radius: 18, shadow: false),
      child: ListTile(
        leading: _InitialAvatar(label: member.initials),
        title: Text(member.displayName, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(member.roleLabel),
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  final ProjectModel project;

  const _ProjectRow({required this.project});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: _cardDecoration(context, radius: 18, shadow: false),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.folder_copy_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: 19,
          ),
        ),
        title: Text(
          project.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text('${project.statusLabel} - ${project.deadlineLabel}'),
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  final String message;

  const _InlineEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(context, radius: 18, shadow: false),
      child: Text(
        message,
        style: TextStyle(color: _mutedColor(context), fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;

  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _teamCardDecoration(context),
      child: Column(
        children: [
          _TeamIcon(name: title),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _textColor(context),
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: _mutedColor(context), fontWeight: FontWeight.w600),
          ),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 16),
            _GradientButton(label: actionText!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

class _LoadingTeamTile extends StatelessWidget {
  const _LoadingTeamTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _teamCardDecoration(context),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Skeleton(width: 52, height: 52, radius: 18),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Skeleton(width: 190, height: 16, radius: 8),
                    SizedBox(height: 8),
                    _Skeleton(width: 140, height: 12, radius: 8),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _Skeleton(width: double.infinity, height: 8, radius: 8),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _Skeleton({required this.width, required this.height, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _ModalShell extends StatelessWidget {
  final Widget child;

  const _ModalShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: _borderColor(context)),
      ),
      child: child,
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 5,
        decoration: BoxDecoration(
          color: _borderColor(context),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SheetTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: _textColor(context),
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: TextStyle(color: _mutedColor(context), fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      onTap: onTap,
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _GradientButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: onPressed == null ? null : PlanoraTheme.primaryGradientFor(context),
        color: onPressed == null ? _borderColor(context) : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: onPressed == null ? null : PlanoraTheme.floatingShadowFor(context),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.transparent,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(label),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final String label;

  const _CountBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AnimatedIn extends StatelessWidget {
  final int index;
  final Widget child;

  const _AnimatedIn({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 45).clamp(0, 240)),
      curve: Curves.easeOutCubic,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 16),
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

BoxDecoration _cardDecoration(
  BuildContext context, {
  double radius = 24,
  bool shadow = true,
}) {
  return BoxDecoration(
    color: _surfaceColor(context),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: _borderColor(context)),
    boxShadow: shadow ? PlanoraTheme.cardShadowFor(context) : null,
  );
}

BoxDecoration _teamCardDecoration(BuildContext context) {
  final isDark = PlanoraTheme.isDark(context);

  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? const [Color(0xFF1E293B), Color(0xFF151E31)]
          : const [Color(0xFFFFFFFF), Color(0xFFF7F4FF)],
    ),
    borderRadius: BorderRadius.circular(28),
    border: Border.all(
      color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.lavenderBorder,
    ),
    boxShadow: PlanoraTheme.cardShadowFor(context),
  );
}

Color _pageBackground(BuildContext context) {
  return PlanoraTheme.isDark(context)
      ? PlanoraTheme.darkBackground
      : PlanoraTheme.background;
}

Color _surfaceColor(BuildContext context) {
  return PlanoraTheme.isDark(context)
      ? PlanoraTheme.darkSurface
      : PlanoraTheme.surface;
}

Color _subtleFill(BuildContext context) {
  return PlanoraTheme.isDark(context)
      ? PlanoraTheme.darkSurfaceVariant
      : PlanoraTheme.lavenderCard;
}

Color _textColor(BuildContext context) {
  return PlanoraTheme.isDark(context)
      ? PlanoraTheme.darkTextPrimary
      : PlanoraTheme.textPrimary;
}

Color _mutedColor(BuildContext context) {
  return PlanoraTheme.isDark(context)
      ? PlanoraTheme.darkTextMuted
      : PlanoraTheme.textMuted;
}

Color _borderColor(BuildContext context) {
  return PlanoraTheme.isDark(context)
      ? PlanoraTheme.darkBorder
      : PlanoraTheme.border;
}

IconData _teamIcon(String name) {
  final normalized = name.toLowerCase();
  if (normalized.contains('qa') || normalized.contains('test')) {
    return Icons.fact_check_outlined;
  }
  if (normalized.contains('business') || normalized.contains('sales')) {
    return Icons.business_center_outlined;
  }
  if (normalized.contains('design')) return Icons.palette_outlined;
  if (normalized.contains('dev') || normalized.contains('planora')) {
    return Icons.code_rounded;
  }
  if (normalized.contains('invitation')) return Icons.mail_outline_rounded;
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

String _apiMessage(Object error, {required String fallback}) {
  if (error is ApiException && error.message.trim().isNotEmpty) {
    return error.message;
  }
  return fallback;
}
