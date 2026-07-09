import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/planora_theme.dart';
import '../../core/ui/planora_ui.dart';
import '../auth/data/project_api.dart';
import '../auth/models/project_models.dart';
import '../tasks/data/tasks_api.dart';
import '../tasks/models/task_models.dart';
import 'data/teams_api.dart';

enum _TeamAction { details, invite, rename, delete }

class TeamsScreen extends StatefulWidget {
  final TeamsApi teamsApi;
  final ProjectsApi projectsApi;
  final TasksApi tasksApi;

  final bool showBackButton;
  final bool openInvitations;

  final VoidCallback? onTeamsChanged;
  final VoidCallback? onBack;

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
    this.onBack,
  });

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  final TextEditingController searchController = TextEditingController();

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

  List<TeamModel> get visibleTeams {
    final query = searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return teams;
    }

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
            completedTaskCount += tasks
                .where((item) => item.task.isCompleted)
                .length;
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
    final page = PlanoraPage(
      title: 'Teams',
      subtitle: 'Manage members, invitations, and shared plans',
      onBack: widget.showBackButton
          ? () => Navigator.of(context).maybePop()
          : widget.onBack,
      onRefresh: () => loadTeams(showLoading: false),
      padding: EdgeInsets.fromLTRB(
        PlanoraSpacing.pageHorizontal,
        PlanoraSpacing.pageTop,
        PlanoraSpacing.pageHorizontal,
        widget.showBackButton ? PlanoraSpacing.pageBottom : 110,
      ),
      actions: [
        PlanoraIconButton(
          icon: Icons.add_rounded,
          tooltip: 'Create team',
          backgroundColor: Theme.of(context).colorScheme.primary,
          iconColor: Colors.white,
          onTap: openCreateTeamSheet,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchField(
            controller: searchController,
            onChanged: (value) {
              setState(() => searchQuery = value);
            },
            onClear: clearSearch,
          ),
          const SizedBox(height: 14),
          _SegmentedTabs(
            selectedIndex: selectedTab,
            invitationCount: pendingInvitations.length,
            onChanged: (index) {
              setState(() => selectedTab = index);
            },
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
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
    );

    if (!widget.showBackButton) {
      return Material(type: MaterialType.transparency, child: page);
    }

    return PlanoraScaffold(child: page);
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
              ? 'Create a workspace for people, plans, and shared delivery.'
              : 'Try another team, member, role, or plan name.',
          actionText: searchQuery.trim().isEmpty ? 'Create Team' : null,
          onAction: searchQuery.trim().isEmpty ? openCreateTeamSheet : null,
        ),
      ];
    }

    return [
      _SectionHeader(
        title: 'My teams',
        count: visibleTeams.length,
        subtitle: 'Tap a workspace to manage people and plans.',
      ),
      const SizedBox(height: 12),
      for (int index = 0; index < visibleTeams.length; index++) ...[
        _TeamCard(
          team: visibleTeams[index],
          members: membersByTeamId[visibleTeams[index].teamId] ?? const [],
          projects: projectsByTeamId[visibleTeams[index].teamId] ?? const [],
          stats:
              statsByTeamId[visibleTeams[index].teamId] ?? const _TeamStats(),
          currentMember: currentMemberForTeam(visibleTeams[index]),
          canManage: canManageTeam(visibleTeams[index]),
          onTap: () => openTeamDetailsSheet(visibleTeams[index]),
          onMenuPressed: () => openTeamActionsSheet(visibleTeams[index]),
          onInvitePressed: canManageTeam(visibleTeams[index])
              ? () => openInviteMemberSheet(visibleTeams[index])
              : null,
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
          message:
              'Team invitations will appear here when someone invites you.',
        ),
      ];
    }

    return [
      _SectionHeader(
        title: 'Invitations',
        count: pendingInvitations.length,
        subtitle: 'Accept or reject team invitations.',
      ),
      const SizedBox(height: 12),
      for (final invitation in pendingInvitations) ...[
        _InvitationCard(
          invitation: invitation,
          onAccept: () => respondToInvitation(invitation, accept: true),
          onReject: () => respondToInvitation(invitation, accept: false),
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

    if (currentUserId == null) {
      return null;
    }

    for (final member
        in membersByTeamId[team.teamId] ?? const <TeamMemberModel>[]) {
      if (member.userId == currentUserId) {
        return member;
      }
    }

    return null;
  }

  bool canManageTeam(TeamModel team) {
    final currentUserId = widget.currentUserId;

    if (currentUserId != null && team.createdBy == currentUserId) {
      return true;
    }

    final currentMember = currentMemberForTeam(team);

    return currentMember?.role == 'owner' || currentMember?.role == 'admin';
  }

  Future<void> openCreateTeamSheet() async {
    final controller = TextEditingController();
    var isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return _ModalContainer(
              title: 'Create team',
              subtitle:
                  'Start a simple workspace for plans, tasks, and people.',
              child: Column(
                children: [
                  _PlanoraTextField(
                    controller: controller,
                    label: 'Team name',
                    hintText: 'Example: Planora QA Team',
                    icon: Icons.groups_2_outlined,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) async {
                      await submitCreateTeam(
                        controller: controller,
                        setSheetState: setSheetState,
                        sheetContext: sheetContext,
                        isSaving: isSaving,
                        onSavingChanged: (value) => isSaving = value,
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  _PrimarySheetButton(
                    label: isSaving ? 'Creating...' : 'Create Team',
                    isLoading: isSaving,
                    onPressed: isSaving
                        ? null
                        : () async {
                            await submitCreateTeam(
                              controller: controller,
                              setSheetState: setSheetState,
                              sheetContext: sheetContext,
                              isSaving: isSaving,
                              onSavingChanged: (value) => isSaving = value,
                            );
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

  Future<void> submitCreateTeam({
    required TextEditingController controller,
    required StateSetter setSheetState,
    required BuildContext sheetContext,
    required bool isSaving,
    required ValueChanged<bool> onSavingChanged,
  }) async {
    final name = controller.text.trim();

    if (name.isEmpty || isSaving) {
      return;
    }

    setSheetState(() {
      onSavingChanged(true);
    });

    try {
      await widget.teamsApi.createTeam(name);

      if (!mounted || !sheetContext.mounted) {
        return;
      }

      Navigator.of(sheetContext).pop();
      widget.onTeamsChanged?.call();
      await loadTeams(showLoading: false);

      if (!mounted) return;

      showSnack('Team created.');
    } catch (error) {
      if (!mounted || !sheetContext.mounted) {
        return;
      }

      setSheetState(() {
        onSavingChanged(false);
      });

      showSnack(_apiMessage(error, fallback: 'Could not create team.'));
    }
  }

  Future<void> openRenameTeamSheet(TeamModel team) async {
    final controller = TextEditingController(text: team.name);
    var isSaving = false;

    Future<void>? modalClosed;

    final wasRenamed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final route = ModalRoute.of(sheetContext);

        if (route != null) {
          modalClosed ??= route.completed.then<void>((_) {});
        }

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> submitRename() async {
              final name = controller.text.trim();

              if (name.isEmpty || isSaving) {
                return;
              }

              if (name == team.name.trim()) {
                Navigator.of(sheetContext).pop(false);
                return;
              }

              setSheetState(() {
                isSaving = true;
              });

              try {
                await widget.teamsApi.updateTeam(
                  teamId: team.teamId,
                  name: name,
                );

                if (!sheetContext.mounted) {
                  return;
                }

                Navigator.of(sheetContext).pop(true);
              } catch (error) {
                if (!sheetContext.mounted) {
                  return;
                }

                setSheetState(() {
                  isSaving = false;
                });

                showSnack(
                  _apiMessage(error, fallback: 'Could not update team.'),
                );
              }
            }

            return _ModalContainer(
              title: 'Rename team',
              subtitle: 'Update this workspace name.',
              child: Column(
                children: [
                  _PlanoraTextField(
                    controller: controller,
                    label: 'Team name',
                    hintText: 'Team name',
                    icon: Icons.edit_outlined,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) async {
                      await submitRename();
                    },
                  ),
                  const SizedBox(height: 18),
                  _PrimarySheetButton(
                    label: isSaving ? 'Saving...' : 'Save Changes',
                    isLoading: isSaving,
                    onPressed: isSaving
                        ? null
                        : () async {
                            await submitRename();
                          },
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (modalClosed != null) {
      await modalClosed;
    }

    controller.dispose();

    if (wasRenamed != true || !mounted) {
      return;
    }

    widget.onTeamsChanged?.call();
    await loadTeams(showLoading: false);

    if (!mounted) {
      return;
    }

    showSnack('Team updated.');
  }

  Future<void> openInviteMemberSheet(TeamModel team) async {
    final controller = TextEditingController();
    var role = 'member';
    var isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return _ModalContainer(
              title: 'Create an invitation',
              subtitle: 'Give someone a place inside ${team.name}.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _InvitePreviewCard(teamName: team.name, role: role),
                  const SizedBox(height: 20),
                  _PlanoraTextField(
                    controller: controller,
                    label: 'Planora username',
                    hintText: 'Enter their username',
                    icon: Icons.alternate_email_rounded,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 18),
                  _InviteRoleSelector(
                    selectedRole: role,
                    onChanged: (value) {
                      setSheetState(() {
                        role = value;
                      });
                    },
                  ),
                  const SizedBox(height: 22),
                  _PrimarySheetButton(
                    label: isSaving
                        ? 'Sending invitation...'
                        : 'Send special invitation',
                    isLoading: isSaving,
                    onPressed: isSaving
                        ? null
                        : () async {
                            final username = controller.text.trim();

                            if (username.isEmpty) {
                              showSnack('Enter a username first.');
                              return;
                            }

                            setSheetState(() {
                              isSaving = true;
                            });

                            try {
                              await widget.teamsApi.inviteUser(
                                teamId: team.teamId,
                                username: username,
                                role: role,
                              );

                              if (!mounted || !sheetContext.mounted) {
                                return;
                              }

                              Navigator.of(sheetContext).pop();

                              await loadTeams(showLoading: false);

                              if (!mounted) {
                                return;
                              }

                              showSnack('Invitation sent to @$username.');
                            } catch (error) {
                              if (!mounted || !sheetContext.mounted) {
                                return;
                              }

                              setSheetState(() {
                                isSaving = false;
                              });

                              showSnack(
                                _apiMessage(
                                  error,
                                  fallback: 'Could not send invitation.',
                                ),
                              );
                            }
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

  Future<void> openTeamActionsSheet(TeamModel team) async {
    final canManage = canManageTeam(team);

    Future<void>? modalClosed;

    final action = await showModalBottomSheet<_TeamAction>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final route = ModalRoute.of(sheetContext);

        if (route != null) {
          modalClosed ??= route.completed.then<void>((_) {});
        }

        return _ModalContainer(
          title: team.name,
          subtitle: canManage ? 'Manage team workspace.' : 'Team actions',
          child: Column(
            children: [
              _ActionTile(
                icon: Icons.info_outline_rounded,
                title: 'View details',
                subtitle: 'Members, plans, and task progress',
                onTap: () {
                  Navigator.of(sheetContext).pop(_TeamAction.details);
                },
              ),
              if (canManage) ...[
                _ActionTile(
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'Invite member',
                  subtitle: 'Add someone to this team',
                  onTap: () {
                    Navigator.of(sheetContext).pop(_TeamAction.invite);
                  },
                ),
                _ActionTile(
                  icon: Icons.edit_outlined,
                  title: 'Rename team',
                  subtitle: 'Update the workspace name',
                  onTap: () {
                    Navigator.of(sheetContext).pop(_TeamAction.rename);
                  },
                ),
                _ActionTile(
                  icon: Icons.delete_outline_rounded,
                  title: 'Delete team',
                  subtitle: 'Remove this team permanently',
                  isDestructive: true,
                  onTap: () {
                    Navigator.of(sheetContext).pop(_TeamAction.delete);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );

    if (modalClosed != null) {
      await modalClosed;
    }

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _TeamAction.details:
        await openTeamDetailsSheet(team);
        break;

      case _TeamAction.invite:
        await openInviteMemberSheet(team);
        break;

      case _TeamAction.rename:
        await openRenameTeamSheet(team);
        break;

      case _TeamAction.delete:
        await confirmDeleteTeam(team);
        break;
    }
  }

  Future<void> confirmDeleteTeam(TeamModel team) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete team?'),
          content: Text('This will permanently delete "${team.name}".'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: PlanoraTheme.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await widget.teamsApi.deleteTeam(team.teamId);

      if (!mounted) return;

      widget.onTeamsChanged?.call();
      await loadTeams(showLoading: false);

      if (!mounted) return;

      showSnack('Team deleted.');
    } catch (error) {
      if (!mounted) return;

      showSnack(_apiMessage(error, fallback: 'Could not delete team.'));
    }
  }

  Future<void> openTeamDetailsSheet(TeamModel team) async {
    final members = membersByTeamId[team.teamId] ?? const <TeamMemberModel>[];
    final projects = projectsByTeamId[team.teamId] ?? const <ProjectModel>[];
    final stats = statsByTeamId[team.teamId] ?? const _TeamStats();

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _ModalContainer(
          title: team.name,
          subtitle: '${members.length} members • ${projects.length} plans',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DetailMetricRow(stats: stats),
              const SizedBox(height: 18),
              _DetailTitle(title: 'Members', count: members.length),
              const SizedBox(height: 10),
              if (members.isEmpty)
                const _SmallEmptyLine(text: 'No members loaded yet.')
              else
                for (final member in members.take(6)) ...[
                  _MemberLine(member: member),
                  const SizedBox(height: 8),
                ],
              const SizedBox(height: 18),
              _DetailTitle(title: 'Plans', count: projects.length),
              const SizedBox(height: 10),
              if (projects.isEmpty)
                const _SmallEmptyLine(text: 'No plans attached yet.')
              else
                for (final project in projects.take(5)) ...[
                  _ProjectLine(project: project),
                  const SizedBox(height: 8),
                ],
            ],
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

      if (!mounted) return;

      widget.onTeamsChanged?.call();
      await loadTeams(showLoading: false);

      if (!mounted) return;

      showSnack(accept ? 'Invitation accepted.' : 'Invitation declined.');
    } catch (error) {
      if (!mounted) return;

      showSnack(_apiMessage(error, fallback: 'Could not update invitation.'));
    }
  }

  void showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      decoration: _cardDecoration(context, radius: 18),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: TextStyle(
          color: isDark
              ? PlanoraTheme.darkTextPrimary
              : PlanoraTheme.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: 'Search teams, people, roles, or plans...',
          hintStyle: TextStyle(
            color: _mutedColor(context),
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: _mutedColor(context)),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: onClear,
                  icon: Icon(Icons.close_rounded, color: _mutedColor(context)),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
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
      decoration: _cardDecoration(
        context,
        radius: 22,
      ).copyWith(boxShadow: const []),
      child: Row(
        children: [
          Expanded(
            child: _SegmentedTabButton(
              icon: Icons.grid_view_rounded,
              label: 'My Teams',
              isSelected: selectedIndex == 0,
              onTap: () => onChanged(0),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _SegmentedTabButton(
              icon: Icons.mail_outline_rounded,
              label: invitationCount == 0
                  ? 'Invites'
                  : 'Invites $invitationCount',
              isSelected: selectedIndex == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedTabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentedTabButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? PlanoraTheme.primaryGradientFor(context)
              : null,
          color: isSelected
              ? null
              : (isDark
                    ? PlanoraTheme.darkSurfaceVariant
                    : PlanoraTheme.surface),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isSelected
                      ? Colors.white
                      : (isDark
                            ? PlanoraTheme.darkTextSecondary
                            : PlanoraTheme.textSecondary),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final String subtitle;

  const _SectionHeader({
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
                  Flexible(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: PlanoraTheme.isDark(context)
                            ? PlanoraTheme.darkTextPrimary
                            : PlanoraTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CountBadge(value: count),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
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

class _CountBadge extends StatelessWidget {
  final int value;

  const _CountBadge({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value.toString(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  final TeamModel team;
  final List<TeamMemberModel> members;
  final List<ProjectModel> projects;
  final _TeamStats stats;
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
    required this.onInvitePressed,
  });

  @override
  Widget build(BuildContext context) {
    final progress = stats.completionRatio;
    final activePlans = projects.where((project) => project.isActive).length;
    final roleLabel =
        currentMember?.roleLabel ?? (canManage ? 'Admin' : 'Team');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(context, radius: 24).copyWith(
          color: PlanoraTheme.isDark(context)
              ? PlanoraTheme.darkSurface
              : PlanoraTheme.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TeamIcon(name: team.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: PlanoraTheme.isDark(context)
                                    ? PlanoraTheme.darkTextPrimary
                                    : PlanoraTheme.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$activePlans active plans • ${stats.completionPercent}% complete',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: _mutedColor(context),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onMenuPressed,
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: _mutedColor(context),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withOpacity(0.10),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _AvatarStack(members: members),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    members.isEmpty
                        ? 'No members loaded'
                        : members
                              .take(2)
                              .map((member) => member.displayName)
                              .join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: _mutedColor(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (onInvitePressed != null)
                  _InviteMiniButton(onTap: onInvitePressed!),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricPill(
                  icon: Icons.people_outline_rounded,
                  label: '${stats.memberCount} People',
                ),
                _MetricPill(
                  icon: Icons.folder_copy_outlined,
                  label: '${stats.projectCount} Plans',
                ),
                _MetricPill(
                  icon: Icons.check_box_outlined,
                  label: '${stats.taskCount} Tasks',
                ),
                _MetricPill(
                  icon: Icons.verified_user_outlined,
                  label: roleLabel,
                ),
              ],
            ),
          ],
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
      child: Icon(
        name.toLowerCase().contains('business')
            ? Icons.business_center_rounded
            : Icons.groups_2_rounded,
        color: Colors.white,
        size: 25,
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
      return const _SmallAvatar(label: '?', muted: true);
    }

    final visible = members.take(3).toList();

    return SizedBox(
      width: 28.0 + ((visible.length - 1) * 18.0),
      height: 30,
      child: Stack(
        children: [
          for (int index = 0; index < visible.length; index++)
            Positioned(
              left: index * 18,
              child: _SmallAvatar(label: visible[index].initials),
            ),
        ],
      ),
    );
  }
}

class _SmallAvatar extends StatelessWidget {
  final String label;
  final bool muted;

  const _SmallAvatar({required this.label, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: muted
            ? Theme.of(context).colorScheme.primary.withOpacity(0.10)
            : Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
        border: Border.all(color: _surfaceColor(context), width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: muted ? Theme.of(context).colorScheme.primary : Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InviteMiniButton extends StatelessWidget {
  final VoidCallback onTap;

  const _InviteMiniButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
      label: const Text('Invite'),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetricPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: isDark
            ? PlanoraTheme.darkSurfaceVariant
            : PlanoraTheme.lavenderCard,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.lavenderBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isDark
                  ? PlanoraTheme.darkTextSecondary
                  : PlanoraTheme.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvitePreviewCard extends StatelessWidget {
  final String teamName;
  final String role;

  const _InvitePreviewCard({required this.teamName, required this.role});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.94 + (value * 0.06),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: PlanoraTheme.primaryGradientFor(context),
          borderRadius: BorderRadius.circular(24),
          boxShadow: PlanoraTheme.floatingShadowFor(context),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -35,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.09),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: -30,
              bottom: -55,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PLANORA INVITATION',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white.withOpacity(0.72),
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          teamName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'A new place to plan and collaborate.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white.withOpacity(0.72),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _roleLabel(role),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteRoleSelector extends StatelessWidget {
  final String selectedRole;
  final ValueChanged<String> onChanged;

  const _InviteRoleSelector({
    required this.selectedRole,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose their role',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: isDark
                ? PlanoraTheme.darkTextPrimary
                : PlanoraTheme.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'You can change the role later.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: _mutedColor(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _InviteRoleOption(
                icon: Icons.person_outline_rounded,
                title: 'Member',
                subtitle: 'Collaborate on plans and tasks',
                value: 'member',
                selectedRole: selectedRole,
                onTap: () => onChanged('member'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InviteRoleOption(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Admin',
                subtitle: 'Manage people and workspace',
                value: 'admin',
                selectedRole: selectedRole,
                onTap: () => onChanged('admin'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InviteRoleOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final String selectedRole;
  final VoidCallback onTap;

  const _InviteRoleOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.selectedRole,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedRole == value;
    final isDark = PlanoraTheme.isDark(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(isDark ? 0.20 : 0.10)
              : isDark
              ? PlanoraTheme.darkSurfaceVariant
              : PlanoraTheme.lavenderCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : isDark
                ? PlanoraTheme.darkBorder
                : PlanoraTheme.lavenderBorder,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: primaryColor, size: 20),
                ),
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 21,
                  height: 21,
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? primaryColor : _mutedColor(context),
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 14,
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: isDark
                    ? PlanoraTheme.darkTextPrimary
                    : PlanoraTheme.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: _mutedColor(context),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
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
    final isDark = PlanoraTheme.isDark(context);

    final expiryText = invitation.expiresAt == null
        ? 'Respond whenever you are ready'
        : 'Valid until ${_formatInvitationDate(invitation.expiresAt!)}';

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
          borderRadius: BorderRadius.circular(27),
          border: Border.all(
            color: isDark
                ? PlanoraTheme.darkBorder
                : PlanoraTheme.lavenderBorder,
          ),
          boxShadow: PlanoraTheme.softCardShadowFor(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 17, 18, 16),
              decoration: BoxDecoration(
                gradient: PlanoraTheme.primaryGradientFor(context),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -22,
                    top: -28,
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.18),
                          ),
                        ),
                        child: const Icon(
                          Icons.mark_email_unread_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'YOU ARE INVITED',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Colors.white.withOpacity(0.72),
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.3,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'A team saved you a seat',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _roleLabel(invitation.role),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 19),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Team #${invitation.teamId}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: isDark
                          ? PlanoraTheme.darkTextPrimary
                          : PlanoraTheme.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Join the workspace, meet the team, and start planning together.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _mutedColor(context),
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 17),
                  const _InvitationDashedDivider(),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 17,
                        color: _mutedColor(context),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          expiryText,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: _mutedColor(context),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      Text(
                        '#${invitation.invitationId}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onReject,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 50),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(child: _InvitationAcceptButton(onTap: onAccept)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvitationAcceptButton extends StatelessWidget {
  final VoidCallback onTap;

  const _InvitationAcceptButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: PlanoraTheme.primaryGradientFor(context),
        borderRadius: BorderRadius.circular(18),
        boxShadow: PlanoraTheme.floatingShadowFor(context),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Accept invite',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 7),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvitationDashedDivider extends StatelessWidget {
  const _InvitationDashedDivider();

  @override
  Widget build(BuildContext context) {
    final dividerColor = PlanoraTheme.isDark(context)
        ? PlanoraTheme.darkBorder
        : PlanoraTheme.lavenderBorder;

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / 12).floor().clamp(1, 50).toInt();

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(width: 6, height: 1, color: dividerColor),
          ),
        );
      },
    );
  }
}

class _LoadingTeamTile extends StatelessWidget {
  const _LoadingTeamTile();

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      height: 146,
      decoration: _cardDecoration(context, radius: 24),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const _SkeletonBox(width: 52, height: 52, radius: 18),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  children: [
                    _SkeletonBox(width: double.infinity, height: 14, radius: 8),
                    SizedBox(height: 8),
                    _SkeletonBox(width: double.infinity, height: 12, radius: 8),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          _SkeletonBox(
            width: double.infinity,
            height: 42,
            radius: 16,
            color: isDark
                ? PlanoraTheme.darkSurfaceVariant
                : PlanoraTheme.lavenderCard,
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final Color? color;

  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.radius,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color:
            color ??
            (PlanoraTheme.isDark(context)
                ? PlanoraTheme.darkSurfaceVariant
                : PlanoraTheme.surfaceVariant),
        borderRadius: BorderRadius.circular(radius),
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
      decoration: _cardDecoration(context, radius: 24),
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _mutedColor(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionText!)),
          ],
        ],
      ),
    );
  }
}

class _ModalContainer extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ModalContainer({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isDark = PlanoraTheme.isDark(context);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(
            color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
          ),
          boxShadow: PlanoraTheme.softCardShadowFor(context),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark
                        ? PlanoraTheme.darkBorder
                        : PlanoraTheme.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: isDark
                      ? PlanoraTheme.darkTextPrimary
                      : PlanoraTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _mutedColor(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanoraTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const _PlanoraTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      decoration: _fieldDecoration(
        context,
        label: label,
        hintText: hintText,
        icon: icon,
      ),
    );
  }
}

class _PrimarySheetButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _PrimarySheetButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? PlanoraTheme.error
        : Theme.of(context).colorScheme.primary;

    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? PlanoraTheme.error : null,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(subtitle),
    );
  }
}

class _DetailMetricRow extends StatelessWidget {
  final _TeamStats stats;

  const _DetailMetricRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricPill(
            icon: Icons.people_outline_rounded,
            label: '${stats.memberCount} People',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricPill(
            icon: Icons.folder_copy_outlined,
            label: '${stats.projectCount} Plans',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricPill(
            icon: Icons.check_box_outlined,
            label: '${stats.taskCount} Tasks',
          ),
        ),
      ],
    );
  }
}

class _DetailTitle extends StatelessWidget {
  final String title;
  final int count;

  const _DetailTitle({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(width: 8),
        _CountBadge(value: count),
      ],
    );
  }
}

class _MemberLine extends StatelessWidget {
  final TeamMemberModel member;

  const _MemberLine({required this.member});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PlanoraTheme.isDark(context)
            ? PlanoraTheme.darkSurfaceVariant
            : PlanoraTheme.lavenderCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _SmallAvatar(label: member.initials),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              member.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            member.roleLabel,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectLine extends StatelessWidget {
  final ProjectModel project;

  const _ProjectLine({required this.project});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PlanoraTheme.isDark(context)
            ? PlanoraTheme.darkSurfaceVariant
            : PlanoraTheme.lavenderCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.folder_copy_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              project.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            project.statusLabel,
            style: TextStyle(
              color: _mutedColor(context),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallEmptyLine extends StatelessWidget {
  final String text;

  const _SmallEmptyLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: _mutedColor(context),
        fontWeight: FontWeight.w700,
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
    this.memberCount = 0,
    this.projectCount = 0,
    this.taskCount = 0,
    this.completedTaskCount = 0,
  });

  double get completionRatio {
    if (taskCount == 0) {
      return 0;
    }

    return completedTaskCount / taskCount;
  }

  int get completionPercent {
    if (taskCount == 0) {
      return 0;
    }

    return (completionRatio * 100).round();
  }
}

InputDecoration _fieldDecoration(
  BuildContext context, {
  required String label,
  String? hintText,
  required IconData icon,
}) {
  final isDark = PlanoraTheme.isDark(context);

  return InputDecoration(
    labelText: label,
    hintText: hintText,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: isDark ? PlanoraTheme.darkSurfaceVariant : PlanoraTheme.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
      ),
    ),
  );
}

BoxDecoration _cardDecoration(BuildContext context, {double radius = 20}) {
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

Color _surfaceColor(BuildContext context) {
  return PlanoraTheme.isDark(context)
      ? PlanoraTheme.darkSurface
      : PlanoraTheme.surface;
}

Color _mutedColor(BuildContext context) {
  return PlanoraTheme.isDark(context)
      ? PlanoraTheme.darkTextMuted
      : PlanoraTheme.textMuted;
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

String _formatInvitationDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _apiMessage(Object error, {required String fallback}) {
  if (error is ApiException && error.message.trim().isNotEmpty) {
    return error.message;
  }

  return fallback;
}
