/// Savings Riverpod provider.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/savings_remote_datasource.dart';
import '../../domain/entities/savings.dart';

final _savingsDsProvider = Provider<SavingsRemoteDataSource>(
  (ref) => SavingsRemoteDataSource(ApiClient.instance),
);

class SavingsNotifier extends AsyncNotifier<Savings> {
  @override
  Future<Savings> build() async {
    final authAsync = ref.watch(authNotifierProvider);
    if (authAsync.isLoading) return Savings.empty;
    final auth = authAsync.valueOrNull;
    if (auth is! AuthAuthenticated) return Savings.empty;

    return ref.read(_savingsDsProvider).getSavings();
  }

  Future<void> updateTotal(double amount) async {
    final ds = ref.read(_savingsDsProvider);
    final updated = await ds.updateSavings(totalAmount: amount);
    state = AsyncData(updated);
  }

  Future<void> updateCashDeduction(double amount) async {
    final ds = ref.read(_savingsDsProvider);
    final updated = await ds.updateSavings(cashDeduction: amount);
    state = AsyncData(updated);
  }

  Future<void> toggleDeductFromBalance({required bool value}) async {
    final ds = ref.read(_savingsDsProvider);
    final updated = await ds.updateSavings(deductFromBalance: value);
    state = AsyncData(updated);
  }

  /// Called after wishlist changes to re-fetch updated wishlistDeduction.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final savingsProvider =
    AsyncNotifierProvider<SavingsNotifier, Savings>(SavingsNotifier.new);
