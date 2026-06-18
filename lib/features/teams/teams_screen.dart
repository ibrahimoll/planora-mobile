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
              invitationCount: pendingInvitations.length,
            ),
          ),
          const SizedBox(height: 16),
          _Entrance(
            index: 1,
            child: _SearchField(
              controller: searchController,
              onChanged: (value) => setState(() => searchQuery = value),
              onClear: clearSearch,
            ),
          ),
          const SizedBox(height: 12),
          _Entrance(
            index: 2,
            child: _TeamTabs(
              selectedIndex: selectedTab,
              invitationCount: pendingInvitations.length,
              onChanged: (index) => setState(() => selectedTab = index),
            ),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: selectedTab == 0
                ? Column(
                    key: const ValueKey('teams'),
                    children: buildTeamContent(),
                  )
                : Column(
                    key: const ValueKey('invitations'),
                    children: buildInvitationContent(),
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
        _StateCard(
          icon: Icons.groups_2_outlined,
          title: searchQuery.trim().isEmpty ? 'No teams yet' : 'No teams found',
          message: searchQuery.trim().isEmpty
              ? 'Create your first workspace and keep team plans in one place.'
              : 'Try another team, member, or plan name.',
          actionText: searchQuery.trim().isEmpty ? 'Create Team' : null,
          onAction: searchQuery.trim().isEmpty ? openCreateTeamSheet : null,
        ),
      ];
    }

    return [
      _SectionHeader(count: visibleTeams.length),
      const SizedBox(height: 10),
      for (int index = 0; index < visibleTeams.length; index++) ...[
        _Entrance(
          index: index + 3,
          child: _TeamCard(
            team: visibleTeams[index],
            members: membersByTeamId[visibleTeams[index].teamId] ?? const [],
            projects: projectsByTeamId[visibleTeams[index].teamId] ?? const [],
            stats: statsByTeamId[visibleTeams[index].teamId],
            currentMember: currentMemberForTeam(visibleTeams[index]),
            canManage: canManageTeam(visibleTeams[index]),
            onTap: () => openTeamDetailsSheet(visibleTeams[index]),
            onInvitePressed: canManageTeam(visibleTeams[index])
                ? () => openInviteMemberSheet(visibleTeams[index])
                : null,
            onMenuPressed: () => openTeamActionsSheet(visibleTeams[index]),
          ),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  List<Widget> buildInvitationContent() {
    if (isLoading && invitations.isEmpty) {
      return const [_TeamLoadingCard()];
    }

    if (pendingInvitations.isEmpty) {
      return const [
        _StateCard(
          icon: Icons.mail_outline_rounded,
          title: 'No invitations',
          message: 'Team invitations will appear here when someone invites you.',
        ),
      ];
    }

    return [
      for (int index = 0; index < pendingInvitations.length; index++) ...[
        _Entrance(
          index: index,
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
      title: 'Create team',
      subtitle: 'Start a clean workspace for people, plans, and delivery.',
      initialName: '',
      buttonLabel: 'Create Team',
      loadingLabel: 'Creating...',
      onSubmit: (name) async {
        await widget.teamsApi.createTeam(name);
        await reloadAfterMutation('Team created.');
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
            return _BottomSheetShell(
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
                      onSubmitted: (_) => submitTeamName(
                        sheetContext,
                        setSheetState,
                        controller,
                        isSubmitting,
                        (value) => isSubmitting = value,
                        onSubmit,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _PrimaryButton(
                      label: isSubmitting ? loadingLabel : buttonLabel,
                      onPressed: isSubmitting
                          ? null
                          : () => submitTeamName(
                                sheetContext,
                                setSheetState,
                                controller,
                                isSubmitting,
                                (value) => isSubmitting = value,
                                onSubmit,
                              ),
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

  Future<void> submitTeamName(
    BuildContext sheetContext,
    StateSetter setSheetState,
    TextEditingController controller,
    bool isSubmitting,
    ValueChanged<bool> setSubmitting,
    Future<void> Function(String name) onSubmit,
  ) async {
    if (isSubmitting) return;
    final name = controller.text.trim();
    if (name.length < 2) {
      showMessage('Team name must be at least 2 characters.');
      return;
    }

    setSheetState(() => setSubmitting(true));

    try {
      await onSubmit(name);
      if (!sheetContext.mounted) return;
      Navigator.of(sheetContext).pop();
    } catch (error, stackTrace) {
      debugPrint('Team name submit failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!sheetContext.mounted) return;
      showMessage(_apiMessage(error, fallback: 'Could not save team.'));
      setSheetState(() => setSubmitting(false));
    }
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
            return _BottomSheetShell(
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
                      subtitle: 'Send an invite to ${team.name} by username.',
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
                    _PrimaryButton(
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
                                  _apiMessage(error, fallback: 'Could not send invitation.'),
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
        return _BottomSheetShell(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SheetHandle(),
                  const SizedBox(height: 10),
                  ListTile(
                    leading: const Icon(Icons.open_in_new_rounded),
                    title: const Text('Open team'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      openTeamDetailsSheet(team);
                    },
                  ),
                  if (canManage)
                    ListTile(
                      leading: const Icon(Icons.person_add_alt_1_rounded),
                      title: const Text('Invite member'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        openInviteMemberSheet(team);
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

  void openTeamDetailsSheet(TeamModel team) {
    final members = membersByTeamId[team.teamId] ?? const <TeamMemberModel>[];
    final projects = projectsByTeamId[team.teamId] ?? const <ProjectModel>[];
    final stats = statsByTeamId[team.teamId] ?? const _TeamStats();
    final canManage = canManageTeam(team);
    final currentMember = currentMemberForTeam(team);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _BottomSheetShell(
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
                  _TeamDetailHero(
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
                  _SheetSectionTitle(title: 'Members', trailing: '${members.length}'),
                  const SizedBox(height: 8),
                  if (members.isEmpty)
                    const _EmptyInlinePanel(message: 'No members loaded yet.')
                  else
                    for (final member in members) _MemberRow(member: member),
                  const SizedBox(height: 18),
                  _SheetSectionTitle(title: 'Plans', trailing: '${projects.length}'),
                  const SizedBox(height: 8),
                  if (projects.isEmpty)
                    const _EmptyInlinePanel(message: 'No team plans yet.')
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
      await reloadAfterMutation(accept ? 'Invitation accepted.' : 'Invitation declined.');
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

class _TeamsHero extends StatelessWidget {
  final bool showBackButton;
  final VoidCallback onBackPressed;
  final VoidCallback onCreatePressed;
  final int teamCount;
  final int memberCount;
  final int projectCount;
  final int taskCount;
  final int invitationCount;

  const _TeamsHero({
    required this.showBackButton,
    required this.onBackPressed,
    required this.onCreatePressed,
    required this.teamCount,
    required this.memberCount,
    required this.projectCount,
    required this.taskCount,
    required this.invitationCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF1A1238), Color(0xFF0F172A)]
              : const [Color(0xFFFFFFFF), Color(0xFFF7F2FF)],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: _borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: isDark ? 0.20 : 0.11),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showBackButton) ...[
                _CircleIconButton(icon: Icons.arrow_back_rounded, onPressed: onBackPressed),
                const SizedBox(width: 10),
              ],
              _BrandTile(icon: Icons.groups_2_rounded, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Teams',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: _textColor(context),
                            height: 1.05,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Clean workspaces for people, plans, and shared delivery.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _mutedColor(context),
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _AddButton(onPressed: onCreatePressed),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.045)
                  : Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _borderColor(context)),
            ),
            child: Row(
              children: [
                Expanded(child: _HeroMetric(label: 'Teams', value: '$teamCount', icon: Icons.groups_2_outlined)),
                _MetricDivider(isDark: isDark),
                Expanded(child: _HeroMetric(label: 'People', value: '$memberCount', icon: Icons.people_alt_outlined)),
                _MetricDivider(isDark: isDark),
                Expanded(child: _HeroMetric(label: 'Plans', value: '$projectCount', icon: Icons.folder_copy_outlined)),
                _MetricDivider(isDark: isDark),
                Expanded(child: _HeroMetric(label: 'Tasks', value: '$taskCount', icon: Icons.checklist_rounded)),
              ],
            ),
          ),
          if (invitationCount > 0) ...[
            const SizedBox(height: 12),
            _InviteBanner(count: invitationCount),
          ],
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  final bool isDark;
  const _MetricDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFEAE7F7),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _HeroMetric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(color: _textColor(context), fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 1),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _mutedColor(context), fontSize: 10, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _InviteBanner extends StatelessWidget {
  final int count;
  const _InviteBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.mail_outline_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text('$count pending invitation${count == 1 ? '' : 's'}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({required this.controller, required this.onChanged, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      radius: 22,
      padding: EdgeInsets.zero,
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
              return IconButton(onPressed: onClear, icon: Icon(Icons.close_rounded, color: _mutedColor(context)));
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        ),
      ),
    );
  }
}

class _TeamTabs extends StatelessWidget {
  final int selectedIndex;
  final int invitationCount;
  final ValueChanged<int> onChanged;

  const _TeamTabs({required this.selectedIndex, required this.invitationCount, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      radius: 22,
      padding: const EdgeInsets.all(5),
      shadow: false,
      child: Row(
        children: [
          _TabButton(label: 'My Teams', selected: selectedIndex == 0, onTap: () => onChanged(0)),
          _TabButton(label: invitationCount > 0 ? 'Invitations ($invitationCount)' : 'Invitations', selected: selectedIndex == 1, onTap: () => onChanged(1)),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: selected ? primary.withValues(alpha: 0.14) : Colors.transparent, borderRadius: BorderRadius.circular(17)),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: selected ? primary : _mutedColor(context), fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final int count;
  const _SectionHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Workspaces', style: TextStyle(color: _textColor(context), fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(width: 8),
        _SmallBadge(label: '$count'),
        const Spacer(),
        Icon(Icons.touch_app_outlined, size: 16, color: _mutedColor(context)),
        const SizedBox(width: 5),
        Text('Tap to manage', style: TextStyle(color: _mutedColor(context), fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _TeamCard extends StatelessWidget {
  final TeamModel team;
  final List<TeamMemberModel> members;
  final List<ProjectModel> projects;
  final _TeamStats? stats;
  final TeamMemberModel? currentMember;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback onMenuPressed;
  final VoidCallback? onInvitePressed;

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

  @override
  Widget build(BuildContext context) {
    final safeStats = stats ?? const _TeamStats();
    final activeProjects = projects.where((item) => item.isActive).length;
    final progressPercent = (safeStats.progress * 100).round();

    return _SurfaceCard(
      radius: 28,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _BrandTile(icon: _teamIcon(team.name), size: 52),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(team.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _textColor(context), fontSize: 17, height: 1.1, fontWeight: FontWeight.w900))),
                              if (currentMember != null) ...[
                                const SizedBox(width: 8),
                                _RolePill(label: currentMember!.roleLabel),
                              ],
                            ],
                          ),
                          const SizedBox(height: 7),
                          Text('$activeProjects active plans • $progressPercent% task completion', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _mutedColor(context), fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(tooltip: 'Team actions', onPressed: onMenuPressed, icon: Icon(Icons.more_horiz_rounded, color: _mutedColor(context))),
                  ],
                ),
                const SizedBox(height: 14),
                _ProgressLine(value: safeStats.progress),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _AvatarStack(members: members),
                    const SizedBox(width: 10),
                    Expanded(child: Text(members.isEmpty ? 'No members loaded' : members.take(2).map((item) => item.displayName).join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _mutedColor(context), fontSize: 12, fontWeight: FontWeight.w700))),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _MetricChip(icon: Icons.people_outline_rounded, value: '${safeStats.memberCount}'),
                    const SizedBox(width: 8),
                    _MetricChip(icon: Icons.folder_copy_outlined, value: '${safeStats.projectCount}'),
                    const SizedBox(width: 8),
                    _MetricChip(icon: Icons.check_box_outlined, value: '${safeStats.taskCount}'),
                    const Spacer(),
                    if (canManage && onInvitePressed != null)
                      _GhostButton(label: 'Invite', icon: Icons.person_add_alt_1_rounded, onTap: onInvitePressed!),
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

class _InvitationCard extends StatelessWidget {
  final TeamInvitationModel invitation;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _InvitationCard({required this.invitation, required this.onAccept, required this.onReject});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _BrandTile(icon: Icons.mail_outline_rounded, size: 50),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Team invitation', style: TextStyle(color: _textColor(context), fontSize: 17, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('Role: ${_roleLabel(invitation.role)}', style: TextStyle(color: _mutedColor(context), fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: onReject, child: const Text('Decline'))),
              const SizedBox(width: 10),
              Expanded(child: _PrimaryButton(label: 'Accept', onPressed: onAccept)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamDetailHero extends StatelessWidget {
  final TeamModel team;
  final _TeamStats stats;
  final TeamMemberModel? currentMember;
  final bool canManage;
  final VoidCallback onInvitePressed;

  const _TeamDetailHero({required this.team, required this.stats, required this.currentMember, required this.canManage, required this.onInvitePressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: PlanoraTheme.softPurpleGradientFor(context), borderRadius: BorderRadius.circular(26), border: Border.all(color: _borderColor(context))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _BrandTile(icon: _teamIcon(team.name), size: 54),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(team.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _textColor(context), fontSize: 19, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(currentMember == null ? 'Shared workspace' : 'Your role: ${currentMember!.roleLabel}', style: TextStyle(color: _mutedColor(context), fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              if (canManage) IconButton.filledTonal(tooltip: 'Invite member', onPressed: onInvitePressed, icon: const Icon(Icons.person_add_alt_1_rounded)),
            ],
          ),
          const SizedBox(height: 16),
          _ProgressLine(value: stats.progress),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _DetailMetric(label: 'Members', value: '${stats.memberCount}', icon: Icons.people_outline_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _DetailMetric(label: 'Plans', value: '${stats.projectCount}', icon: Icons.folder_copy_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _DetailMetric(label: 'Tasks', value: '${stats.taskCount}', icon: Icons.check_box_outlined)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailMetric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 18),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(color: _textColor(context), fontWeight: FontWeight.w900, fontSize: 16)),
          Text(label, style: TextStyle(color: _mutedColor(context), fontWeight: FontWeight.w800, fontSize: 10)),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;

  const _StateCard({required this.icon, required this.title, required this.message, this.actionText, this.onAction});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      radius: 30,
      child: Column(
        children: [
          _BrandTile(icon: icon, size: 58),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: TextStyle(color: _textColor(context), fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: _mutedColor(context), fontWeight: FontWeight.w600)),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 16),
            _PrimaryButton(label: actionText!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

class _TeamLoadingCard extends StatelessWidget {
  const _TeamLoadingCard();

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              _SkeletonBox(width: 52, height: 52, radius: 18),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBox(width: 190, height: 16, radius: 8),
                    SizedBox(height: 8),
                    _SkeletonBox(width: 140, height: 12, radius: 8),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _SkeletonBox(width: double.infinity, height: 8, radius: 8),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBox({required this.width, required this.height, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: PlanoraTheme.isDark(context) ? const Color(0xFF334155) : const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(radius)),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool shadow;

  const _SurfaceCard({required this.child, this.radius = 24, this.padding = const EdgeInsets.all(16), this.shadow = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: _surfaceColor(context), borderRadius: BorderRadius.circular(radius), border: Border.all(color: _borderColor(context)), boxShadow: shadow ? PlanoraTheme.cardShadowFor(context) : null),
      child: child,
    );
  }
}

class _BrandTile extends StatelessWidget {
  final IconData icon;
  final double size;

  const _BrandTile({required this.icon, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)]),
        borderRadius: BorderRadius.circular(size * 0.34),
        boxShadow: const [BoxShadow(color: Color(0x337C3AED), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.50),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _AddButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Ink(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]),
            borderRadius: BorderRadius.circular(18),
            boxShadow: PlanoraTheme.floatingShadowFor(context),
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _CircleIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(onPressed: onPressed, icon: Icon(icon));
  }
}

class _ProgressLine extends StatelessWidget {
  final double value;
  const _ProgressLine({required this.value});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 8,
        backgroundColor: PlanoraTheme.isDark(context) ? const Color(0xFF334155) : const Color(0xFFEDE9FE),
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  final List<TeamMemberModel> members;
  const _AvatarStack({required this.members});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox(width: 34, height: 34, child: _EmptyAvatar());
    final visible = members.take(3).toList();
    return SizedBox(
      width: 34.0 + ((visible.length - 1) * 22),
      height: 34,
      child: Stack(
        children: [
          for (int index = 0; index < visible.length; index++)
            Positioned(left: index * 22.0, child: _InitialAvatar(label: visible[index].initials)),
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
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)]), shape: BoxShape.circle, border: Border.all(color: _surfaceColor(context), width: 2)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }
}

class _EmptyAvatar extends StatelessWidget {
  const _EmptyAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(alignment: Alignment.center, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10), shape: BoxShape.circle), child: Icon(Icons.person_outline_rounded, color: Theme.of(context).colorScheme.primary, size: 18));
  }
}

class _RolePill extends StatelessWidget {
  final String label;
  const _RolePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String value;
  const _MetricChip({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: PlanoraTheme.isDark(context) ? const Color(0xFF273449) : const Color(0xFFF8F5FF), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: _mutedColor(context)), const SizedBox(width: 5), Text(value, style: TextStyle(color: _textColor(context), fontSize: 12, fontWeight: FontWeight.w900))]),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _GhostButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 15, color: primary), const SizedBox(width: 5), Text(label, style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w900))]),
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;
  const _SmallBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)), child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w900)));
  }
}

class _MemberRow extends StatelessWidget {
  final TeamMemberModel member;
  const _MemberRow({required this.member});

  @override
  Widget build(BuildContext context) {
    return ListTile(contentPadding: EdgeInsets.zero, leading: _InitialAvatar(label: member.initials), title: Text(member.displayName, style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text(member.roleLabel));
  }
}

class _ProjectRow extends StatelessWidget {
  final ProjectModel project;
  const _ProjectRow({required this.project});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.folder_copy_outlined, color: Theme.of(context).colorScheme.primary, size: 19)),
      title: Text(project.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text('${project.statusLabel} • ${project.deadlineLabel}'),
    );
  }
}

class _SheetSectionTitle extends StatelessWidget {
  final String title;
  final String trailing;
  const _SheetSectionTitle({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))), _SmallBadge(label: trailing)]);
  }
}

