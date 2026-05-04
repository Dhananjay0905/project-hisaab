/// WishlistItem entity.
library;

class WishlistItem {
  const WishlistItem({
    required this.id,
    required this.title,
    required this.emoji,
    required this.amountSaved,
    required this.deductFromSavings,
    required this.isPurchased,
    required this.createdAt,
    this.targetPrice,
    this.link,
    this.purchasedAt,
  });

  final String id;
  final String title;
  final String emoji;
  final double? targetPrice;
  final double amountSaved;
  final bool deductFromSavings;
  final String? link;
  final bool isPurchased;
  final DateTime? purchasedAt;
  final DateTime createdAt;

  /// Progress 0.0–1.0 (null if no targetPrice)
  double? get progress =>
      (targetPrice != null && targetPrice! > 0) ? (amountSaved / targetPrice!).clamp(0.0, 1.0) : null;

  bool get isComplete => progress != null && progress! >= 1.0;

  WishlistItem copyWith({
    String? id,
    String? title,
    String? emoji,
    double? targetPrice,
    double? amountSaved,
    bool? deductFromSavings,
    String? link,
    bool? isPurchased,
    DateTime? purchasedAt,
    DateTime? createdAt,
  }) {
    return WishlistItem(
      id: id ?? this.id,
      title: title ?? this.title,
      emoji: emoji ?? this.emoji,
      targetPrice: targetPrice ?? this.targetPrice,
      amountSaved: amountSaved ?? this.amountSaved,
      deductFromSavings: deductFromSavings ?? this.deductFromSavings,
      link: link ?? this.link,
      isPurchased: isPurchased ?? this.isPurchased,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
