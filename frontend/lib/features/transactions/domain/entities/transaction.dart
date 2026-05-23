/// Transaction entity — pure domain class, no JSON logic.
library;




class TransactionCategory {
  const TransactionCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.type,
    this.excludeFromAnalytics = false,
  });

  final String id;
  final String name;
  final String emoji;
  final String type;
  final bool excludeFromAnalytics;

  bool get isIncome => type == 'INCOME';
}

class Transaction {
  const Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.excludeFromAnalytics = false,
    this.note,
    this.categoryId,
    this.category,
  });

  final String id;
  final String title;
  final double amount;

  /// 'INCOME' or 'EXPENSE'
  final String type;

  /// True when this specific transaction is excluded from analytics.
  final bool excludeFromAnalytics;

  final String? note;
  final String? categoryId;
  final TransactionCategory? category;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isIncome => type == 'INCOME';
  bool get isExpense => type == 'EXPENSE';

  /// Excluded if either this transaction or its category is marked excluded.
  bool get isExcludedFromAnalytics =>
      excludeFromAnalytics || (category?.excludeFromAnalytics ?? false);

  @override
  String toString() => 'Transaction($title [$type] ₹$amount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Transaction && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Wraps a paginated list of transactions.
class TransactionPage {
  const TransactionPage({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.pages,
    required this.hasNext,
    required this.hasPrev,
    this.incomeTotal = 0.0,
    this.expenseTotal = 0.0,
  });

  final List<Transaction> items;
  final int total;
  final int page;
  final int limit;
  final int pages;
  final bool hasNext;
  final bool hasPrev;

  /// Sum of all INCOME transactions matching the current filter (server-side aggregate).
  final double incomeTotal;

  /// Sum of all EXPENSE transactions matching the current filter (server-side aggregate).
  final double expenseTotal;

  double get net => incomeTotal - expenseTotal;

  static const empty = TransactionPage(
    items: [],
    total: 0,
    page: 1,
    limit: 20,
    pages: 0,
    hasNext: false,
    hasPrev: false,
  );
}