class _EmptyInlinePanel extends StatelessWidget {
  final String message;
  const _EmptyInlinePanel({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: PlanoraTheme.isDark(context) ? const Color(0xFF273449) : const Color(0xFFF8F5FF), borderRadius: BorderRadius.circular(18)), child: Text(message, style: TextStyle(color: _mutedColor(context), fontWeight: FontWeight.w700)));
  }
}

class _BottomSheetShell extends StatelessWidget {
  final Widget child;
  const _BottomSheetShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(decoration: BoxDecoration(color: _surfaceColor(context), borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), border: Border.all(color: _borderColor(context))), child: child);
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: _borderColor(context), borderRadius: BorderRadius.circular(999))));
  }
}

class _SheetTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SheetTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(subtitle, style: TextStyle(color: _mutedColor(context), fontWeight: FontWeight.w600))]);
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const _PrimaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: onPressed == null ? null : PlanoraTheme.primaryGradientFor(context), color: onPressed == null ? _borderColor(context) : null, borderRadius: BorderRadius.circular(16), boxShadow: onPressed == null ? null : PlanoraTheme.floatingShadowFor(context)),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(elevation: 0, shadowColor: Colors.transparent, backgroundColor: Colors.transparent, foregroundColor: Colors.white, disabledBackgroundColor: Colors.transparent, minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: Text(label),
      ),
    );
  }
}

