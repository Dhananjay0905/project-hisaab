/// Splits Riverpod providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../dashboard/presentation/providers/summary_provider.dart';
import '../../data/datasources/splits_remote_datasource.dart';
import '../../data/models/split_model.dart';
import '../../domain/entities/split.dart';

// ─── DI ───────────────────────────────────────────────────────────────────────

final _splitsRemoteDataSourceProvider = Provider<SplitsRemoteDataSource>((ref) {
  return SplitsRemoteDataSource(ApiClient.instance);
});

// ─── Splits List ──────────────────────────────────────────────────────────────

class SplitsNotifier extends AsyncNotifier<List<SplitGroup>> {
  @override
  Future<List<SplitGroup>> build() => _fetch();

  Future<List<SplitGroup>> _fetch() {
    return ref.read(_splitsRemoteDataSourceProvider).getSplits();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  // ── Mutations ────────────────────────────────────────────────────────────────

  Future<SplitGroup> addSplit({
    required String title,
    required double totalAmount,
    required List<String> participantNames,
    String? note,
    DateTime? date,
    String? categoryId,
  }) async {
    final ds = ref.read(_splitsRemoteDataSourceProvider);
    final split = await ds.createSplit(
      title: title,
      totalAmount: totalAmount,
      participantNames: participantNames,
      note: note,
      date: date,
      categoryId: categoryId,
    );
    state = AsyncData([split, ...state.valueOrNull ?? []]);
    return split;
  }

  Future<SplitGroup> updateSplit(String id, {String? title, String? note, String? categoryId}) async {
    final ds = ref.read(_splitsRemoteDataSourceProvider);
    final updated = await ds.updateSplit(id, title: title, note: note, categoryId: categoryId);
    state = AsyncData(
      (state.valueOrNull ?? []).map((s) => s.id == id ? updated : s).toList(),
    );
    return updated;
  }

  Future<void> removeSplit(String id) async {
    final ds = ref.read(_splitsRemoteDataSourceProvider);
    await ds.deleteSplit(id);
    state = AsyncData(
      (state.valueOrNull ?? []).where((s) => s.id != id).toList(),
    );
  }

  Future<SplitParticipantModel> markParticipantPaid(
    String splitId,
    String participantId, {
    required bool createTransaction,
    double? paidAmount, // actual amount received (may differ from split share)
  }) async {
    final ds = ref.read(_splitsRemoteDataSourceProvider);
    final updatedParticipant = await ds.markParticipantPaid(
      splitId,
      participantId,
      createTransaction: createTransaction,
      paidAmount: paidAmount,
    );

    // Optimistically update local state
    final splits = state.valueOrNull ?? [];
    final updatedSplits = splits.map((s) {
      if (s.id != splitId) return s;
      return (s as SplitGroupModel).copyWithParticipant(updatedParticipant);
    }).toList();
    state = AsyncData(updatedSplits);

    if (createTransaction) {
      ref.invalidate(dashboardSummaryProvider);
    }

    return updatedParticipant;
  }

  Future<SplitParticipantModel> unmarkParticipantPaid(
    String splitId,
    String participantId,
  ) async {
    final ds = ref.read(_splitsRemoteDataSourceProvider);
    final updatedParticipant = await ds.unmarkParticipantPaid(splitId, participantId);

    final splits = state.valueOrNull ?? [];
    final updatedSplits = splits.map((s) {
      if (s.id != splitId) return s;
      return (s as SplitGroupModel).copyWithParticipant(updatedParticipant);
    }).toList();
    state = AsyncData(updatedSplits);

    return updatedParticipant;
  }
}

final splitsProvider = AsyncNotifierProvider<SplitsNotifier, List<SplitGroup>>(
  SplitsNotifier.new,
);
