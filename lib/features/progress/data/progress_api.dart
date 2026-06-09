import '../../../core/network/api_client.dart';

class ProgressApi {
  const ProgressApi();

  Future<Map<String, dynamic>> getProjectProgress(int projectId) async {
    final data = await ApiClient.get('/projects/$projectId/progress');
    return Map<String, dynamic>.from(data as Map);
  }
}
