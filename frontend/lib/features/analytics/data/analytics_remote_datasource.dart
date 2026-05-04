/// Analytics remote data source — calls the two analytics endpoints.
library;

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/entities/analytics_entities.dart';

class AnalyticsRemoteDataSource {
  const AnalyticsRemoteDataSource(this._client);
  final ApiClient _client;

  Future<List<MonthlySummary>> getMonthlyTrend() async {
    final response =
        await _client.get<Map<String, dynamic>>(ApiEndpoints.analyticsMonthly);
    final data = response.data!['data'] as Map<String, dynamic>;
    final list = data['trend'] as List<dynamic>;
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return MonthlySummary(
        month:   m['month'] as String,
        income:  (m['income'] as num).toDouble(),
        expense: (m['expense'] as num).toDouble(),
      );
    }).toList();
  }

  Future<List<CategorySpend>> getCategorySpend({int? year, int? month}) async {
    final queryParams = <String, String>{};
    if (year  != null) queryParams['year']  = year.toString();
    if (month != null) queryParams['month'] = month.toString();

    final response = await _client
        .get<Map<String, dynamic>>(ApiEndpoints.analyticsCategories,
            queryParameters: queryParams.isEmpty ? null : queryParams);
    final data = response.data!['data'] as Map<String, dynamic>;
    final list = data['categories'] as List<dynamic>;
    return list.map((e) {
      final c = e as Map<String, dynamic>;
      return CategorySpend(
        categoryId: c['categoryId'] as String?,
        name:       c['name'] as String,
        emoji:      c['emoji'] as String,
        spent:      (c['spent'] as num).toDouble(),
        limit:      (c['limit'] as num?)?.toDouble(),
      );
    }).toList();
  }
}
