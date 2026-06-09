import '../../auth/models/project_models.dart';

enum TaskStatus {
  todo('todo', 'To Do'),
  inProgress('in_progress', 'In Progress'),
  completed('completed', 'Completed'),
  blocked('blocked', 'Blocked');

  const TaskStatus(this.value, this.label);

  final String value;
  final String label;

  static TaskStatus fromJson(dynamic value) {
    final normalized = value?.toString();

    return TaskStatus.values.firstWhere(
      (status) => status.value == normalized,
      orElse: () => TaskStatus.todo,
    );
  }
}

enum TaskPriority {
  low('low', 'Low'),
  medium('medium', 'Medium'),
  high('high', 'High');

  const TaskPriority(this.value, this.label);

  final String value;
  final String label;

  static TaskPriority fromJson(dynamic value) {
    final normalized = value?.toString();

    return TaskPriority.values.firstWhere(
      (priority) => priority.value == normalized,
      orElse: () => TaskPriority.medium,
    );
  }
}

class TaskModel {
  final int taskId;
  final int projectId;
  final int? assignedTo;
  final String? assignedToName;
  final String? assignedToEmail;
  final String? assignedToAvatarUrl;
  final List<TaskMemberPreview> members;
  final List<TaskMemberPreview> followers;
  final List<TaskSubtaskPreview> subtasks;
  final List<String> tags;
  final int createdBy;
  final String title;
  final String? description;
  final String? sectionName;
  final TaskPriority priority;
  final double? estimatedHours;
  final double? actualHours;
  final TaskStatus status;
  final DateTime? startDate;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final DateTime createdAt;

  const TaskModel({
    required this.taskId,
    required this.projectId,
    required this.assignedTo,
    required this.assignedToName,
    required this.assignedToEmail,
    required this.assignedToAvatarUrl,
    required this.members,
    required this.followers,
    required this.subtasks,
    required this.tags,
    required this.createdBy,
    required this.title,
    required this.description,
    required this.sectionName,
    required this.priority,
    required this.estimatedHours,
    required this.actualHours,
    required this.status,
    required this.startDate,
    required this.dueDate,
    required this.completedAt,
    required this.createdAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      taskId: _parseInt(json['task_id']),
      projectId: _parseInt(json['project_id']),
      assignedTo: _parseOptionalInt(json['assigned_to']),
      assignedToName: _parseAssigneeName(json),
      assignedToEmail: _parseAssigneeEmail(json),
      assignedToAvatarUrl: _parseAssigneeAvatarUrl(json),
      members: _parseMemberPreviews(json),
      followers: _parseFollowerPreviews(json),
      subtasks: _parseSubtasks(json),
      tags: _parseTags(json),
      createdBy: _parseInt(json['created_by']),
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      sectionName: _parseSectionName(json),
      priority: TaskPriority.fromJson(json['priority']),
      estimatedHours: _parseOptionalDouble(json['estimated_hours']),
      actualHours: _parseOptionalDouble(json['actual_hours']),
      status: TaskStatus.fromJson(json['status']),
      startDate: _parseOptionalDateTime(
        json['start_date'] ?? json['started_at'],
      ),
      dueDate: _parseOptionalDateTime(json['due_date']),
      completedAt: _parseOptionalDateTime(json['completed_at']),
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_id': taskId,
      'project_id': projectId,
      'assigned_to': assignedTo,
      'assigned_to_name': assignedToName,
      'assigned_to_email': assignedToEmail,
      'assigned_to_avatar_url': assignedToAvatarUrl,
      'members': members.map((member) => member.toJson()).toList(),
      'followers': followers.map((member) => member.toJson()).toList(),
      'subtasks': subtasks.map((subtask) => subtask.toJson()).toList(),
      'tags': tags,
      'created_by': createdBy,
      'title': title,
      'description': description,
      'section_name': sectionName,
      'priority': priority.value,
      'estimated_hours': estimatedHours,
      'actual_hours': actualHours,
      'status': status.value,
      'start_date': startDate?.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isCompleted {
    return status == TaskStatus.completed;
  }

  bool get isBlocked {
    return status == TaskStatus.blocked;
  }

  bool get isOverdue {
    if (dueDate == null || isCompleted) {
      return false;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);

    return dueDay.isBefore(today);
  }

  String? get assigneeLabel {
    final name = assignedToName?.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    final email = assignedToEmail?.trim();

    if (email != null && email.isNotEmpty) {
      return email;
    }

    return null;
  }

  TaskMemberPreview? get assigneePreview {
    if (assignedTo != null) {
      for (final member in members) {
        if (member.userId == assignedTo) {
          return member;
        }
      }
    }

    final label = assigneeLabel;

    if (label == null) {
      return null;
    }

    return TaskMemberPreview(
      userId: assignedTo,
      name: assignedToName,
      email: assignedToEmail,
      avatarUrl: assignedToAvatarUrl,
      fallbackLabel: label,
    );
  }

  List<TaskMemberPreview> get memberPreviews {
    if (members.isNotEmpty) {
      return members;
    }

    final label = assigneeLabel;

    if (label == null) {
      return const [];
    }

    return [
      TaskMemberPreview(
        userId: assignedTo,
        name: assignedToName,
        email: assignedToEmail,
        avatarUrl: assignedToAvatarUrl,
        fallbackLabel: label,
      ),
    ];
  }

  String get dueDateLabel {
    final date = dueDate;

    if (date == null) {
      return 'No due date';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(date.year, date.month, date.day);
    final dayDifference = dueDay.difference(today).inDays;

    if (dayDifference < 0) {
      final days = dayDifference.abs();
      return days == 1 ? '1 day overdue' : '$days days overdue';
    }

    if (dayDifference == 0) {
      return 'Due today';
    }

    if (dayDifference == 1) {
      return 'Due tomorrow';
    }

    return formatShortDate(date);
  }

  String get completedDateLabel {
    final date = completedAt;

    if (date == null) {
      return 'Not completed';
    }

    return formatShortDate(date);
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.parse(value.toString());
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

  static double? _parseOptionalDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.parse(value).toLocal();
    }

    return DateTime.now();
  }

  static DateTime? _parseOptionalDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is String && value.trim().isNotEmpty) {
      return DateTime.parse(value).toLocal();
    }

    return null;
  }

