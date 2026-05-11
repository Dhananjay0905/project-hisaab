/// DuesRemoteDataSource — all HTTP calls for dues.
library;

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/due_model.dart';

class DuesRemoteDataSource {
  const DuesRemoteDataSource(this._client);
  final ApiClient _client;

  Future<List<DueModel>> getDues({String? type, String? isPaid}) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.dues,
      queryParameters: {
        if (type != null) 'type': type,
        if (isPaid != null) 'isPaid': isPaid,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    final list = data['dues'] as List<dynamic>;
    return list.map((e) => DueModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DuesSummaryModel> getDuesSummary() async {
    final response = await _client.get<Map<String, dynamic>>(
      '${ApiEndpoints.dues}/summary',
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return DuesSummaryModel.fromJson(data['summary'] as Map<String, dynamic>);
  }

  Future<DueModel> createDue({
    required String title,
    required String personName,
    required double amount,
    required String type,
    String? note,
    DateTime? dueDate,
    String? categoryId,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.dues,
      data: {
        'title': title,
        'personName': personName,
        'amount': amount,
        'type': type,
        if (note != null && note.isNotEmpty) 'note': note,
        if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
        if (categoryId != null) 'categoryId': categoryId,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return DueModel.fromJson(data['due'] as Map<String, dynamic>);
  }

  Future<DueModel> updateDue(
    String id, {
    String? title,
    String? personName,
    double? amount,
    String? type,
    String? note,
    DateTime? dueDate,
    String? categoryId,
  }) async {
    final response = await _client.put<Map<String, dynamic>>(
      ApiEndpoints.dueById(id),
      data: {
        if (title != null) 'title': title,
        if (personName != null) 'personName': personName,
        if (amount != null) 'amount': amount,
        if (type != null) 'type': type,
        if (note != null) 'note': note,
        if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
        'categoryId': categoryId, // always send (null = remove category)
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return DueModel.fromJson(data['due'] as Map<String, dynamic>);
  }

  Future<DueModel> settleDue(String id, {bool logAsTransaction = false}) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.dueSettle(id),
      data: {'logAsTransaction': logAsTransaction},
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return DueModel.fromJson(data['due'] as Map<String, dynamic>);
  }

  Future<void> deleteDue(String id) async {
    await _client.delete<Map<String, dynamic>>(ApiEndpoints.dueById(id));
  }
}
