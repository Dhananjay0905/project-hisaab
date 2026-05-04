/// Categories state + Riverpod providers.
///
/// [categoriesProvider] — AsyncNotifier that auto-loads the category list on mount.
/// [categoryMutationProvider] — exposes create/update/delete actions that
/// invalidate [categoriesProvider] on success so the list is always fresh.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/datasources/category_remote_datasource.dart';
import '../../data/repositories/category_repository_impl.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';

// ─── DI Providers ─────────────────────────────────────────────────────────────

final _categoryRemoteDataSourceProvider =
    Provider<CategoryRemoteDataSource>((ref) {
  return CategoryRemoteDataSource(ApiClient.instance);
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepositoryImpl(ref.watch(_categoryRemoteDataSourceProvider));
});

// ─── Category List ────────────────────────────────────────────────────────────

/// Fetches and caches all categories for the logged-in user.
/// Separate convenience derivations below split by type for UI use.
class CategoriesNotifier extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() async {
    final repo = ref.watch(categoryRepositoryProvider);
    return repo.getCategories();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  Future<Category> addCategory({
    required String name,
    required String emoji,
    required String type,
    double? monthlyLimit,
  }) async {
    final repo = ref.read(categoryRepositoryProvider);
    final newCategory = await repo.createCategory(
      name: name,
      emoji: emoji,
      type: type,
      monthlyLimit: monthlyLimit,
    );
    // Optimistic: append to current list
    state = state.whenData((list) => [...list, newCategory]);
    return newCategory;
  }

  Future<Category> updateCategory(
    String id, {
    String? name,
    String? emoji,
    Object? monthlyLimit,
  }) async {
    final repo = ref.read(categoryRepositoryProvider);
    final updated = await repo.updateCategory(
      id,
      name: name,
      emoji: emoji,
      monthlyLimit: monthlyLimit,
    );
    state = state.whenData(
      (list) => list.map((c) => c.id == id ? updated : c).toList(),
    );
    return updated;
  }

  Future<void> removeCategory(String id) async {
    final repo = ref.read(categoryRepositoryProvider);
    await repo.deleteCategory(id);
    state = state.whenData((list) => list.where((c) => c.id != id).toList());
  }
}

final categoriesProvider =
    AsyncNotifierProvider<CategoriesNotifier, List<Category>>(
  CategoriesNotifier.new,
);

// ─── Derived: filtered by type ────────────────────────────────────────────────

/// Income categories only — filtered from [categoriesProvider].
final incomeCategoriesProvider = Provider<List<Category>>((ref) {
  final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
  return categories.where((c) => c.isIncome).toList();
});

/// Expense categories only — filtered from [categoriesProvider].
final expenseCategoriesProvider = Provider<List<Category>>((ref) {
  final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
  return categories.where((c) => c.isExpense).toList();
});
