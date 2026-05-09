/// Category entity — pure domain class, no JSON logic.
library;

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.emoji,
    required this.type,
    required this.isDefault,
    required this.excludeFromAnalytics,
    required this.createdAt,
    this.monthlyLimit,
  });

  final String id;
  final String name;
  final String emoji;

  /// 'INCOME' or 'EXPENSE'
  final String type;

  final bool isDefault;

  /// When true, all transactions in this category are excluded from analytics.
  final bool excludeFromAnalytics;

  final DateTime createdAt;

  /// Optional monthly spending cap (EXPENSE categories only, in ₹).
  final double? monthlyLimit;

  bool get isIncome => type == 'INCOME';
  bool get isExpense => type == 'EXPENSE';

  /// True when this EXPENSE category has a limit configured.
  bool get hasLimit => monthlyLimit != null && monthlyLimit! > 0;

  @override
  String toString() => 'Category($emoji $name [$type])';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Category && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
