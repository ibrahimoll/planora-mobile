import '../../../core/network/api_client.dart';
import '../models/productivity_insights_model.dart';

class ProductivityInsightsApi {
  const ProductivityInsightsApi();

  Future<ProductivityInsightsModel> getMyInsights() async {
    final response = await ApiClient.get('/insights/me');

    if (response is! Map) {
      throw const FormatException('Invalid productivity insights response.');
    }

    return ProductivityInsightsModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }
}
