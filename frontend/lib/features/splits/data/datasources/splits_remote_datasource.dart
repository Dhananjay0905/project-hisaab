/// SplitsRemoteDataSource — all HTTP calls for splits.
library;

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/split_model.dart';

class SplitsRemoteDataSource {
  const SplitsRemoteDataSource(this._client);
  final ApiClient _client;

  Future<List<SplitGroupModel>> getSplits() async {
    final response = await _client.get<Map<String, dynamic>>(ApiEndpoints.splits);
    final data = response.data!['data'];
    final list = data is List ? data : (data as Map<String, dynamic>)['splits'] as List<dynamic>;
    return list
        .map((e) => SplitGroupModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SplitGroupModel> createSplit({
    required String title,
    required double totalAmount,
    required List<String> participantNames,
    String? note,
    DateTime? date,
    String? categoryId,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.splits,
      data: {
        'title': title,
        'totalAmount': totalAmount,
        'participantNames': participantNames,
        if (note != null && note.isNotEmpty) 'note': note,
        if (date != null) 'date': date.toIso8601String(),
        if (categoryId != null) 'categoryId': categoryId,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return SplitGroupModel.fromJson(data);
  }

  Future<SplitGroupModel> updateSplit(String id, {String? title, String? note, String? categoryId}) async {
    final response = await _client.put<Map<String, dynamic>>(
      ApiEndpoints.splitById(id),
      data: {
        if (title != null) 'title': title,
        if (note != null) 'note': note,
        'categoryId': categoryId, // always send (null = remove)
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return SplitGroupModel.fromJson(data);
  }

  Future<void> deleteSplit(String id) async {
    await _client.delete<Map<String, dynamic>>(ApiEndpoints.splitById(id));
  }

  Future<SplitParticipantModel> markParticipantPaid(
    String splitId,
    String participantId, {
    required bool createTransaction,
    double? paidAmount,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      ApiEndpoints.splitParticipantPay(splitId, participantId),
      data: {
        'createTransaction': createTransaction,
        if (paidAmount != null) 'paidAmount': paidAmount,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    final participantJson = data['participant'] as Map<String, dynamic>;
    return SplitParticipantModel.fromJson(participantJson, splitId);
  }

  Future<SplitParticipantModel> unmarkParticipantPaid(
    String splitId,
    String participantId,
  ) async {
    final response = await _client.patch<Map<String, dynamic>>(
      ApiEndpoints.splitParticipantUnpay(splitId, participantId),
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    final participantJson = data.containsKey('participant')
        ? data['participant'] as Map<String, dynamic>
        : data;
    return SplitParticipantModel.fromJson(participantJson, splitId);
  }
}
