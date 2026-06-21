class DeadlineReminderModel {
  final int reminderId;
  final int? taskId;
  final int? projectId;
  final String title;
  final String? message;
  final String? taskTitle;
  final String? projectTitle;
  final DateTime? dueDate;
  final DateTime? createdAt;
  final bool isSent;

  const DeadlineReminderModel({
    required this.reminderId,
    required this.title,
    this.taskId,
    this.projectId,
    this.message,
    this.taskTitle,
    this.projectTitle,
    this.dueDate,
    this.createdAt,
    required this.isSent,
  });

  factory DeadlineReminderModel.fromJson(Map<String, dynamic> json) {
    return DeadlineReminderModel(
      reminderId: _parseInt(
        json['reminder_id'] ?? json['id'] ?? json['deadline_reminder_id'],
      ),
      taskId: _parseNullableInt(json['task_id']),
      projectId: _parseNullableInt(json['project_id']),
      title: _parseString(
        json['title'] ??
            json['task_title'] ??
            json['name'] ??
            'Deadline reminder',
      ),
      message: _parseNullableString(json['message'] ?? json['body']),
      taskTitle: _parseNullableString(json['task_title']),
      projectTitle: _parseNullableString(json['project_title']),
      dueDate: _parseDate(json['due_date'] ?? json['deadline']),
      createdAt: _parseDate(json['created_at']),
      isSent: json['is_sent'] == true || json['sent'] == true,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static String _parseString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? 'Deadline reminder' : text;
  }

  static String? _parseNullableString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
