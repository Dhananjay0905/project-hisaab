/// Transactions Riverpod providers.
///
/// [transactionsProvider] — paginated list with filters.
/// [transactionMutationProvider] — create/update/delete actions.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/datasources/transaction_remote_datasource.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../domain/entities/transaction.dart';
import '../../../analytics/presentation/providers/analytics_provider.dart';
import '../../../dashboard/presentation/providers/summary_provider.dart';

// ─── DI ───────────────────────────────────────────────────────────────────────

final _transactionRemoteDataSourceProvider =
    Provider<TransactionRemoteDataSource>((ref) {
  return TransactionRemoteDataSource(ApiClient.instance);
});

final transactionRepositoryProvider =
    Provider<TransactionRepositoryImpl>((ref) {
  return TransactionRepositoryImpl(
    ref.watch(_transactionRemoteDataSourceProvider),
  );
});

// ─── Filter State ─────────────────────────────────────────────────────────────

class TransactionFilters {
  const TransactionFilters({
    this.type,
    this.categoryIds = const [],
    this.search,
    this.startDate,
    this.endDate,
    this.page = 1,
  });

  final String? type;        // 'INCOME' | 'EXPENSE' | null (all)
  final List<String> categoryIds;
  final String? search;
  final String? startDate;
  final String? endDate;
  final int page;

  TransactionFilters copyWith({
    String? type,
    List<String>? categoryIds,
    String? search,
    String? startDate,
    String? endDate,
    int? page,
    bool clearType = false,
    bool clearSearch = false,
    bool clearCategoryIds = false,
  }) {
    return TransactionFilters(
      type: clearType ? null : (type ?? this.type),
      categoryIds: clearCategoryIds ? [] : (categoryIds ?? this.categoryIds),
      search: clearSearch ? null : (search ?? this.search),
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      page: page ?? this.page,
    );
  }
}

// ─── Transaction List ─────────────────────────────────────────────────────────

class TransactionsNotifier extends AsyncNotifier<TransactionPage> {
  TransactionFilters _filters = const TransactionFilters();

  TransactionFilters get filters => _filters;

  @override
  Future<TransactionPage> build() async {
    return _fetch(_filters);
  }

  Future<TransactionPage> _fetch(TransactionFilters filters) async {
    final repo = ref.read(transactionRepositoryProvider);
    return repo.getTransactions(
      page: filters.page,
      type: filters.type,
      categoryIds: filters.categoryIds,
      search: filters.search,
      startDate: filters.startDate,
      endDate: filters.endDate,
    );
  }

  Future<void> applyFilters(TransactionFilters filters) async {
    _filters = filters.copyWith(page: 1);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(_filters));
  }

  Future<void> loadNextPage() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasNext) return;
    final nextFilters = _filters.copyWith(page: _filters.page + 1);
    final nextPage = await _fetch(nextFilters);
    _filters = nextFilters;
    state = AsyncData(TransactionPage(
      items: [...current.items, ...nextPage.items],
      total: nextPage.total,
      page: nextPage.page,
      limit: nextPage.limit,
      pages: nextPage.pages,
      hasNext: nextPage.hasNext,
      hasPrev: nextPage.hasPrev,
    ));
  }

  Future<void> refresh() async {
    _filters = _filters.copyWith(page: 1);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(_filters));
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  Future<Transaction> addTransaction({
    required String title,
    required double amount,
    required String type,
    required DateTime date,
    String? note,
    String? categoryId,
    bool excludeFromAnalytics = false,
  }) async {
    final repo = ref.read(transactionRepositoryProvider);
    final tx = await repo.createTransaction(
      title: title,
      amount: amount,
      type: type,
      date: date,
      note: note,
      categoryId: categoryId,
      excludeFromAnalytics: excludeFromAnalytics,
    );
    // Refresh the history list and invalidate all summary/analytics caches
    await refresh();
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(monthlyTrendProvider);
    ref.invalidate(categorySpendProvider);
    return tx;
  }

  Future<Transaction> updateTransaction(
    String id, {
    required String title,
    required double amount,
    required String type,
    required DateTime date,
    String? note,
    String? categoryId,
    bool? excludeFromAnalytics,
  }) async {
    final repo = ref.read(transactionRepositoryProvider);
    final tx = await repo.updateTransaction(
      id,
      title: title,
      amount: amount,
      type: type,
      date: date,
      note: note,
      categoryId: categoryId,
      excludeFromAnalytics: excludeFromAnalytics,
    );
    // Update in-place so the list reflects changes instantly
    state = state.whenData((page) => TransactionPage(
          items: page.items.map((t) => t.id == id ? tx : t).toList(),
          total: page.total,
          page: page.page,
          limit: page.limit,
          pages: page.pages,
          hasNext: page.hasNext,
          hasPrev: page.hasPrev,
        ));
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(monthlyTrendProvider);
    ref.invalidate(categorySpendProvider);
    return tx;
  }

  Future<void> removeTransaction(String id) async {
    final repo = ref.read(transactionRepositoryProvider);
    await repo.deleteTransaction(id);
    state = state.whenData(
      (page) => TransactionPage(
        items: page.items.where((t) => t.id != id).toList(),
        total: page.total - 1,
        page: page.page,
        limit: page.limit,
        pages: page.pages,
        hasNext: page.hasNext,
        hasPrev: page.hasPrev,
      ),
    );
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(monthlyTrendProvider);
    ref.invalidate(categorySpendProvider);
  }
}

final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, TransactionPage>(
  TransactionsNotifier.new,
);
