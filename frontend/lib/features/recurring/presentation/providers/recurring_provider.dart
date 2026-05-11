/// RecurringProvider — all state management for recurring transactions.
///
/// [recurringProvider]    — full list (active + paused)
/// [dueRecurringProvider] — only items due today or overdue
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../analytics/presentation/providers/analytics_provider.dart';
import '../../../dashboard/presentation/providers/summary_provider.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../data/datasources/recurring_remote_datasource.dart';
import '../../domain/entities/recurring_transaction.dart';

// ─── Datasource provider ──────────────────────────────────────────────────────

final _recurringDsProvider =
    Provider<RecurringRemoteDataSource>((ref) {
  return RecurringRemoteDataSource(ApiClient.instance);
});

// ─── Full list notifier ───────────────────────────────────────────────────────

class RecurringNotifier
    extends AsyncNotifier<List<RecurringTransaction>> {
  @override
  Future<List<RecurringTransaction>> build() {
    return ref.read(_recurringDsProvider).listAll();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> add({
    required String title,
    required double amount,
    required String type,
    required String categoryId,
    required String frequency,
    required DateTime startDate,
  }) async {
    final ds = ref.read(_recurringDsProvider);
    final newItem = await ds.create(
      title: title,
      amount: amount,
      type: type,
      categoryId: categoryId,
      frequency: frequency,
      startDate: startDate,
    );
    state = state.whenData((list) => [...list, newItem]);
  }

  Future<void> edit(
    String id, {
    String? title,
    double? amount,
    String? type,
    String? categoryId,
    String? frequency,
    DateTime? startDate,
  }) async {
    final ds = ref.read(_recurringDsProvider);
    final updated = await ds.update(
      id,
      title: title,
      amount: amount,
      type: type,
      categoryId: categoryId,
      frequency: frequency,
      startDate: startDate,
    );
    state = state.whenData(
      (list) => list.map((i) => i.id == id ? updated : i).toList(),
    );
  }

  Future<void> toggle(String id) async {
    final ds = ref.read(_recurringDsProvider);
    final updated = await ds.toggleActive(id);
    state = state.whenData(
      (list) => list.map((i) => i.id == id ? updated : i).toList(),
    );
  }

  /// Confirms a due item, creates a transaction, advances nextDueDate.
  /// Removes item from the due list if it's no longer due after confirmation.
  Future<void> confirm(String id) async {
    final ds = ref.read(_recurringDsProvider);
    await ds.confirmDue(id);
    // Refresh entire list so nextDueDate is updated
    ref.invalidateSelf();
    // Also invalidate the due-list so dialogs disappear
    ref.invalidate(dueRecurringProvider);
    // A real transaction was just created — refresh history, home & analytics
    ref.invalidate(transactionsProvider);
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(monthlyTrendProvider);
    ref.invalidate(categorySpendProvider);
  }

  Future<void> remove(String id) async {
    final ds = ref.read(_recurringDsProvider);
    await ds.delete(id);
    state = state.whenData((list) => list.where((i) => i.id != id).toList());
  }
}

final recurringProvider =
    AsyncNotifierProvider<RecurringNotifier, List<RecurringTransaction>>(
  RecurringNotifier.new,
);

// ─── Due items (for startup dialog) ──────────────────────────────────────────

final dueRecurringProvider =
    FutureProvider<List<RecurringTransaction>>((ref) async {
  return ref.read(_recurringDsProvider).listDue();
});
