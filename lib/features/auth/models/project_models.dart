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
}

class ProjectMemberModel {
  final int memberId;
  final int projectId;
  final int userId;
  final String role;
  final DateTime joinedAt;

  const ProjectMemberModel({
    required this.memberId,
    required this.projectId,
    required this.userId,
    required this.role,
    required this.joinedAt,
  });

  factory ProjectMemberModel.fromJson(Map<String, dynamic> json) {
    return ProjectMemberModel(
      memberId: json['member_id'] as int,
      projectId: json['project_id'] as int,
      userId: json['user_id'] as int,
      role: json['role'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }

  String get roleLabel {
    switch (role) {
      case 'owner':
        return 'Owner';
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
