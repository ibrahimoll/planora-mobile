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
  final int createdBy;
  final String title;
  final String? description;
  final TaskPriority priority;
  final double? estimatedHours;
  final double? actualHours;
  final TaskStatus status;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final DateTime createdAt;

  const TaskModel({
    required this.taskId,
    required this.projectId,
    required this.assignedTo,
    required this.assignedToName,
    required this.assignedToEmail,
    required this.createdBy,
    required this.title,
    required this.description,
    required this.priority,
    required this.estimatedHours,
    required this.actualHours,
    required this.status,
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
      createdBy: _parseInt(json['created_by']),
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      priority: TaskPriority.fromJson(json['priority']),
      estimatedHours: _parseOptionalDouble(json['estimated_hours']),
      actualHours: _parseOptionalDouble(json['actual_hours']),
      status: TaskStatus.fromJson(json['status']),
      dueDate: _parseOptionalDateTime(json['due_date']),
      completedAt: _parseOptionalDateTime(json['completed_at']),
      createdAt: _parseDateTime(json['created_at']),
    );
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

    if (assignedTo != null) {
      return 'Member #$assignedTo';
    }

    return null;
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
  final String title;
  final String projectType;

  const TaskProjectSummary({
    required this.projectId,
    required this.title,
    required this.projectType,
  });

  factory TaskProjectSummary.fromProject(ProjectModel project) {
    return TaskProjectSummary(
      projectId: project.projectId,
      title: project.title,
      projectType: project.projectType,
    );
  }

  bool get isTeamProject {
    return projectType == 'team';
  }
}

class TaskListItem {
  final TaskModel task;
  final TaskProjectSummary project;

  const TaskListItem({required this.task, required this.project});
}

class TaskBoardData {
  final List<TaskProjectSummary> projects;
  final List<TaskListItem> tasks;

  const TaskBoardData({required this.projects, required this.tasks});
}

class TaskCreateRequest {
  final int projectId;
  final String title;
  final String? description;
  final TaskPriority priority;
  final DateTime? dueDate;

  const TaskCreateRequest({
    required this.projectId,
    required this.title,
    required this.description,
    required this.priority,
    required this.dueDate,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{'title': title, 'priority': priority.value};

    if (description != null) {
      data['description'] = description;
    }

    if (dueDate != null) {
      data['due_date'] = dueDate!.toIso8601String();
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