class _Entrance extends StatelessWidget {
  final int index;
  final Widget child;
  const _Entrance({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (index * 38).clamp(0, 220)),
      curve: Curves.easeOutCubic,
      builder: (context, value, animatedChild) {
        return Opacity(opacity: value, child: Transform.translate(offset: Offset(0, (1 - value) * 14), child: animatedChild));
      },
      child: child,
    );
  }
}

Color _surfaceColor(BuildContext context) {
  return PlanoraTheme.isDark(context) ? PlanoraTheme.darkSurface : PlanoraTheme.surface;
}

Color _textColor(BuildContext context) {
  return PlanoraTheme.isDark(context) ? PlanoraTheme.darkTextPrimary : PlanoraTheme.textPrimary;
}

Color _mutedColor(BuildContext context) {
  return PlanoraTheme.isDark(context) ? PlanoraTheme.darkTextMuted : PlanoraTheme.textMuted;
}

Color _borderColor(BuildContext context) {
  return PlanoraTheme.isDark(context) ? PlanoraTheme.darkBorder : PlanoraTheme.border;
}

IconData _teamIcon(String name) {
  final normalized = name.toLowerCase();
  if (normalized.contains('qa') || normalized.contains('test')) return Icons.fact_check_outlined;
  if (normalized.contains('business') || normalized.contains('sales')) return Icons.business_center_outlined;
  if (normalized.contains('design')) return Icons.palette_outlined;
  if (normalized.contains('dev') || normalized.contains('planora')) return Icons.code_rounded;
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
  if (error is ApiException && error.message.trim().isNotEmpty) return error.message;
  return fallback;
}
