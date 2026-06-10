import 'package:flutter/material.dart';

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
  final VoidCallback? onTeamsChanged;

  const TeamsScreen({
    super.key,
    this.teamsApi = const TeamsApi(),
    this.projectsApi = const ProjectsApi(),
    this.tasksApi = const TasksApi(),
    this.showBackButton = true,
    this.onTeamsChanged,
  });

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  late final TeamsApi _teamsApi;
  late final ProjectsApi _projectsApi;
  late final TasksApi _tasksApi;
  final TextEditingController _teamNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  bool isLoading = true;
  bool isCreatingTeam = false;
  bool isInviting = false;
  bool isLoadingWorkload = false;
  int? updatingInvitationId;
  String? errorMessage;
  String? workloadMessage;
  List<TeamModel> teams = [];
  List<TeamInvitationModel> invitations = [];
  List<TeamMemberModel> members = [];
  Map<int, TeamMemberWorkload> workloadByUserId = {};
  TeamModel? selectedTeam;

  @override
  void initState() {
    super.initState();
    _teamsApi = widget.teamsApi;
    _projectsApi = widget.projectsApi;
    _tasksApi = widget.tasksApi;
    loadTeams();
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> loadTeams() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      workloadMessage = null;
    });

    try {
      final loadedTeams = await _teamsApi.getTeams();
      final loadedInvitations = await _teamsApi.getMyInvitations();
      final nextSelectedTeam = loadedTeams.isEmpty
          ? null
          : selectedTeam == null
          ? loadedTeams.first
          : loadedTeams.firstWhere(
              (team) => team.teamId == selectedTeam!.teamId,
              orElse: () => loadedTeams.first,
            );
      final loadedMembers = nextSelectedTeam == null
          ? <TeamMemberModel>[]
          : await _teamsApi.getTeamMembers(nextSelectedTeam.teamId);
      final loadedWorkload = nextSelectedTeam == null
          ? <int, TeamMemberWorkload>{}
          : await loadTeamWorkloadData(nextSelectedTeam);

      if (!mounted) {
        return;
      }

      setState(() {
        teams = loadedTeams;
        invitations = loadedInvitations
            .where((invitation) => invitation.isPending)
            .toList();
        selectedTeam = nextSelectedTeam;
        members = loadedMembers;
        workloadByUserId = loadedWorkload;
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Teams load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        errorMessage = 'Could not load teams and invitations.';
        workloadByUserId = {};
      });
    }
  }

  Future<void> selectTeam(TeamModel team) async {
    setState(() {
      selectedTeam = team;
      members = [];
      workloadByUserId = {};
      workloadMessage = null;
      isLoadingWorkload = true;
    });

    try {
      final loadedMembers = await _teamsApi.getTeamMembers(team.teamId);
      final loadedWorkload = await loadTeamWorkloadData(team);

      if (!mounted) {
        return;
      }

      setState(() {
        members = loadedMembers;
        workloadByUserId = loadedWorkload;
        isLoadingWorkload = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Team members load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        isLoadingWorkload = false;
        workloadMessage = 'Could not load team workload.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load team members.')),
      );
    }
  }

  Future<Map<int, TeamMemberWorkload>> loadTeamWorkloadData(
    TeamModel team,
  ) async {
    try {
      final teamProjects = await _projectsApi.getTeamProjects(team.teamId);
      final workloads = <int, TeamMemberWorkload>{};

      for (final project in teamProjects) {
        final tasks = await _tasksApi.getProjectTasks(
          project: TaskProjectSummary.fromProject(project),
        );

        for (final item in tasks) {
          final userId = item.task.assignedTo;

          if (userId == null) {
            continue;
          }

          final current = workloads[userId] ?? const TeamMemberWorkload();
          workloads[userId] = current.addTask(item.task);
        }
      }

      return workloads;
    } catch (error, stackTrace) {
      debugPrint('Team workload load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        setState(() {
          workloadMessage = 'Could not load team workload.';
        });
      }

      return {};
    }
  }

  Future<void> createTeam() async {
    final name = _teamNameController.text.trim();

    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team name must be at least 2 letters.')),
      );
      return;
    }

    setState(() {
      isCreatingTeam = true;
    });

    try {
      final team = await _teamsApi.createTeam(name);

      if (!mounted) {
        return;
      }

      _teamNameController.clear();
      setState(() {
        teams = [team, ...teams];
        selectedTeam = team;
        members = [];
        isCreatingTeam = false;
      });

      await selectTeam(team);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Team created.')));
      widget.onTeamsChanged?.call();
    } catch (error, stackTrace) {
      debugPrint('Team creation failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        isCreatingTeam = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create team. Try again.')),
      );
    }
  }

  Future<void> inviteUser() async {
    final team = selectedTeam;
    final username = _usernameController.text.trim();

    if (team == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create or select a team first.')),
      );
      return;
    }

    if (username.length < 3) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid username.')));
      return;
    }

    setState(() {
      isInviting = true;
    });

    try {
      await _teamsApi.inviteUser(teamId: team.teamId, username: username);

      if (!mounted) {
        return;
      }

      _usernameController.clear();
      setState(() {
        isInviting = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invitation sent.')));
      widget.onTeamsChanged?.call();
    } catch (error, stackTrace) {
      debugPrint('Team invitation failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        isInviting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send invitation.')),
      );
    }
  }

  Future<void> respondToInvitation(
    TeamInvitationModel invitation, {
    required bool accept,
  }) async {
    setState(() {
      updatingInvitationId = invitation.invitationId;
    });

    try {
      if (accept) {
        await _teamsApi.acceptInvitation(invitation.invitationId);
      } else {
        await _teamsApi.rejectInvitation(invitation.invitationId);
      }

      if (!mounted) {
        return;
      }

      await loadTeams();

      if (!mounted) {
        return;
      }

      setState(() {
        updatingInvitationId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept ? 'Invitation accepted.' : 'Invitation rejected.',
          ),
        ),
      );
      widget.onTeamsChanged?.call();
    } catch (error, stackTrace) {
      debugPrint('Invitation response failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        updatingInvitationId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update invitation.')),
      );
    }
  }

  Color mutedColor(BuildContext context) {
    return PlanoraTheme.isDark(context)
        ? PlanoraTheme.darkTextSecondary
        : PlanoraTheme.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
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
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 18),
                    Expanded(child: _buildBody(context)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        if (widget.showBackButton) ...[
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            'Teams',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return _buildState(
        context,
        icon: Icons.wifi_off_rounded,
        title: errorMessage!,
        action: 'Try Again',
        onAction: loadTeams,
      );
    }

    return RefreshIndicator(
      onRefresh: loadTeams,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          if (teams.isEmpty)
            _buildStateCard(
              context,
              icon: Icons.groups_2_outlined,
              title: 'Create or join a team',
              message:
                  'Teams let you create shared projects and invite members.',
            ),
          _buildCreateTeamCard(context),
          const SizedBox(height: 16),
          if (teams.isNotEmpty) ...[
            _buildTeamSelector(context),
            const SizedBox(height: 16),
            _buildInviteCard(context),
            const SizedBox(height: 16),
            _buildMembersCard(context),
            const SizedBox(height: 16),
          ],
          _buildInvitationsCard(context),
        ],
      ),
    );
  }

  Widget _buildCreateTeamCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create Team',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _teamNameController,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => createTeam(),
            decoration: const InputDecoration(
              hintText: 'Team name',
              prefixIcon: Icon(Icons.groups_2_outlined),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: isCreatingTeam ? null : createTeam,
              icon: isCreatingTeam
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
              label: const Text('Create Team'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(context),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedTeam?.teamId,
          isExpanded: true,
          borderRadius: BorderRadius.circular(16),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: [
            for (final team in teams)
              DropdownMenuItem<int>(
                value: team.teamId,
                child: Text(
                  team.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (teamId) {
            if (teamId == null) {
              return;
            }

            final team = teams.firstWhere(
              (item) => item.teamId == teamId,
              orElse: () => teams.first,
            );

            selectTeam(team);
          },
        ),
      ),
    );
  }

  Widget _buildInviteCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Invite User',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameController,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => inviteUser(),
            decoration: const InputDecoration(
              hintText: 'Username',
              prefixIcon: Icon(Icons.person_add_alt_1_outlined),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: isInviting ? null : inviteUser,
              icon: isInviting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: const Text('Send Invitation'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Members',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          if (isLoadingWorkload)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(
                minHeight: 3,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          if (workloadMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                workloadMessage!,
                style: TextStyle(
                  color: mutedColor(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (members.isEmpty)
            Text(
              'No team members returned yet.',
              style: TextStyle(
                color: mutedColor(context),
                fontWeight: FontWeight.w700,
              ),
            )
          else
            for (final member in members) _buildMemberRow(context, member),
        ],
      ),
    );
  }

  Widget _buildInvitationsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pending Invitations',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          if (invitations.isEmpty)
            Text(
              'No pending invitations.',
              style: TextStyle(
                color: mutedColor(context),
                fontWeight: FontWeight.w700,
              ),
            )
          else
            for (final invitation in invitations)
              _buildInvitationRow(context, invitation),
        ],
      ),
    );
  }

  Widget _buildInvitationRow(
    BuildContext context,
    TeamInvitationModel invitation,
  ) {
    final isUpdating = updatingInvitationId == invitation.invitationId;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Team #${invitation.teamId}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Role: ${invitation.role} - ${formatShortDate(invitation.createdAt)}',
            style: TextStyle(
              color: mutedColor(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isUpdating
                      ? null
                      : () => respondToInvitation(invitation, accept: false),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: isUpdating
                      ? null
                      : () => respondToInvitation(invitation, accept: true),
                  child: isUpdating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemberRow(BuildContext context, TeamMemberModel member) {
    final workload =
        workloadByUserId[member.userId] ?? const TeamMemberWorkload();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                child: Text(
                  member.initials,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildRoleBadge(context, member.roleLabel),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildWorkloadPill(
                  context,
                  label: 'Assigned',
                  value: workload.assignedTaskCount,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildWorkloadPill(
                  context,
                  label: 'Done',
                  value: workload.completedTaskCount,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildWorkloadPill(
                  context,
                  label: 'Overdue',
                  value: workload.overdueTaskCount,
                  accent: workload.overdueTaskCount == 0
                      ? null
                      : PlanoraTheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildWorkloadPill(
    BuildContext context, {
    required String label,
    required int value,
    Color? accent,
  }) {
    final color = accent ?? mutedColor(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: mutedColor(context),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(context),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 38),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: mutedColor(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildState(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? action,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 40),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (action != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(action)),
          ],
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return BoxDecoration(
      color: isDark ? PlanoraTheme.darkSurface : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isDark ? PlanoraTheme.darkBorder : PlanoraTheme.border,
      ),
      boxShadow: PlanoraTheme.cardShadowFor(context),
    );
  }
}

class TeamMemberWorkload {
  final int assignedTaskCount;
  final int completedTaskCount;
  final int overdueTaskCount;

  const TeamMemberWorkload({
    this.assignedTaskCount = 0,
    this.completedTaskCount = 0,
    this.overdueTaskCount = 0,
  });

  TeamMemberWorkload addTask(TaskModel task) {
    return TeamMemberWorkload(
      assignedTaskCount: assignedTaskCount + 1,
      completedTaskCount: completedTaskCount + (task.isCompleted ? 1 : 0),
      overdueTaskCount: overdueTaskCount + (task.isOverdue ? 1 : 0),
    );
  }
}
