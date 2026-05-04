/// Dues Riverpod providers.
///
/// [duesProvider]        — full list; split by type/isPaid in UI.
/// [duesSummaryProvider] — iOweTotal, theyOweTotal, effectiveBalance.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../dashboard/presentation/providers/summary_provider.dart';
import '../../data/datasources/dues_remote_datasource.dart';
import '../../data/models/due_model.dart';
import '../../domain/entities/due.dart';

// ─── DI ───────────────────────────────────────────────────────────────────────

final _duesRemoteDataSourceProvider = Provider<DuesRemoteDataSource>((ref) {
  return DuesRemoteDataSource(ApiClient.instance);
});

// ─── Dues List ────────────────────────────────────────────────────────────────

class DuesNotifier extends AsyncNotifier<List<Due>> {
  @override
  Future<List<Due>> build() => _fetch();

  Future<List<Due>> _fetch() {
    return ref.read(_duesRemoteDataSourceProvider).getDues();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  // ── Mutations ────────────────────────────────────────────────────────────────

  Future<Due> addDue({
    required String title,
    required String personName,
    required double amount,
    required String type,
    String? note,
    DateTime? dueDate,
  }) async {
    final ds = ref.read(_duesRemoteDataSourceProvider);
    final due = await ds.createDue(
      title: title,
      personName: personName,
      amount: amount,
      type: type,
      note: note,
      dueDate: dueDate,
    );
    // Prepend to list
    state = AsyncData([due, ...state.valueOrNull ?? []]);
    ref.invalidate(duesSummaryProvider);
    return due;
  }

  Future<Due> settleDue(String id, {bool logAsTransaction = false}) async {
    final ds = ref.read(_duesRemoteDataSourceProvider);
    final settled = await ds.settleDue(id, logAsTransaction: logAsTransaction);
    // Replace in list
    state = AsyncData(
      (state.valueOrNull ?? []).map((d) => d.id == id ? settled : d).toList(),
    );
    ref.invalidate(duesSummaryProvider);
    if (logAsTransaction) ref.invalidate(dashboardSummaryProvider);
    return settled;
  }

  Future<Due> updateDue(
    String id, {
    String? title,
    String? personName,
    double? amount,
    String? type,
    String? note,
    DateTime? dueDate,
  }) async {
    final ds = ref.read(_duesRemoteDataSourceProvider);
    final updated = await ds.updateDue(
      id,
      title: title,
      personName: personName,
      amount: amount,
      type: type,
      note: note,
      dueDate: dueDate,
    );
    state = AsyncData(
      (state.valueOrNull ?? []).map((d) => d.id == id ? updated : d).toList(),
    );
    ref.invalidate(duesSummaryProvider);
    return updated;
  }

  Future<void> removeDue(String id) async {
    final ds = ref.read(_duesRemoteDataSourceProvider);
    await ds.deleteDue(id);
    state = AsyncData(
      (state.valueOrNull ?? []).where((d) => d.id != id).toList(),
    );
    ref.invalidate(duesSummaryProvider);
  }
}

final duesProvider = AsyncNotifierProvider<DuesNotifier, List<Due>>(
  DuesNotifier.new,
);

// ─── Summary ──────────────────────────────────────────────────────────────────

class DuesSummaryNotifier extends AsyncNotifier<DuesSummaryModel> {
  @override
  Future<DuesSummaryModel> build() =>
      ref.read(_duesRemoteDataSourceProvider).getDuesSummary();

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final duesSummaryProvider =
    AsyncNotifierProvider<DuesSummaryNotifier, DuesSummaryModel>(
  DuesSummaryNotifier.new,
);
