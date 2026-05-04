/// TransactionRemoteDataSource — all HTTP calls for transactions.
library;

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/transaction_model.dart';

class TransactionRemoteDataSource {
  const TransactionRemoteDataSource(this._client);
  final ApiClient _client;

  Future<TransactionPageModel> getTransactions({
    int page = 1,
    int limit = 20,
    String? type,
    String? categoryId,
    String? startDate,
    String? endDate,
    String? search,
    String sortBy = 'date',
    String sortOrder = 'desc',
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.transactions,
      queryParameters: {
        'page': page,
        'limit': limit,
        if (type != null) 'type': type,
        if (categoryId != null) 'categoryId': categoryId,
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        if (search != null && search.isNotEmpty) 'search': search,
        'sortBy': sortBy,
        'sortOrder': sortOrder,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return TransactionPageModel.fromJson(data);
  }

  Future<TransactionModel> getTransaction(String id) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.transactionById(id),
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return TransactionModel.fromJson(data['transaction'] as Map<String, dynamic>);
  }

  Future<TransactionModel> createTransaction({
    required String title,
    required double amount,
    required String type,
    required DateTime date,
    String? note,
    String? categoryId,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.transactions,
      data: {
        'title': title,
        'amount': amount,
        'type': type,
        'date': date.toIso8601String(),
        if (note != null && note.isNotEmpty) 'note': note,
        if (categoryId != null) 'categoryId': categoryId,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return TransactionModel.fromJson(data['transaction'] as Map<String, dynamic>);
  }

  Future<TransactionModel> updateTransaction(
    String id, {
    String? title,
    double? amount,
    String? type,
    DateTime? date,
    String? note,
    String? categoryId,
  }) async {
    final response = await _client.put<Map<String, dynamic>>(
      ApiEndpoints.transactionById(id),
      data: {
        if (title != null) 'title': title,
        if (amount != null) 'amount': amount,
        if (type != null) 'type': type,
        if (date != null) 'date': date.toIso8601String(),
        if (note != null) 'note': note,
        if (categoryId != null) 'categoryId': categoryId,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return TransactionModel.fromJson(data['transaction'] as Map<String, dynamic>);
  }

  Future<void> deleteTransaction(String id) async {
    await _client.delete<Map<String, dynamic>>(ApiEndpoints.transactionById(id));
  }
}
