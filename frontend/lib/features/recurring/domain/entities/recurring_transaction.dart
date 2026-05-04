/// RecurringTransaction — pure domain entity.
library;

class RecurringTransaction {
  const RecurringTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.frequency,
    required this.startDate,
    required this.nextDueDate,
    required this.isActive,
    required this.createdAt,
    this.category,
  });

  final String id;
  final String title;
  final double amount;

  /// 'INCOME' or 'EXPENSE'
  final String type;

  /// 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'YEARLY'
  final String frequency;

  final DateTime startDate;
  final DateTime nextDueDate;
  final bool isActive;
  final DateTime createdAt;
  final RecurringCategory? category;

  bool get isIncome => type == 'INCOME';
  bool get isExpense => type == 'EXPENSE';
  bool get isDueToday {
    final now = DateTime.now();
    return nextDueDate.isBefore(DateTime(now.year, now.month, now.day + 1));
  }

  String get frequencyLabel {
    switch (frequency) {
      case 'DAILY':
        return 'Daily';
      case 'WEEKLY':
        return 'Weekly';
      case 'MONTHLY':
        return 'Monthly';
      case 'YEARLY':
        return 'Yearly';
      default:
        return frequency;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is RecurringTransaction && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

class RecurringCategory {
  const RecurringCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.type,
  });

  final String id;
  final String name;
  final String emoji;
  final String type;
}
