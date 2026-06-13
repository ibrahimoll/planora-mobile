import '../../../core/network/api_client.dart';
import '../../auth/models/project_models.dart';

class TeamsApi {
  const TeamsApi();

  Future<List<TeamModel>> getTeams() async {
    final response = await ApiClient.get('/teams');

    if (response is! List) {
      return [];
    }

    return response
        .map((item) => TeamModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<TeamModel> createTeam(String name) async {
    final response = await ApiClient.postJson('/teams', data: {'name': name});

    return TeamModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteTeam(int teamId) async {
    await ApiClient.delete('/teams/$teamId');
  }

  Future<List<TeamMemberModel>> getTeamMembers(int teamId) async {
    final response = await ApiClient.get('/teams/$teamId/members');

    if (response is! List) {
      return [];
    }

    return response
        .map((item) => TeamMemberModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<TeamInvitationModel> inviteUser({
    required int teamId,
    required String username,
    String role = 'member',
  }) async {
    final response = await ApiClient.postJson(
      '/teams/$teamId/invitations',
      data: {'username': username, 'role': role},
    );

    return TeamInvitationModel.fromJson(response as Map<String, dynamic>);
  }

  Future<List<TeamInvitationModel>> getMyInvitations() async {
    final response = await ApiClient.get('/invitations/me');

    if (response is! List) {
      return [];
    }

    return response
        .map(
          (item) => TeamInvitationModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<TeamInvitationModel> acceptInvitation(int invitationId) async {
    final response = await ApiClient.postJson(
      '/invitations/$invitationId/accept',
    );

    return TeamInvitationModel.fromJson(response as Map<String, dynamic>);
  }

  Future<TeamInvitationModel> rejectInvitation(int invitationId) async {
    final response = await ApiClient.postJson(
      '/invitations/$invitationId/reject',
    );

    return TeamInvitationModel.fromJson(response as Map<String, dynamic>);
  }
}

class TeamMemberModel {
  final int teamMemberId;
  final int teamId;
  final int userId;
  final String role;
  final DateTime joinedAt;
  final UserSummaryModel? user;

  const TeamMemberModel({
    required this.teamMemberId,
    required this.teamId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    required this.user,
  });

  factory TeamMemberModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'];

    return TeamMemberModel(
      teamMemberId: _parseInt(json['team_member_id'] ?? json['id']),
      teamId: _parseInt(json['team_id']),
      userId: _parseInt(json['user_id']),
      role: json['role'] as String? ?? 'member',
      joinedAt: _parseDateTime(json['joined_at']),
      user: user is Map<String, dynamic>
          ? UserSummaryModel.fromJson(user)
          : null,
    );
  }

  String get displayName {
    return user?.displayName ?? 'User #$userId';
  }

  String get initials {
    return user?.initials ?? '?';
  }

  String get roleLabel {
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
}

class TeamInvitationModel {
  final int invitationId;
  final int teamId;
  final int? projectId;
  final int invitedBy;
  final int invitedUserId;
  final String? email;
  final String role;
  final String status;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const TeamInvitationModel({
    required this.invitationId,
    required this.teamId,
    required this.projectId,
    required this.invitedBy,
    required this.invitedUserId,
    required this.email,
    required this.role,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    required this.respondedAt,
  });

  factory TeamInvitationModel.fromJson(Map<String, dynamic> json) {
    return TeamInvitationModel(
      invitationId: _parseInt(json['invitation_id'] ?? json['id']),
      teamId: _parseInt(json['team_id']),
      projectId: _parseOptionalInt(json['project_id']),
      invitedBy: _parseInt(json['invited_by']),
      invitedUserId: _parseInt(json['invited_user_id']),
      email: _firstNonEmptyString([json['email']]),
      role: json['role'] as String? ?? 'member',
      status: json['status'] as String? ?? 'pending',
      expiresAt: _parseOptionalDateTime(json['expires_at']),
      createdAt: _parseDateTime(json['created_at']),
      respondedAt: _parseOptionalDateTime(json['responded_at']),
    );
  }

  bool get isPending {
    return status == 'pending';
  }
}

int _parseInt(dynamic value) {
  if (value is int) {
    return value;
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _parseOptionalInt(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  return int.tryParse(value.toString());
}

DateTime _parseDateTime(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
  }

  return DateTime.now();
}

DateTime? _parseOptionalDateTime(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal();
  }

  return null;
}

String? _firstNonEmptyString(List<dynamic> values) {
  for (final value in values) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }

  return null;
}
