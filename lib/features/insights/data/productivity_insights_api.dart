import '../../../core/network/api_client.dart';

class ProductivityInsightsApi {
  const ProductivityInsightsApi();

  Future<Map<String, dynamic>> getMyInsights() async {
    final data = await ApiClient.get('/insights/me');
    return Map<String, dynamic>.from(data as Map);
  }
}
