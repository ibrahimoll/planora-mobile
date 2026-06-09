import '../../../core/network/api_client.dart';

class DeadlineRemindersApi {
  const DeadlineRemindersApi();

  Future<List<Map<String, dynamic>>> getMyDeadlineReminders() async {
    final data = await ApiClient.get('/deadline-reminders/me');
    if (data is! List) return [];
    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }
}