  static String? _parseAssigneeName(Map<String, dynamic> json) {
    final direct = _firstNonEmptyString([
      json['assigned_to_name'],
      json['assignee_name'],
      json['assignee_full_name'],
      json['assigned_user_name'],
    ]);

    if (direct != null) {
      return direct;
    }

    final nested = json['assigned_user'] ?? json['assignee'];

    if (nested is Map<String, dynamic>) {
      return _firstNonEmptyString([
        nested['full_name'],
        nested['username'],
        nested['name'],
      ]);
    }

    return null;
  }

  static String? _parseAssigneeEmail(Map<String, dynamic> json) {
    final direct = _firstNonEmptyString([
      json['assigned_to_email'],
      json['assignee_email'],
      json['assigned_user_email'],
    ]);

    if (direct != null) {
      return direct;
    }

    final nested = json['assigned_user'] ?? json['assignee'];

    if (nested is Map<String, dynamic>) {
      return _firstNonEmptyString([nested['email']]);
    }

    return null;
  }

  static String? _parseAssigneeAvatarUrl(Map<String, dynamic> json) {
    final direct = _firstNonEmptyString([
      json['assigned_to_avatar_url'],
      json['assigned_to_avatar'],
      json['assignee_avatar_url'],
      json['assignee_avatar'],
      json['assigned_user_avatar_url'],
      json['assigned_user_avatar'],
    ]);

    if (direct != null) {
      return direct;
    }

    final nested =
        json['assigned_user'] ??
        json['assignee'] ??
        json['assigned_member'] ??
        json['member'];

    if (nested is Map<String, dynamic>) {
      return _firstNonEmptyString([
        nested['profile_pic'],
        nested['profile_picture'],
        nested['avatar_url'],
        nested['avatar'],
        nested['image_url'],
      ]);
    }

    return null;
  }

