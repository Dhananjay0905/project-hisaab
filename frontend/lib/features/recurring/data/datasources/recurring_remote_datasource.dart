/// RecurringRemoteDataSource — all HTTP calls for recurring transactions.
library;

import '../../../../core/network/api_client.dart';
import '../models/recurring_transaction_model.dart';

class RecurringRemoteDataSource {
  const RecurringRemoteDataSource(this._client);
  final ApiClient _client;

  static const _base = '/recurring';

  Future<List<RecurringTransactionModel>> listAll() async {
    final res = await _client.get<Map<String, dynamic>>(_base);
    final list = res.data!['data'] as List<dynamic>;
    return list
        .map((e) =>
            RecurringTransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<RecurringTransactionModel>> listDue() async {
    final res = await _client.get<Map<String, dynamic>>('$_base/due');
    final list = res.data!['data'] as List<dynamic>;
    return list
        .map((e) =>
            RecurringTransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<RecurringTransactionModel> create({
    required String title,
    required double amount,
    required String type,
    required String categoryId,
    required String frequency,
    required DateTime startDate,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      _base,
      data: {
        'title': title,
        'amount': amount,
        'type': type,
        'categoryId': categoryId,
        'frequency': frequency,
        'startDate': startDate.toIso8601String(),
      },
    );
    return RecurringTransactionModel.fromJson(
        res.data!['data'] as Map<String, dynamic>);
  }

  Future<RecurringTransactionModel> update(
    String id, {
    String? title,
    double? amount,
    String? type,
    String? categoryId,
    String? frequency,
    DateTime? startDate,
  }) async {
    final res = await _client.put<Map<String, dynamic>>(
      '$_base/$id',
      data: {
        if (title != null) 'title': title,
        if (amount != null) 'amount': amount,
        if (type != null) 'type': type,
        if (categoryId != null) 'categoryId': categoryId,
        if (frequency != null) 'frequency': frequency,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
      },
    );
    return RecurringTransactionModel.fromJson(
        res.data!['data'] as Map<String, dynamic>);
  }

  Future<RecurringTransactionModel> toggleActive(String id) async {
    final res = await _client.patch<Map<String, dynamic>>('$_base/$id/toggle');
    return RecurringTransactionModel.fromJson(
        res.data!['data'] as Map<String, dynamic>);
  }

  Future<void> confirmDue(String id) async {
    await _client.post<Map<String, dynamic>>('$_base/$id/confirm');
  }

  Future<void> delete(String id) async {
    await _client.delete<Map<String, dynamic>>('$_base/$id');
  }
}
