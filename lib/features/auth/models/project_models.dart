import '../../../core/config/app_config.dart';

class ProjectModel {
  final int projectId;
  final int createdBy;
  final int? teamId;
  final String title;
  final String? description;
  final DateTime deadline;
  final String status;
  final String projectType;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ProjectModel({
    required this.projectId,
    required this.createdBy,
    required this.teamId,
    required this.title,
    required this.description,
    required this.deadline,
    required this.status,
    required this.projectType,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      projectId: json['project_id'] as int,
      createdBy: json['created_by'] as int,
      teamId: json['team_id'] as int?,
      title: json['title'] as String,
      description: json['description'] as String?,
      deadline: DateTime.parse(json['deadline'] as String),
      status: json['status'] as String,
      projectType: json['project_type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: _parseOptionalDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'project_id': projectId,
      'created_by': createdBy,
      'team_id': teamId,
      'title': title,
      'description': description,
      'deadline': deadline.toIso8601String(),
      'status': status,
      'project_type': projectType,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  bool get isCompleted {
    return status == 'completed';
  }

  bool get isActive {
    return status == 'in_progress' || status == 'not_started';
  }

  bool get isTeamProject {
    return projectType == 'team';
  }

  String get statusLabel {
    switch (status) {
      case 'not_started':
        return 'Not Started';
      case 'in_progress':
        return 'In Progress';
      case 'on_hold':
        return 'On Hold';
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  String get projectTypeLabel {
    switch (projectType) {
      case 'personal':
        return 'Personal';
      case 'team':
        return 'Team';
      default:
        return projectType;
    }
  }

  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDate = DateTime(deadline.year, deadline.month, deadline.day);

    return deadlineDate.difference(today).inDays;
  }

  String get deadlineLabel {
    final remainingDays = daysLeft;

    if (remainingDays < 0) {
      return '${remainingDays.abs()} days overdue';
    }

    if (remainingDays == 0) {
      return 'Due today';
    }

    if (remainingDays == 1) {
      return 'Due tomorrow';
    }

    return '$remainingDays days left';
  }

  static DateTime? _parseOptionalDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is String && value.trim().isNotEmpty) {
      return DateTime.parse(value);
    }

    return null;
  }
}

class TeamModel {
  final int teamId;
  final String name;
  final int createdBy;
  final DateTime createdAt;

  const TeamModel({
    required this.teamId,
    required this.name,
    required this.createdBy,
    required this.createdAt,
  });

  factory TeamModel.fromJson(Map<String, dynamic> json) {
    return TeamModel(
      teamId: json['team_id'] as int,
      name: json['name'] as String,
      createdBy: json['created_by'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'team_id': teamId,
      'name': name,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class UserSummaryModel {
  final int? userId;
  final String? username;
  final String? email;
  final String? fullName;
  final String? profilePic;

  const UserSummaryModel({
    required this.userId,
    required this.username,
    required this.email,
    required this.fullName,
    required this.profilePic,
  });

  static String? _normalizeProfilePic(String? value) {
    final trimmed = value?.trim();

    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }

    final uri = Uri.tryParse(trimmed);

    if (uri != null && uri.hasScheme) {
      return trimmed;
    }

    if (trimmed.startsWith('/')) {
      return '${AppConfig.apiBaseUrl}$trimmed';
    }

    return '${AppConfig.apiBaseUrl}/$trimmed';
  }

  factory UserSummaryModel.fromJson(Map<String, dynamic> json) {
    return UserSummaryModel(
      userId: _parseOptionalInt(json['user_id'] ?? json['id']),
      username: _firstNonEmptyString([json['username']]),
      email: _firstNonEmptyString([json['email']]),
      fullName: _firstNonEmptyString([
        json['full_name'],
        json['fullName'],
        json['name'],
      ]),
      profilePic: _normalizeProfilePic(
        _firstNonEmptyString([
          json['profile_pic'],
          json['profilePic'],
          json['profile_pic_url'],
          json['profile_picture'],
          json['profilePicture'],
          json['profile_picture_url'],
          json['avatar_url'],
          json['avatarUrl'],
          json['avatar'],
          json['image_url'],
          json['imageUrl'],
        ]),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'email': email,
      'full_name': fullName,
      'profile_pic': profilePic,
    };
  }

  String get displayName {
    final value = _firstNonEmptyString([fullName, username, email]);
    return value ?? 'Unknown user';
  }

  String get initials {
    final label = displayName.trim();

    if (label.isEmpty || label == 'Unknown user') {
      return '?';
    }

    final parts = label.split(RegExp(r'\s+'));

    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }

    return label[0].toUpperCase();
  }

  static int? _parseOptionalInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }

  static String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return null;
  }
}

class ProjectMemberModel {
  final int memberId;
  final int projectId;
  final int userId;
  final String role;
  final DateTime joinedAt;
  final UserSummaryModel? user;

  const ProjectMemberModel({
    required this.memberId,
    required this.projectId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    required this.user,
  });

  factory ProjectMemberModel.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];

    final userJson = rawUser is Map
        ? Map<String, dynamic>.from(rawUser)
        : <String, dynamic>{};

    dynamic firstValue(List<dynamic> values) {
      for (final value in values) {
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }

        if (value != null && value is! String) {
          return value;
        }
      }

      return null;
    }

    userJson['user_id'] = firstValue([
      userJson['user_id'],
      userJson['id'],
      json['user_id'],
      json['member_user_id'],
    ]);

    userJson['username'] = firstValue([
      userJson['username'],
      json['username'],
      json['user_username'],
    ]);

    userJson['email'] = firstValue([
      userJson['email'],
      json['email'],
      json['user_email'],
    ]);

    userJson['full_name'] = firstValue([
      userJson['full_name'],
      userJson['fullName'],
      userJson['name'],
      json['full_name'],
      json['fullName'],
      json['name'],
      json['user_full_name'],
    ]);

    userJson['profile_pic'] = firstValue([
      userJson['profile_pic'],
      userJson['profilePic'],
      userJson['profile_pic_url'],
      userJson['profile_picture'],
      userJson['profilePicture'],
      userJson['profile_picture_url'],
      userJson['avatar_url'],
      userJson['avatarUrl'],
      userJson['avatar'],
      userJson['image_url'],
      userJson['imageUrl'],

      json['profile_pic'],
      json['profilePic'],
      json['profile_pic_url'],
      json['profile_picture'],
      json['profilePicture'],
      json['profile_picture_url'],
      json['avatar_url'],
      json['avatarUrl'],
      json['avatar'],
      json['image_url'],
      json['imageUrl'],
      json['user_profile_pic'],
      json['user_profile_picture'],
      json['user_avatar_url'],
    ]);

    final userId =
        int.tryParse(
          (json['user_id'] ?? userJson['user_id'] ?? 0).toString(),
        ) ??
        0;

    return ProjectMemberModel(
      memberId: int.parse(json['member_id'].toString()),
      projectId: int.parse(json['project_id'].toString()),
      userId: userId,
      role: json['role']?.toString() ?? 'member',
      joinedAt:
          DateTime.tryParse(json['joined_at']?.toString() ?? '') ??
          DateTime.now(),
      user: UserSummaryModel.fromJson(userJson),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'member_id': memberId,
      'project_id': projectId,
      'user_id': userId,
      'role': role,
      'joined_at': joinedAt.toIso8601String(),
      'user': user?.toJson(),
    };
  }

  String get displayName {
    return user?.displayName ?? 'Unknown user';
  }

  String? get email {
    return user?.email;
  }

  String? get profilePic {
    return user?.profilePic;
  }

  String get initials {
    return user?.initials ?? '?';
  }

  String get roleLabel {
    switch (role) {
      case 'owner':
        return 'Owner';
      case 'admin':
        return 'Admin';
      case 'manager':
        return 'Manager';
      case 'member':
        return 'Member';
      default:
        return role;
    }
  }
}

class ProjectCreateRequest {
  final String title;
  final String? description;
  final DateTime deadline;

  const ProjectCreateRequest({
    required this.title,
    required this.description,
    required this.deadline,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'deadline': deadline.toIso8601String(),
    };
  }
}

class ProjectUpdateRequest {
  final String? title;
  final String? description;
  final DateTime? deadline;
  final String? status;

  const ProjectUpdateRequest({
    this.title,
    this.description,
    this.deadline,
    this.status,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};

    if (title != null) {
      data['title'] = title;
    }

    if (description != null) {
      data['description'] = description;
    }

    if (deadline != null) {
      data['deadline'] = deadline!.toIso8601String();
    }

    if (status != null) {
      data['status'] = status;
    }

    return data;
  }
}
