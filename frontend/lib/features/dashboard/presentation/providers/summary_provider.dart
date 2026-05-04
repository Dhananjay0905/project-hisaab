/// Summary Riverpod provider — fetches dashboard data.
/// Only fetches when the user is authenticated. Auto-refreshes on auth change.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/summary_remote_datasource.dart';
import '../../domain/entities/summary.dart';

// ─── DI ───────────────────────────────────────────────────────────────────────

final _summaryRemoteDataSourceProvider =
    Provider<SummaryRemoteDataSource>((ref) {
  return SummaryRemoteDataSource(ApiClient.instance);
});

// ─── Summary Notifier ────────────────────────────────────────────────────────

class SummaryNotifier extends AsyncNotifier<Summary> {
  @override
  Future<Summary> build() async {
    // Watch auth — this notifier rebuilds whenever auth changes.
    final authAsync = ref.watch(authNotifierProvider);

    // Auth still resolving → return empty immediately (no loading spinner, no error).
    // The router is on /splash during this time anyway.
    if (authAsync.isLoading) return Summary.empty;

    // Not authenticated → return empty (router will redirect to /login anyway)
    final auth = authAsync.valueOrNull;
    if (auth is! AuthAuthenticated) return Summary.empty;

    // Authenticated — fetch from API
    final ds = ref.read(_summaryRemoteDataSourceProvider);
    return ds.getSummary();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final dashboardSummaryProvider =
    AsyncNotifierProvider<SummaryNotifier, Summary>(SummaryNotifier.new);
