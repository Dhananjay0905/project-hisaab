/// Summary entity — aggregated financial dashboard data.
library;

class TopCategory {
  const TopCategory({
    required this.categoryId,
    required this.name,
    required this.emoji,
    required this.type,
    required this.total,
    required this.percentage,
  });

  final String categoryId;
  final String name;
  final String emoji;
  final String type;
  final double total;
  final double percentage;
}

class RecentTransaction {
  const RecentTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
    this.categoryName,
    this.categoryEmoji,
  });

  final String id;
  final String title;
  final double amount;
  final String type;
  final DateTime date;
  final String? categoryName;
  final String? categoryEmoji;

  bool get isIncome => type == 'INCOME';
}

class MonthSummary {
  const MonthSummary({
    required this.income,
    required this.expenses,
    required this.transactionCount,
  });

  final double income;
  final double expenses;
  final int transactionCount;
}

class Summary {
  const Summary({
    required this.currentBalance,
    required this.openingBalance,
    required this.totalIncome,
    required this.totalExpenses,
    required this.thisMonth,
    required this.recentTransactions,
    required this.topCategories,
  });

  final double currentBalance;
  final double openingBalance;
  final double totalIncome;
  final double totalExpenses;
  final MonthSummary thisMonth;
  final List<RecentTransaction> recentTransactions;
  final List<TopCategory> topCategories;

  static const empty = Summary(
    currentBalance: 0,
    openingBalance: 0,
    totalIncome: 0,
    totalExpenses: 0,
    thisMonth: MonthSummary(income: 0, expenses: 0, transactionCount: 0),
    recentTransactions: [],
    topCategories: [],
  );
}
