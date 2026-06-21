import '../../../core/network/api_client.dart';
import '../models/deadline_reminder_model.dart';

class DeadlineRemindersApi {
  const DeadlineRemindersApi();

  Future<List<DeadlineReminderModel>> getMyDeadlineReminders() async {
    final response = await ApiClient.get('/deadline-reminders/me');

    if (response is List) {
      return response
          .whereType<Map>()
          .map(
            (item) =>
                DeadlineReminderModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    }

    if (response is Map) {
      final map = Map<String, dynamic>.from(response);
      final items = map['items'] ?? map['reminders'] ?? map['data'];

      if (items is List) {
        return items
            .whereType<Map>()
            .map(
              (item) => DeadlineReminderModel.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();
      }
    }

    return [];
  }

  Future<void> runDeadlineReminders() async {
    await ApiClient.postJson('/deadline-reminders/run', data: {});
  }
}
