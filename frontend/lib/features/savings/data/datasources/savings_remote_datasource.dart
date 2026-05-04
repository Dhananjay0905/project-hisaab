/// SavingsRemoteDataSource — HTTP calls for savings.
library;

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/savings_model.dart';

class SavingsRemoteDataSource {
  const SavingsRemoteDataSource(this._client);
  final ApiClient _client;

  Future<SavingsModel> getSavings() async {
    final response = await _client.get<Map<String, dynamic>>(ApiEndpoints.savings);
    final data = response.data!['data'] as Map<String, dynamic>;
    return SavingsModel.fromJson(data);
  }

  Future<SavingsModel> updateSavings({
    double? totalAmount,
    double? cashDeduction,
    bool? deductFromBalance,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      ApiEndpoints.savings,
      data: {
        if (totalAmount != null) 'totalAmount': totalAmount,
        if (cashDeduction != null) 'cashDeduction': cashDeduction,
        if (deductFromBalance != null) 'deductFromBalance': deductFromBalance,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return SavingsModel.fromJson(data);
  }
}
