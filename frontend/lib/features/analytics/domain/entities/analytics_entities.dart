/// Domain entities for analytics data.
library;

/// One month's income vs expense totals.
class MonthlySummary {
  const MonthlySummary({
    required this.month,
    required this.income,
    required this.expense,
  });

  /// Short label, e.g. "Jan 25"
  final String month;
  final double income;
  final double expense;

  double get savings => income - expense;
}

/// Current-month spending for one expense category.
class CategorySpend {
  const CategorySpend({
    required this.categoryId,
    required this.name,
    required this.emoji,
    required this.spent,
    this.limit,
  });

  final String? categoryId;
  final String name;
  final String emoji;
  final double spent;

  /// null means no limit was configured.
  final double? limit;

  bool get hasLimit => limit != null && limit! > 0;

  /// 0.0–1.0 progress; capped at 1.0 for UI.
  double get progress => hasLimit ? (spent / limit!).clamp(0.0, 1.0) : 0.0;

  bool get isAtLimit => hasLimit && spent >= limit!;
  bool get willExceed => hasLimit && spent > limit!;
}
