/// Analytics Riverpod providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/analytics_remote_datasource.dart';
import '../../domain/entities/analytics_entities.dart';

final _analyticsDataSourceProvider =
    Provider<AnalyticsRemoteDataSource>((ref) {
  return AnalyticsRemoteDataSource(ApiClient.instance);
});

/// Last 6 months of income vs expense.
final monthlyTrendProvider =
    FutureProvider.autoDispose<List<MonthlySummary>>((ref) async {
  return ref.read(_analyticsDataSourceProvider).getMonthlyTrend();
});

/// A (year, month) pair — null means "current month".
typedef YearMonth = (int?, int?);

/// Category spending for any month.
/// Family key: (year, month) — pass (null, null) for current month.
///
/// The current-month result (null, null) is NOT autoDispose so it stays alive
/// and budget checks read the cached value instantly.
final categorySpendProvider =
    FutureProvider.family<List<CategorySpend>, YearMonth>((ref, ym) async {
  final (year, month) = ym;
  return ref
      .read(_analyticsDataSourceProvider)
      .getCategorySpend(year: year, month: month);
});
