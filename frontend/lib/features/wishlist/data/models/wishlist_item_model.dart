/// WishlistItemModel — JSON ↔ WishlistItem entity mapping.
library;

import '../../domain/entities/wishlist_item.dart';

class WishlistItemModel extends WishlistItem {
  const WishlistItemModel({
    required super.id,
    required super.title,
    required super.emoji,
    required super.amountSaved,
    required super.deductFromSavings,
    required super.isPurchased,
    required super.createdAt,
    super.targetPrice,
    super.link,
    super.purchasedAt,
  });

  factory WishlistItemModel.fromJson(Map<String, dynamic> json) {
    return WishlistItemModel(
      id: json['id'] as String,
      title: json['title'] as String,
      emoji: json['emoji'] as String? ?? '🛍️',
      targetPrice: json['targetPrice'] != null
          ? (json['targetPrice'] as num).toDouble()
          : null,
      amountSaved: (json['amountSaved'] as num).toDouble(),
      deductFromSavings: json['deductFromSavings'] as bool? ?? true,
      link: json['link'] as String?,
      isPurchased: json['isPurchased'] as bool? ?? false,
      purchasedAt: json['purchasedAt'] != null
          ? DateTime.parse(json['purchasedAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
