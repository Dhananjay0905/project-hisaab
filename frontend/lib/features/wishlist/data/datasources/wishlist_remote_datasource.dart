/// WishlistRemoteDataSource — HTTP calls for wishlist.
library;

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/wishlist_item_model.dart';

class WishlistRemoteDataSource {
  const WishlistRemoteDataSource(this._client);
  final ApiClient _client;

  Future<List<WishlistItemModel>> listWishlist() async {
    final response =
        await _client.get<Map<String, dynamic>>(ApiEndpoints.wishlist);
    final data = response.data!['data'] as List<dynamic>;
    return data
        .map((e) => WishlistItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WishlistItemModel> createItem({
    required String title,
    required String emoji,
    double? targetPrice,
    double amountSaved = 0,
    bool deductFromSavings = true,
    String? link,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.wishlist,
      data: {
        'title': title,
        'emoji': emoji,
        if (targetPrice != null) 'targetPrice': targetPrice,
        'amountSaved': amountSaved,
        'deductFromSavings': deductFromSavings,
        if (link != null && link.isNotEmpty) 'link': link,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return WishlistItemModel.fromJson(data);
  }

  Future<WishlistItemModel> updateItem(
    String id, {
    String? title,
    String? emoji,
    double? targetPrice,
    double? amountSaved,
    bool? deductFromSavings,
    String? link,
  }) async {
    final response = await _client.put<Map<String, dynamic>>(
      ApiEndpoints.wishlistById(id),
      data: {
        if (title != null) 'title': title,
        if (emoji != null) 'emoji': emoji,
        if (targetPrice != null) 'targetPrice': targetPrice,
        if (amountSaved != null) 'amountSaved': amountSaved,
        if (deductFromSavings != null) 'deductFromSavings': deductFromSavings,
        if (link != null) 'link': link.isEmpty ? null : link,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return WishlistItemModel.fromJson(data);
  }

  Future<WishlistItemModel> toggleDeduct(String id) async {
    final response = await _client.patch<Map<String, dynamic>>(
      ApiEndpoints.wishlistToggleDeduct(id),
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return WishlistItemModel.fromJson(data);
  }

  Future<WishlistItemModel> markPurchased(String id) async {
    final response = await _client.patch<Map<String, dynamic>>(
      ApiEndpoints.wishlistMarkPurchased(id),
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return WishlistItemModel.fromJson(data);
  }

  Future<void> deleteItem(String id) async {
    await _client.delete<Map<String, dynamic>>(ApiEndpoints.wishlistById(id));
  }
}
