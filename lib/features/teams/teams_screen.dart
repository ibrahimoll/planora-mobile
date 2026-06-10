import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/core/theme/planora_theme.dart';
import 'package:mobile/features/auth/data/project_api.dart';
import 'package:mobile/features/auth/models/project_models.dart';
import 'package:mobile/features/tasks/data/tasks_api.dart';
import 'package:mobile/features/tasks/models/task_models.dart';
import 'package:mobile/features/teams/data/teams_api.dart';

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
  late final TeamsApi _teamsApi;
  late final ProjectsApi _projectsApi;
  late final TasksApi _tasksApi;
  late final TextEditingController _searchController;

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  int _selectedTabIndex = 0;
  String _searchQuery = '';

  List<_TeamCardData> _teams = [];
  List<TeamInvitationModel> _invitations = [];

  @override
  void initState() {
    super.initState();
    _teamsApi = widget.teamsApi is TeamsApi
        ? widget.teamsApi! as TeamsApi
        : const TeamsApi();
    _projectsApi = widget.projectsApi is ProjectsApi
        ? widget.projectsApi! as ProjectsApi
        : const ProjectsApi();
    _tasksApi = widget.tasksApi is TasksApi
        ? widget.tasksApi! as TasksApi
        : const TasksApi();
    _searchController = TextEditingController();
    _loadTeams();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_TeamCardData> get _filteredTeams {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _teams;
    }

    return _teams.where((item) {
      return item.team.name.toLowerCase().contains(query) ||
          item.subtitle.toLowerCase().contains(query);
    }).toList();
  }

  List<TeamInvitationModel> get _pendingInvitations {
    return _invitations.where((item) => item.isPending).toList();
  }

  Future<void> _loadTeams({bool silent = false}) async {
    if (!mounted) return;

    setState(() {
      if (silent) {
        _isRefreshing = true;
      } else {
        _isLoading = true;
      }
      _errorMessage = null;
    });

    try {
      final teams = await _teamsApi.getTeams().timeout(
        const Duration(seconds: 12),
      );

      final invitations = await _teamsApi.getMyInvitations().timeout(
        const Duration(seconds: 12),
        onTimeout: () => <TeamInvitationModel>[],
      );

      final basicCards = teams.asMap().entries.map((entry) {
        return _TeamCardData.basic(team: entry.value, index: entry.key);
      }).toList();

      if (!mounted) return;

      setState(() {
        _teams = basicCards;
        _invitations = invitations;
        _isLoading = false;
        _isRefreshing = false;
      });

      unawaited(_loadTeamStatsInBackground(teams));
    } catch (error, stackTrace) {
      debugPrint('Teams load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _errorMessage = 'Could not load teams. Please try again.';
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _loadTeamStatsInBackground(List<TeamModel> teams) async {
    final detailedCards = <_TeamCardData>[];

    for (final entry in teams.asMap().entries) {
      final card = await _buildTeamCardData(
        team: entry.value,
        index: entry.key,
      );
      detailedCards.add(card);
    }

    if (!mounted) return;

    setState(() {
      _teams = detailedCards;
    });
  }

  Future<_TeamCardData> _buildTeamCardData({
    required TeamModel team,
    required int index,
  }) async {
    List<TeamMemberModel> members = [];
    List<ProjectModel> projects = [];
    int taskCount = 0;

    try {
      members = await _teamsApi
          .getTeamMembers(team.teamId)
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => <TeamMemberModel>[],
          );
    } catch (error, stackTrace) {
      debugPrint('Team members load failed for ${team.teamId}: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      projects = await _projectsApi
          .getTeamProjects(team.teamId)
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => <ProjectModel>[],
          );
    } catch (error, stackTrace) {
      debugPrint('Team projects load failed for ${team.teamId}: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    for (final project in projects) {
      try {
        final tasks = await _tasksApi
            .getProjectTasks(project: TaskProjectSummary.fromProject(project))
            .timeout(
              const Duration(seconds: 8),
              onTimeout: () => <TaskListItem>[],
            );
        taskCount += tasks.length;
      } catch (error, stackTrace) {
        debugPrint(
          'Team task load failed for project ${project.projectId}: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    return _TeamCardData(
      team: team,
      members: members,
      projectCount: projects.length,
      taskCount: taskCount,
      icon: _iconForTeam(team.name),
      iconColor: _iconColorForTeam(team.name),
      iconBackground: _iconBackgroundForTeam(team.name),
      accentLabel: index == 0 ? 'Owner' : null,
      isLoadingStats: false,
    );
  }

  IconData _iconForTeam(String teamName) {
    final normalized = teamName.toLowerCase();

    if (normalized.contains('design') || normalized.contains('ui')) {
      return Icons.business_center_outlined;
    }

    if (normalized.contains('develop') ||
        normalized.contains('code') ||
        normalized.contains('tech') ||
        normalized.contains('backend') ||
        normalized.contains('frontend')) {
      return Icons.code_rounded;
    }

    if (normalized.contains('market') ||
        normalized.contains('sales') ||
        normalized.contains('growth')) {
      return Icons.campaign_outlined;
    }

    if (normalized.contains('planora')) {
      return Icons.rocket_launch_outlined;
    }

    return Icons.groups_2_outlined;
  }

  Color _iconColorForTeam(String teamName) {
    final normalized = teamName.toLowerCase();

    if (normalized.contains('design') || normalized.contains('ui')) {
      return const Color(0xFF3B82F6);
    }

    if (normalized.contains('develop') ||
        normalized.contains('code') ||
        normalized.contains('tech') ||
        normalized.contains('backend') ||
        normalized.contains('frontend')) {
      return const Color(0xFF22C55E);
    }

    if (normalized.contains('market') ||
        normalized.contains('sales') ||
        normalized.contains('growth')) {
      return const Color(0xFFF59E0B);
    }

    return PlanoraTheme.secondaryPurple;
  }

  Color _iconBackgroundForTeam(String teamName) {
    final normalized = teamName.toLowerCase();

    if (normalized.contains('design') || normalized.contains('ui')) {
      return const Color(0xFFEAF2FF);
    }

    if (normalized.contains('develop') ||
        normalized.contains('code') ||
        normalized.contains('tech') ||
        normalized.contains('backend') ||
        normalized.contains('frontend')) {
      return const Color(0xFFEAFBF0);
    }

    if (normalized.contains('market') ||
        normalized.contains('sales') ||
        normalized.contains('growth')) {
      return const Color(0xFFFFF6E6);
    }

    return const Color(0xFFF0EAFF);
  }

  Future<void> _openCreateTeamDialog() async {
    final controller = TextEditingController();
    var isSubmitting = false;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = PlanoraTheme.isDark(context);

            return AlertDialog(
              backgroundColor: isDark
                  ? PlanoraTheme.darkSurface
                  : PlanoraTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                'Create a new team',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? PlanoraTheme.darkTextPrimary
                      : PlanoraTheme.textPrimary,
                ),
              ),
              content: TextField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Team name',
                  hintText: 'Example: Design Team',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onSubmitted: (_) async {
                  if (!isSubmitting) {
                    await _createTeamFromDialog(
                      controller: controller,
                      setDialogState: setDialogState,
                      closeDialog: () => Navigator.of(dialogContext).pop(true),
                      setSubmitting: (value) => isSubmitting = value,
                    );
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          await _createTeamFromDialog(
                            controller: controller,
                            setDialogState: setDialogState,
                            closeDialog: () =>
                                Navigator.of(dialogContext).pop(true),
                            setSubmitting: (value) => isSubmitting = value,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: PlanoraTheme.primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (created == true) {
      widget.onTeamsChanged?.call();
      await _loadTeams(silent: true);
    }
  }

  Future<void> _createTeamFromDialog({
    required TextEditingController controller,
    required StateSetter setDialogState,
    required VoidCallback closeDialog,
    required ValueChanged<bool> setSubmitting,
  }) async {
    final name = controller.text.trim();

    if (name.isEmpty) {
      _showSnackBar('Enter a team name first.');
      return;
    }

    setDialogState(() {
      setSubmitting(true);
    });

    try {
      await _teamsApi.createTeam(name);
      closeDialog();
      _showSnackBar('Team created successfully.');
    } catch (error, stackTrace) {
      debugPrint('Team create failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showSnackBar('Could not create team. Please try again.');
      setDialogState(() {
        setSubmitting(false);
      });
    }
  }

  Future<void> _acceptInvitation(TeamInvitationModel invitation) async {
    try {
      await _teamsApi.acceptInvitation(invitation.invitationId);
      _showSnackBar('Invitation accepted.');
      widget.onTeamsChanged?.call();
      await _loadTeams(silent: true);
    } catch (error, stackTrace) {
      debugPrint('Invitation accept failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showSnackBar('Could not accept invitation.');
    }
  }

  Future<void> _rejectInvitation(TeamInvitationModel invitation) async {
    try {
      await _teamsApi.rejectInvitation(invitation.invitationId);
      _showSnackBar('Invitation rejected.');
      widget.onTeamsChanged?.call();
      await _loadTeams(silent: true);
    } catch (error, stackTrace) {
      debugPrint('Invitation reject failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showSnackBar('Could not reject invitation.');
    }
  }

  void _showSnackBar(String message) {
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

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final backgroundColor = isDark
        ? PlanoraTheme.darkBackground
        : const Color(0xFFFAFAFF);

    final content = AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: _buildTeamsContent(context),
    );

    if (!widget.showBackButton) {
      return content;
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildTeamsContent(BuildContext context) {
    final isEmbeddedInHome = !widget.showBackButton;

    return RefreshIndicator(
      color: PlanoraTheme.primaryPurple,
      onRefresh: () => _loadTeams(silent: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          isEmbeddedInHome ? 0 : 22,
          isEmbeddedInHome ? 0 : 22,
          isEmbeddedInHome ? 0 : 22,
          120,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TeamsHeader(
              showBackButton: widget.showBackButton,
              isRefreshing: _isRefreshing,
              onBackPressed: () => Navigator.of(context).maybePop(),
              onCreatePressed: _openCreateTeamDialog,
            ),
            const SizedBox(height: 18),
            _SearchAndFilterRow(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              onFilterPressed: () => _showSnackBar(
                'Filters will be connected when team roles/status filters are added.',
              ),
            ),
            const SizedBox(height: 22),
            _TeamTabs(
              selectedIndex: _selectedTabIndex,
              invitationCount: _pendingInvitations.length,
              onChanged: (index) {
                setState(() => _selectedTabIndex = index);
              },
            ),
            const SizedBox(height: 18),
            _buildBody(),
            const SizedBox(height: 4),
            _CreateTeamBanner(onPressed: _openCreateTeamDialog),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _teams.isEmpty) {
      return const _TeamsLoadingList();
    }

    if (_errorMessage != null) {
      return _TeamsErrorState(
        message: _errorMessage!,
        onRetry: () => _loadTeams(),
      );
    }

    if (_selectedTabIndex == 1) {
      return _InvitationsList(
        invitations: _pendingInvitations,
        onAccept: _acceptInvitation,
        onReject: _rejectInvitation,
      );
    }

    final teams = _filteredTeams;

    if (teams.isEmpty) {
      return _EmptyTeamsState(
        hasSearchQuery: _searchQuery.trim().isNotEmpty,
        onCreateTeam: _openCreateTeamDialog,
      );
    }

    return Column(
      children: [
        for (final team in teams)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _TeamCard(
              data: team,
              onMenuPressed: () => _showTeamMenu(team),
              onTap: () => _showTeamSummary(team),
            ),
          ),
      ],
    );
  }

  void _showTeamMenu(_TeamCardData team) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = PlanoraTheme.isDark(context);

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: isDark ? PlanoraTheme.darkSurface : PlanoraTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? PlanoraTheme.darkBorder
                      : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('View team summary'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showTeamSummary(team);
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('Refresh teams'),
                onTap: () {
                  Navigator.of(context).pop();
                  _loadTeams(silent: true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTeamSummary(_TeamCardData team) {
    _showSnackBar(
      '${team.team.name}: ${team.memberCount} members, ${team.projectCount} projects, ${team.taskCount} tasks.',
    );
  }
}

class _TeamsHeader extends StatelessWidget {
  const _TeamsHeader({
    required this.showBackButton,
    required this.isRefreshing,
    required this.onBackPressed,
    required this.onCreatePressed,
  });

  final bool showBackButton;
  final bool isRefreshing;
  final VoidCallback onBackPressed;
  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final titleColor = isDark
        ? PlanoraTheme.darkTextPrimary
        : const Color(0xFF141724);
    final subtitleColor = isDark
        ? PlanoraTheme.darkTextSecondary
        : const Color(0xFF6C7391);

    return Row(
      children: [
        if (showBackButton) ...[
          _HeaderIconButton(
            icon: Icons.arrow_back_rounded,
            onPressed: onBackPressed,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Teams',
                      style: TextStyle(
                        fontSize: 28,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: titleColor,
                      ),
                    ),
                  ),
                  if (isRefreshing) ...[
                    const SizedBox(width: 10),
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Manage your teams and collaborate',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  color: subtitleColor,
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
            gradient: PlanoraTheme.primaryGradientFor(context),
            borderRadius: BorderRadius.circular(13),
            boxShadow: PlanoraTheme.floatingShadowFor(context),
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

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: isDark ? PlanoraTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isDark ? PlanoraTheme.darkBorder : const Color(0xFFE6E8F2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onPressed,
          child: Icon(
            icon,
            color: isDark
                ? PlanoraTheme.darkTextSecondary
                : const Color(0xFF68708C),
          ),
        ),
      ),
    );
  }
}

class _SearchAndFilterRow extends StatelessWidget {
  const _SearchAndFilterRow({
    required this.controller,
    required this.onChanged,
    required this.onFilterPressed,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final surface = isDark ? PlanoraTheme.darkSurface : Colors.white;
    final borderColor = isDark
        ? PlanoraTheme.darkBorder
        : const Color(0xFFE6E8F2);

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: borderColor),
              boxShadow: isDark ? [] : PlanoraTheme.cardShadow,
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: PlanoraTheme.primaryPurple,
              decoration: InputDecoration(
                hintText: 'Search teams...',
                hintStyle: TextStyle(
                  color: isDark
                      ? PlanoraTheme.darkTextMuted
                      : const Color(0xFF98A0B8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: isDark
                      ? PlanoraTheme.darkTextMuted
                      : const Color(0xFF8A91AA),
                  size: 22,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? PlanoraTheme.darkTextPrimary
                    : const Color(0xFF171B2E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: borderColor),
            boxShadow: isDark ? [] : PlanoraTheme.cardShadow,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: onFilterPressed,
              child: Icon(
                Icons.tune_rounded,
                color: isDark
                    ? PlanoraTheme.darkTextSecondary
                    : const Color(0xFF68708C),
                size: 23,
              ),
            ),
          ),
        ),
      ],
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
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      height: 35,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? PlanoraTheme.darkBorder : const Color(0xFFE7E9F2),
            width: 1,
          ),
        ),
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
  final int? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final color = selected
        ? PlanoraTheme.secondaryPurple
        : isDark
        ? PlanoraTheme.darkTextSecondary
        : const Color(0xFF6C7391);

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
                          color: PlanoraTheme.primaryPurple,
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
                    color: PlanoraTheme.secondaryPurple,
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

class _TeamsLoadingList extends StatelessWidget {
  const _TeamsLoadingList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _LoadingTeamCard(),
        SizedBox(height: 14),
        _LoadingTeamCard(),
        SizedBox(height: 14),
        _LoadingTeamCard(),
      ],
    );
  }
}

class _LoadingTeamCard extends StatelessWidget {
  const _LoadingTeamCard();

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final surface = isDark ? PlanoraTheme.darkSurface : Colors.white;
    final borderColor = isDark
        ? PlanoraTheme.darkBorder
        : const Color(0xFFE8EAF4);
    final blockColor = isDark
        ? PlanoraTheme.darkSurfaceVariant
        : const Color(0xFFF1F3FA);

    return Container(
      height: 156,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(15),
        boxShadow: isDark ? [] : PlanoraTheme.softCardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: blockColor,
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 150, height: 16, color: blockColor),
                    const SizedBox(height: 10),
                    Container(width: 220, height: 12, color: blockColor),
                    const SizedBox(height: 12),
                    Container(width: 88, height: 24, color: blockColor),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Divider(color: borderColor, height: 1),
          const SizedBox(height: 10),
          Container(width: double.infinity, height: 18, color: blockColor),
        ],
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.data,
    required this.onMenuPressed,
    required this.onTap,
  });

  final _TeamCardData data;
  final VoidCallback onMenuPressed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);
    final surface = isDark ? PlanoraTheme.darkSurface : Colors.white;
    final borderColor = isDark
        ? PlanoraTheme.darkBorder
        : const Color(0xFFE8EAF4);
    final titleColor = isDark
        ? PlanoraTheme.darkTextPrimary
        : const Color(0xFF171B2E);
    final subtitleColor = isDark
        ? PlanoraTheme.darkTextSecondary
        : const Color(0xFF6C7391);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(15),
        boxShadow: isDark ? [] : PlanoraTheme.softCardShadow,
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
                        color: data.iconBackground,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(data.icon, color: data.iconColor, size: 31),
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
                                    data.team.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 17,
                                      height: 1.15,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.25,
                                      color: titleColor,
                                    ),
                                  ),
                                ),
                                if (data.accentLabel != null) ...[
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
                                      data.accentLabel!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: PlanoraTheme.primaryPurple,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 7),
                            Text(
                              data.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: subtitleColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _AvatarStack(members: data.members),
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
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: isDark
                            ? PlanoraTheme.darkTextSecondary
                            : const Color(0xFF626B87),
                        size: 21,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark
                      ? PlanoraTheme.darkBorder
                      : const Color(0xFFE9EBF4),
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        icon: Icons.group_outlined,
                        value: data.memberCount,
                        label: 'Members',
                        isLoading: data.isLoadingStats,
                      ),
                    ),
                    Expanded(
                      child: _StatItem(
                        icon: Icons.folder_copy_outlined,
                        value: data.projectCount,
                        label: 'Projects',
                        isLoading: data.isLoadingStats,
                      ),
                    ),
                    Expanded(
                      child: _StatItem(
                        icon: Icons.check_box_outlined,
                        value: data.taskCount,
                        label: 'Tasks',
                        isLoading: data.isLoadingStats,
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
  const _AvatarStack({required this.members});

  final List<TeamMemberModel> members;

  @override
  Widget build(BuildContext context) {
    const double size = 26;
    const double overlap = 18;
    final visibleMembers = members.take(3).toList();
    final extraCount = math.max(0, members.length - visibleMembers.length);
    final width = visibleMembers.isEmpty
        ? 94.0
        : (visibleMembers.length * overlap) + (extraCount > 0 ? 33 : 12);

    if (visibleMembers.isEmpty) {
      return Text(
        'Loading members',
        style: TextStyle(
          color: PlanoraTheme.isDark(context)
              ? PlanoraTheme.darkTextMuted
              : const Color(0xFF98A0B8),
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return SizedBox(
      height: size,
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int index = 0; index < visibleMembers.length; index++)
            Positioned(
              left: index * overlap,
              child: _MemberAvatar(
                member: visibleMembers[index],
                index: index,
                size: size,
              ),
            ),
          if (extraCount > 0)
            Positioned(
              left: visibleMembers.length * overlap,
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
                    color: PlanoraTheme.primaryPurple,
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

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({
    required this.member,
    required this.index,
    required this.size,
  });

  final TeamMemberModel member;
  final int index;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF8D5A3B),
      const Color(0xFFD08A5B),
      const Color(0xFF7A4B32),
      const Color(0xFF6D28D9),
      const Color(0xFF2563EB),
    ];

    return Tooltip(
      message: member.displayName,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors[index % colors.length],
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Text(
          member.initials,
          maxLines: 1,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
          ),
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
    required this.isLoading,
  });

  final IconData icon;
  final int value;
  final String label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isDark
                  ? PlanoraTheme.darkTextSecondary
                  : const Color(0xFF69718D),
            ),
            const SizedBox(width: 5),
            if (isLoading)
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: isDark
                      ? PlanoraTheme.darkTextMuted
                      : const Color(0xFF69718D),
                ),
              )
            else
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? PlanoraTheme.darkTextPrimary
                      : const Color(0xFF24283B),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: isDark
                ? PlanoraTheme.darkTextSecondary
                : const Color(0xFF6C7391),
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
      height: 81,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: PlanoraTheme.softPurpleGradientFor(context),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: PlanoraTheme.lavenderBorder),
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
              color: PlanoraTheme.secondaryPurple,
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
                    fontWeight: FontWeight.w800,
                    color: PlanoraTheme.isDark(context)
                        ? PlanoraTheme.darkTextPrimary
                        : const Color(0xFF171B2E),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Invite your team members and start\ncollaborating together.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                    color: PlanoraTheme.isDark(context)
                        ? PlanoraTheme.darkTextSecondary
                        : const Color(0xFF6C7391),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: PlanoraTheme.primaryPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: const Text(
                'Create Team',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvitationsList extends StatelessWidget {
  const _InvitationsList({
    required this.invitations,
    required this.onAccept,
    required this.onReject,
  });

  final List<TeamInvitationModel> invitations;
  final ValueChanged<TeamInvitationModel> onAccept;
  final ValueChanged<TeamInvitationModel> onReject;

  @override
  Widget build(BuildContext context) {
    if (invitations.isEmpty) {
      return const _InvitationsEmptyState();
    }

    return Column(
      children: [
        for (final invitation in invitations)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _InvitationCard(
              invitation: invitation,
              onAccept: () => onAccept(invitation),
              onReject: () => onReject(invitation),
            ),
          ),
      ],
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
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? PlanoraTheme.darkSurface : Colors.white,
        border: Border.all(
          color: isDark ? PlanoraTheme.darkBorder : const Color(0xFFE8EAF4),
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: isDark ? [] : PlanoraTheme.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Color(0xFFEDE8FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mail_outline_rounded,
                  color: PlanoraTheme.secondaryPurple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Team invitation',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? PlanoraTheme.darkTextPrimary
                            : const Color(0xFF171B2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Role: ${invitation.role}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? PlanoraTheme.darkTextSecondary
                            : const Color(0xFF6C7391),
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
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PlanoraTheme.error,
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: PlanoraTheme.primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvitationsEmptyState extends StatelessWidget {
  const _InvitationsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: BoxDecoration(
        color: PlanoraTheme.isDark(context)
            ? PlanoraTheme.darkSurface
            : Colors.white,
        border: Border.all(
          color: PlanoraTheme.isDark(context)
              ? PlanoraTheme.darkBorder
              : const Color(0xFFE8EAF4),
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.mail_outline_rounded,
            size: 42,
            color: PlanoraTheme.secondaryPurple,
          ),
          const SizedBox(height: 12),
          Text(
            'No invitations yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: PlanoraTheme.isDark(context)
                  ? PlanoraTheme.darkTextPrimary
                  : const Color(0xFF171B2E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Team invitations will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: PlanoraTheme.isDark(context)
                  ? PlanoraTheme.darkTextSecondary
                  : const Color(0xFF6C7391),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTeamsState extends StatelessWidget {
  const _EmptyTeamsState({
    required this.hasSearchQuery,
    required this.onCreateTeam,
  });

  final bool hasSearchQuery;
  final VoidCallback onCreateTeam;

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: BoxDecoration(
        color: isDark ? PlanoraTheme.darkSurface : Colors.white,
        border: Border.all(
          color: isDark ? PlanoraTheme.darkBorder : const Color(0xFFE8EAF4),
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.groups_2_outlined,
            size: 46,
            color: PlanoraTheme.secondaryPurple,
          ),
          const SizedBox(height: 12),
          Text(
            hasSearchQuery ? 'No matching teams' : 'No teams yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark
                  ? PlanoraTheme.darkTextPrimary
                  : const Color(0xFF171B2E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasSearchQuery
                ? 'Try another search keyword.'
                : 'Create your first team and start collaborating.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? PlanoraTheme.darkTextSecondary
                  : const Color(0xFF6C7391),
            ),
          ),
          if (!hasSearchQuery) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onCreateTeam,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: PlanoraTheme.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Create Team'),
            ),
          ],
        ],
      ),
    );
  }
}

class _TeamsErrorState extends StatelessWidget {
  const _TeamsErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = PlanoraTheme.isDark(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: isDark ? PlanoraTheme.darkSurface : Colors.white,
        border: Border.all(
          color: isDark ? PlanoraTheme.darkBorder : const Color(0xFFE8EAF4),
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 42,
            color: PlanoraTheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? PlanoraTheme.darkTextSecondary
                  : const Color(0xFF6C7391),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: PlanoraTheme.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _TeamCardData {
  const _TeamCardData({
    required this.team,
    required this.members,
    required this.projectCount,
    required this.taskCount,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.accentLabel,
    required this.isLoadingStats,
  });

  factory _TeamCardData.basic({required TeamModel team, required int index}) {
    final icon = _basicIconForTeam(team.name);
    final iconColor = _basicIconColorForTeam(team.name);
    final iconBackground = _basicIconBackgroundForTeam(team.name);

    return _TeamCardData(
      team: team,
      members: const [],
      projectCount: 0,
      taskCount: 0,
      icon: icon,
      iconColor: iconColor,
      iconBackground: iconBackground,
      accentLabel: index == 0 ? 'Owner' : null,
      isLoadingStats: true,
    );
  }

  final TeamModel team;
  final List<TeamMemberModel> members;
  final int projectCount;
  final int taskCount;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String? accentLabel;
  final bool isLoadingStats;

  int get memberCount => members.length;

  String get subtitle {
    if (isLoadingStats) {
      return 'Workspace for team collaboration';
    }

    if (projectCount == 0 && taskCount == 0) {
      return 'Workspace for team collaboration';
    }

    if (projectCount == 1) {
      return '1 active project workspace';
    }

    return '$projectCount project workspaces';
  }

  static IconData _basicIconForTeam(String teamName) {
    final normalized = teamName.toLowerCase();

    if (normalized.contains('design') || normalized.contains('ui')) {
      return Icons.business_center_outlined;
    }

    if (normalized.contains('develop') || normalized.contains('code')) {
      return Icons.code_rounded;
    }

    if (normalized.contains('market') || normalized.contains('sales')) {
      return Icons.campaign_outlined;
    }

    if (normalized.contains('planora')) {
      return Icons.rocket_launch_outlined;
    }

    return Icons.groups_2_outlined;
  }

  static Color _basicIconColorForTeam(String teamName) {
    final normalized = teamName.toLowerCase();

    if (normalized.contains('design') || normalized.contains('ui')) {
      return const Color(0xFF3B82F6);
    }

    if (normalized.contains('develop') || normalized.contains('code')) {
      return const Color(0xFF22C55E);
    }

    if (normalized.contains('market') || normalized.contains('sales')) {
      return const Color(0xFFF59E0B);
    }

    return PlanoraTheme.secondaryPurple;
  }

  static Color _basicIconBackgroundForTeam(String teamName) {
    final normalized = teamName.toLowerCase();

    if (normalized.contains('design') || normalized.contains('ui')) {
      return const Color(0xFFEAF2FF);
    }

    if (normalized.contains('develop') || normalized.contains('code')) {
      return const Color(0xFFEAFBF0);
    }

    if (normalized.contains('market') || normalized.contains('sales')) {
      return const Color(0xFFFFF6E6);
    }

    return const Color(0xFFF0EAFF);
  }
}
