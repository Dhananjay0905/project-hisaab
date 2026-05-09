/// CategoryRemoteDataSource — all HTTP calls for categories.
/// Throws [AppException] subtypes on failure (handled by ApiClient).
library;

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/category_model.dart';

class CategoryRemoteDataSource {
  const CategoryRemoteDataSource(this._client);
  final ApiClient _client;

  Future<List<CategoryModel>> getCategories() async {
    final response =
        await _client.get<Map<String, dynamic>>(ApiEndpoints.categories);
    final data = response.data!['data'] as Map<String, dynamic>;
    final list = data['categories'] as List<dynamic>;
    return list
        .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CategoryModel> createCategory({
    required String name,
    required String emoji,
    required String type,
    double? monthlyLimit,
    bool excludeFromAnalytics = false,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.categories,
      data: {
        'name': name,
        'emoji': emoji,
        'type': type,
        if (monthlyLimit != null) 'monthlyLimit': monthlyLimit,
        'excludeFromAnalytics': excludeFromAnalytics,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return CategoryModel.fromJson(data['category'] as Map<String, dynamic>);
  }

  Future<CategoryModel> updateCategory(
    String id, {
    String? name,
    String? emoji,
    // Pass null to explicitly clear the limit; omit entirely if not changing.
    Object? monthlyLimit = _sentinel,
    bool? excludeFromAnalytics,
  }) async {
    final response = await _client.put<Map<String, dynamic>>(
      ApiEndpoints.categoryById(id),
      data: {
        if (name != null) 'name': name,
        if (emoji != null) 'emoji': emoji,
        if (monthlyLimit != _sentinel) 'monthlyLimit': monthlyLimit,
        if (excludeFromAnalytics != null) 'excludeFromAnalytics': excludeFromAnalytics,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return CategoryModel.fromJson(data['category'] as Map<String, dynamic>);
  }

  Future<void> deleteCategory(String id) async {
    await _client.delete<Map<String, dynamic>>(ApiEndpoints.categoryById(id));
  }
}

// Sentinel so we can distinguish "not provided" from explicit null.
const Object _sentinel = Object();