  static String? _parseSectionName(Map<String, dynamic> json) {
    final direct = _firstNonEmptyString([
      json['section'],
      json['section_name'],
      json['project_section'],
      json['project_section_name'],
    ]);

    if (direct != null) {
      return direct;
    }

    final nested = json['section_data'] ?? json['task_section'];

    if (nested is Map<String, dynamic>) {
      return _firstNonEmptyString([
        nested['title'],
        nested['name'],
        nested['label'],
      ]);
    }

    return null;
  }

  static List<TaskMemberPreview> _parseMemberPreviews(
    Map<String, dynamic> json,
  ) {
    final previews = <TaskMemberPreview>[];
    final listSources = [
      json['members'],
      json['team_members'],
      json['assigned_members'],
      json['assignees'],
      json['assigned_users'],
      json['task_members'],
    ];

    for (final source in listSources) {
      if (source is List) {
        for (final item in source) {
          final preview = TaskMemberPreview.fromJson(item);

          if (preview != null) {
            previews.add(preview);
          }
        }
      }
    }

    final singleSources = [
      json['assigned_user'],
      json['assignee'],
      json['assigned_member'],
      json['member'],
      json['user'],
    ];

    for (final source in singleSources) {
      final preview = TaskMemberPreview.fromJson(source);

      if (preview != null) {
        previews.add(preview);
      }
    }

    final unique = <TaskMemberPreview>[];
    final seenKeys = <String>{};

    for (final preview in previews) {
      final key = preview.identityKey;

      if (key.isEmpty || seenKeys.add(key)) {
        unique.add(preview);
      }
    }

    return unique;
  }

  static List<TaskMemberPreview> _parseFollowerPreviews(
    Map<String, dynamic> json,
  ) {
    final previews = <TaskMemberPreview>[];
    final listSources = [
      json['followers'],
      json['watchers'],
      json['subscribers'],
    ];

    for (final source in listSources) {
      if (source is List) {
        for (final item in source) {
          final preview = TaskMemberPreview.fromJson(item);

          if (preview != null) {
            previews.add(preview);
          }
        }
      }
    }

    return _uniqueMemberPreviews(previews);
  }

  static List<TaskSubtaskPreview> _parseSubtasks(Map<String, dynamic> json) {
    final subtasks = <TaskSubtaskPreview>[];
    final sources = [json['subtasks'], json['children'], json['child_tasks']];

    for (final source in sources) {
      if (source is List) {
        for (final item in source) {
          final subtask = TaskSubtaskPreview.fromJson(item);

          if (subtask != null) {
            subtasks.add(subtask);
          }
        }
      }
    }

    return subtasks;
  }

  static List<String> _parseTags(Map<String, dynamic> json) {
    final tags = <String>[];
    final sources = [json['tags'], json['labels']];

    for (final source in sources) {
      if (source is List) {
        for (final item in source) {
          final tag = _tagLabel(item);

          if (tag != null) {
            tags.add(tag);
          }
        }
      }
    }

    final single = _firstNonEmptyString([json['tag'], json['label']]);

    if (single != null) {
      tags.add(single);
    }

    final uniqueTags = <String>[];
    final seen = <String>{};

    for (final tag in tags) {
      final normalized = tag.trim();

      if (normalized.isNotEmpty && seen.add(normalized.toLowerCase())) {
        uniqueTags.add(normalized);
      }
    }

    return uniqueTags;
  }

  static String? _tagLabel(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    if (value is Map<String, dynamic>) {
      return _firstNonEmptyString([
        value['name'],
        value['title'],
        value['label'],
      ]);
    }

    return null;
  }

