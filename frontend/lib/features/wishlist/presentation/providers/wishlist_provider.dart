/// Wishlist Riverpod provider.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../savings/presentation/providers/savings_provider.dart';
import '../../data/datasources/wishlist_remote_datasource.dart';
import '../../domain/entities/wishlist_item.dart';

final _wishlistDsProvider = Provider<WishlistRemoteDataSource>(
  (ref) => WishlistRemoteDataSource(ApiClient.instance),
);

class WishlistNotifier extends AsyncNotifier<List<WishlistItem>> {
  @override
  Future<List<WishlistItem>> build() async {
    final authAsync = ref.watch(authNotifierProvider);
    if (authAsync.isLoading) return [];
    final auth = authAsync.valueOrNull;
    if (auth is! AuthAuthenticated) return [];

    return ref.read(_wishlistDsProvider).listWishlist();
  }

  Future<void> addItem({
    required String title,
    required String emoji,
    double? targetPrice,
    double amountSaved = 0,
    bool deductFromSavings = true,
    String? link,
  }) async {
    final ds = ref.read(_wishlistDsProvider);
    final item = await ds.createItem(
      title: title,
      emoji: emoji,
      targetPrice: targetPrice,
      amountSaved: amountSaved,
      deductFromSavings: deductFromSavings,
      link: link,
    );
    state = AsyncData([item, ...state.valueOrNull ?? []]);
    // Savings deduction may have changed — refresh savings
    ref.read(savingsProvider.notifier).refresh();
  }

  Future<void> updateItem(
    String id, {
    String? title,
    String? emoji,
    double? targetPrice,
    double? amountSaved,
    bool? deductFromSavings,
    String? link,
  }) async {
    final ds = ref.read(_wishlistDsProvider);
    final updated = await ds.updateItem(
      id,
      title: title,
      emoji: emoji,
      targetPrice: targetPrice,
      amountSaved: amountSaved,
      deductFromSavings: deductFromSavings,
      link: link,
    );
    _replaceItem(updated);
    ref.read(savingsProvider.notifier).refresh();
  }

  Future<void> toggleDeduct(String id) async {
    final ds = ref.read(_wishlistDsProvider);
    final updated = await ds.toggleDeduct(id);
    _replaceItem(updated);
    ref.read(savingsProvider.notifier).refresh();
  }

  Future<void> markPurchased(String id) async {
    final ds = ref.read(_wishlistDsProvider);
    final updated = await ds.markPurchased(id);
    _replaceItem(updated);
    ref.read(savingsProvider.notifier).refresh();
  }

  Future<void> deleteItem(String id) async {
    final ds = ref.read(_wishlistDsProvider);
    await ds.deleteItem(id);
    state = AsyncData(
      (state.valueOrNull ?? []).where((i) => i.id != id).toList(),
    );
    ref.read(savingsProvider.notifier).refresh();
  }

  void _replaceItem(WishlistItem updated) {
    final current = List<WishlistItem>.from(state.valueOrNull ?? []);
    final idx = current.indexWhere((i) => i.id == updated.id);
    if (idx != -1) {
      current[idx] = updated;
      state = AsyncData(current);
    }
  }
}

final wishlistProvider =
    AsyncNotifierProvider<WishlistNotifier, List<WishlistItem>>(
        WishlistNotifier.new);
