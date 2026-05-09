/// Abstract repository contract for categories.
library;

import '../entities/category.dart';

abstract interface class CategoryRepository {
  /// Returns all categories for the current user.
  Future<List<Category>> getCategories();

  /// Creates a new custom category.
  Future<Category> createCategory({
    required String name,
    required String emoji,
    required String type,
    double? monthlyLimit,
    bool excludeFromAnalytics = false,
  });

  /// Updates name and/or emoji of an existing category.
  /// Pass [monthlyLimit] as null to clear an existing limit.
  Future<Category> updateCategory(
    String id, {
    String? name,
    String? emoji,
    Object? monthlyLimit,
    bool? excludeFromAnalytics,
  });

  /// Deletes a custom category. Throws if default or has linked transactions.
  Future<void> deleteCategory(String id);
}