  static List<TaskMemberPreview> _uniqueMemberPreviews(
    List<TaskMemberPreview> previews,
  ) {
    final unique = <TaskMemberPreview>[];
    final seenKeys = <String>{};

    for (final preview in previews) {
      final key = preview.identityKey;

      if (key.isEmpty || seenKeys.add(key)) {
        unique.add(preview);
      }
    }

    return unique;
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

class TaskSubtaskPreview {
  final int? subtaskId;
  final String title;
  final TaskStatus status;

  const TaskSubtaskPreview({
    required this.subtaskId,
    required this.title,
    required this.status,
  });

  static TaskSubtaskPreview? fromJson(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    final title = _firstNonEmptyString([
      value['title'],
      value['name'],
      value['task_title'],
    ]);

    if (title == null) {
      return null;
    }

    return TaskSubtaskPreview(
      subtaskId: _parseOptionalInt(
        value['subtask_id'] ?? value['task_id'] ?? value['id'],
      ),
      title: title,
      status: TaskStatus.fromJson(value['status']),
    );
  }

  bool get isCompleted {
    return status == TaskStatus.completed;
  }

  Map<String, dynamic> toJson() {
    return {'subtask_id': subtaskId, 'title': title, 'status': status.value};
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

class TaskMemberPreview {
  final int? userId;
  final String? name;
  final String? email;
  final String? avatarUrl;
  final String? fallbackLabel;

  const TaskMemberPreview({
    required this.userId,
    required this.name,
    required this.email,
    required this.avatarUrl,
    this.fallbackLabel,
  });

  factory TaskMemberPreview.fromParts({
    int? userId,
    String? name,
    String? email,
    String? avatarUrl,
    String? fallbackLabel,
  }) {
    return TaskMemberPreview(
      userId: userId,
      name: _firstNonEmptyString([name]),
      email: _firstNonEmptyString([email]),
      avatarUrl: _firstNonEmptyString([avatarUrl]),
      fallbackLabel: _firstNonEmptyString([fallbackLabel]),
    );
  }

  static TaskMemberPreview? fromJson(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    final nestedUser = value['user'];
    final source = nestedUser is Map<String, dynamic> ? nestedUser : value;
    final name = _firstNonEmptyString([
      source['full_name'],
      source['name'],
      source['username'],
      source['display_name'],
      value['full_name'],
      value['name'],
      value['username'],
      value['display_name'],
      value['fallback_label'],
    ]);
    final email = _firstNonEmptyString([
      source['email'],
      value['email'],
      value['user_email'],
    ]);
    final avatarUrl = _firstNonEmptyString([
      source['profile_pic'],
      source['profile_picture'],
      source['avatar_url'],
      source['avatar'],
      source['image_url'],
      value['profile_pic'],
      value['profile_picture'],
      value['avatar_url'],
      value['avatar'],
      value['image_url'],
    ]);
    final userId = _parseOptionalInt(
      source['user_id'] ??
          source['id'] ??
          value['user_id'] ??
          value['member_id'] ??
          value['id'],
    );

    if (name == null && email == null && avatarUrl == null && userId == null) {
      return null;
    }

    return TaskMemberPreview(
      userId: userId,
      name: name,
      email: email,
      avatarUrl: avatarUrl,
      fallbackLabel: null,
    );
  }

  String get displayLabel {
    final preferred = _firstNonEmptyString([name, email, fallbackLabel]);

    if (preferred != null) {
      return preferred;
    }

    return 'Unknown user';
  }

  String get initials {
    final label = displayLabel.trim();

    if (label.isEmpty) {
      return '?';
    }

    final parts = label.split(RegExp(r'\s+'));

    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }

    return label[0].toUpperCase();
  }

  String get identityKey {
    if (userId != null) {
      return 'id:$userId';
    }

    final emailValue = email?.trim().toLowerCase();

    if (emailValue != null && emailValue.isNotEmpty) {
      return 'email:$emailValue';
    }

    final label = displayLabel.trim().toLowerCase();

    if (label.isNotEmpty) {
      return 'label:$label';
    }

    final avatar = avatarUrl?.trim().toLowerCase();

    if (avatar != null && avatar.isNotEmpty) {
      return 'avatar:$avatar';
    }

    return '';
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'email': email,
      'avatar_url': avatarUrl,
      'fallback_label': fallbackLabel,
    };
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

class TaskProjectSummary {
  final int projectId;
  final int? teamId;
  final String title;
  final String projectType;

  const TaskProjectSummary({
    required this.projectId,
    this.teamId,
    required this.title,
    required this.projectType,
  });

  factory TaskProjectSummary.fromJson(Map<String, dynamic> json) {
    return TaskProjectSummary(
      projectId: _parseInt(json['project_id']),
      teamId: _parseOptionalInt(json['team_id']),
      title: json['title'] as String? ?? 'Untitled project',
      projectType: json['project_type'] as String? ?? 'personal',
    );
  }

  factory TaskProjectSummary.fromProject(ProjectModel project) {
    return TaskProjectSummary(
      projectId: project.projectId,
      teamId: project.teamId,
      title: project.title,
      projectType: project.projectType,
    );
  }

  bool get isTeamProject {
    return projectType == 'team';
  }

  Map<String, dynamic> toJson() {
    return {
      'project_id': projectId,
      'team_id': teamId,
      'title': title,
      'project_type': projectType,
    };
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
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
}

class TaskAttachmentModel {
  final int attachmentId;
  final int projectId;
  final int? taskId;
  final int uploadedBy;
  final String fileName;
  final String fileUrl;
  final String? fileType;
  final int? fileSize;
  final DateTime uploadedAt;

  const TaskAttachmentModel({
    required this.attachmentId,
    required this.projectId,
    required this.taskId,
    required this.uploadedBy,
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.fileSize,
    required this.uploadedAt,
  });

  factory TaskAttachmentModel.fromJson(Map<String, dynamic> json) {
    return TaskAttachmentModel(
      attachmentId: TaskModel._parseInt(json['attachment_id']),
      projectId: TaskModel._parseInt(json['project_id']),
      taskId: TaskModel._parseOptionalInt(json['task_id']),
      uploadedBy: TaskModel._parseInt(json['uploaded_by']),
      fileName: json['file_name'] as String? ?? 'Attachment',
      fileUrl: json['file_url'] as String? ?? '',
      fileType: json['file_type'] as String?,
      fileSize: TaskModel._parseOptionalInt(json['file_size'] ?? json['size']),
      uploadedAt: TaskModel._parseDateTime(json['uploaded_at']),
    );
  }

  String? get sizeLabel {
    final bytes = fileSize;

    if (bytes == null) {
      return null;
    }

    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(kb >= 10 ? 0 : 1)} KB';
    }

    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
  }

  bool get isImage {
    final type = fileType?.toLowerCase() ?? '';
    final name = fileName.toLowerCase();

    return type.startsWith('image/') ||
        name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.webp');
  }
}

class TaskCommentModel {
  final int commentId;
  final int taskId;
  final int userId;
  final String? userName;
  final String? userEmail;
  final String? userAvatarUrl;
  final String commentText;
  final DateTime createdAt;

  const TaskCommentModel({
    required this.commentId,
    required this.taskId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userAvatarUrl,
    required this.commentText,
    required this.createdAt,
  });

  factory TaskCommentModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final userMap = user is Map<String, dynamic> ? user : null;

    return TaskCommentModel(
      commentId: TaskModel._parseInt(json['comment_id']),
      taskId: TaskModel._parseInt(json['task_id']),
      userId: TaskModel._parseInt(json['user_id']),
      userName: TaskModel._firstNonEmptyString([
        json['user_full_name'],
        json['user_name'],
        json['author_name'],
        userMap?['full_name'],
        userMap?['name'],
        json['user_username'],
        userMap?['username'],
      ]),
      userEmail: TaskModel._firstNonEmptyString([
        json['user_email'],
        json['author_email'],
        userMap?['email'],
      ]),
      userAvatarUrl: TaskModel._firstNonEmptyString([
        json['user_profile_pic'],
        json['profile_pic'],
        json['user_avatar_url'],
        json['author_avatar_url'],
        userMap?['profile_pic'],
        userMap?['profile_picture'],
        userMap?['avatar_url'],
        userMap?['avatar'],
      ]),
      commentText: json['comment_text'] as String? ?? '',
      createdAt: TaskModel._parseDateTime(json['created_at']),
    );
  }

  TaskMemberPreview get authorPreview {
    return TaskMemberPreview(
      userId: userId,
      name: userName,
      email: userEmail,
      avatarUrl: userAvatarUrl,
      fallbackLabel: 'Comment author',
    );
  }
}

class TaskListItem {
  final TaskModel task;
  final TaskProjectSummary project;

  const TaskListItem({required this.task, required this.project});

  factory TaskListItem.fromJson(Map<String, dynamic> json) {
    return TaskListItem(
      task: TaskModel.fromJson(json['task'] as Map<String, dynamic>),
      project: TaskProjectSummary.fromJson(
        json['project'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {'task': task.toJson(), 'project': project.toJson()};
  }
}

class TaskBoardData {
  final List<TaskProjectSummary> projects;
  final List<TaskListItem> tasks;
  final DateTime? lastSyncedAt;
  final bool isFromCache;

  const TaskBoardData({
    required this.projects,
    required this.tasks,
    this.lastSyncedAt,
    this.isFromCache = false,
  });

  factory TaskBoardData.fromJson(
    Map<String, dynamic> json, {
    DateTime? lastSyncedAt,
    bool isFromCache = false,
  }) {
    final projects = json['projects'] as List? ?? const [];
    final tasks = json['tasks'] as List? ?? const [];

    return TaskBoardData(
      projects: projects
          .whereType<Map<String, dynamic>>()
          .map(TaskProjectSummary.fromJson)
          .toList(),
      tasks: tasks
          .whereType<Map<String, dynamic>>()
          .map(TaskListItem.fromJson)
          .toList(),
      lastSyncedAt: lastSyncedAt,
      isFromCache: isFromCache,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'projects': projects.map((project) => project.toJson()).toList(),
      'tasks': tasks.map((item) => item.toJson()).toList(),
    };
  }
}

class TaskCreateRequest {
  final int projectId;
  final String title;
  final String? description;
  final TaskPriority priority;
  final DateTime? dueDate;
  final int? assignedTo;

  const TaskCreateRequest({
    required this.projectId,
    required this.title,
    required this.description,
    required this.priority,
    required this.dueDate,
    this.assignedTo,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{'title': title, 'priority': priority.value};

    if (description != null) {
      data['description'] = description;
    }

    if (dueDate != null) {
      data['due_date'] = dueDate!.toIso8601String();
    }

    if (assignedTo != null) {
      data['assigned_to'] = assignedTo;
    }

    return data;
  }
}

class TaskUpdateRequest {
  final String? title;
  final String? description;
  final TaskPriority? priority;
  final TaskStatus? status;
  final DateTime? dueDate;

  const TaskUpdateRequest({
    this.title,
    this.description,
    this.priority,
    this.status,
    this.dueDate,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};

    if (title != null) {
      data['title'] = title;
    }

    if (description != null) {
      data['description'] = description;
    }

    if (priority != null) {
      data['priority'] = priority!.value;
    }

    if (status != null) {
      data['status'] = status!.value;
    }

    if (dueDate != null) {
      data['due_date'] = dueDate!.toIso8601String();
    }

    return data;
  }
}

String formatShortDate(DateTime date) {
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

String formatInputDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();

  return '$day/$month/$year';
}

int compareTaskItemsByDueDate(TaskListItem first, TaskListItem second) {
  final dueComparison = _compareNullableDates(
    first.task.dueDate,
    second.task.dueDate,
  );

  if (dueComparison != 0) {
    return dueComparison;
  }

  return second.task.createdAt.compareTo(first.task.createdAt);
}

int compareUpcomingTaskItems(TaskListItem first, TaskListItem second) {
  final dueComparison = _compareNullableDates(
    first.task.dueDate,
    second.task.dueDate,
  );

  if (dueComparison != 0) {
    return dueComparison;
  }

  final priorityComparison =
      _priorityRank(second.task.priority) - _priorityRank(first.task.priority);

  if (priorityComparison != 0) {
    return priorityComparison;
  }

  return second.task.createdAt.compareTo(first.task.createdAt);
}

int _compareNullableDates(DateTime? first, DateTime? second) {
  if (first == null && second != null) {
    return 1;
  }

  if (first != null && second == null) {
    return -1;
  }

  if (first != null && second != null) {
    return first.compareTo(second);
  }

  return 0;
}

int _priorityRank(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.low:
      return 0;
    case TaskPriority.medium:
      return 1;
    case TaskPriority.high:
      return 2;
  }
}
