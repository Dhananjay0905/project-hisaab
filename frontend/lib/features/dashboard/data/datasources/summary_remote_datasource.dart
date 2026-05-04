/// SummaryRemoteDataSource — fetches dashboard summary from backend.
library;

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/summary_model.dart';

class SummaryRemoteDataSource {
  const SummaryRemoteDataSource(this._client);
  final ApiClient _client;

  Future<SummaryModel> getSummary() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.summary,
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return SummaryModel.fromJson(data);
  }
}
