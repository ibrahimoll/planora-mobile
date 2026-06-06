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

  bool get hasDescription {
    return description != null && description!.trim().isNotEmpty;
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

  TaskModel copyWith({
    String? title,
    String? description,
    TaskPriority? priority,
    double? estimatedHours,
    double? actualHours,
    TaskStatus? status,
    DateTime? dueDate,
    DateTime? completedAt,
  }) {
    return TaskModel(
      taskId: taskId,
      projectId: projectId,
      assignedTo: assignedTo,
      createdBy: createdBy,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      actualHours: actualHours ?? this.actualHours,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
    );
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
}

class TaskProjectSummary {
  final int projectId;
  final String title;
  final String status;
  final String projectType;
  final DateTime deadline;

  const TaskProjectSummary({
    required this.projectId,
    required this.title,
    required this.status,
    required this.projectType,
    required this.deadline,
  });

  factory TaskProjectSummary.fromProject(ProjectModel project) {
    return TaskProjectSummary(
      projectId: project.projectId,
      title: project.title,
      status: project.status,
      projectType: project.projectType,
      deadline: project.deadline,
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

  TaskListItem copyWith({TaskModel? task, TaskProjectSummary? project}) {
    return TaskListItem(
      task: task ?? this.task,
      project: project ?? this.project,
    );
  }
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
    return {
      'title': title,
      'description': description,
      'priority': priority.value,
      'due_date': dueDate?.toIso8601String(),
    };
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
