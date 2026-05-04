/// SummaryModel — parses the /api/summary response.
library;

import '../../domain/entities/summary.dart';

class SummaryModel extends Summary {
  const SummaryModel({
    required super.currentBalance,
    required super.openingBalance,
    required super.totalIncome,
    required super.totalExpenses,
    required super.thisMonth,
    required super.recentTransactions,
    required super.topCategories,
  });

  factory SummaryModel.fromJson(Map<String, dynamic> json) {
    final month = json['thisMonth'] as Map<String, dynamic>;
    final recentJson = json['recentTransactions'] as List<dynamic>? ?? [];
    final topJson = json['topCategories'] as List<dynamic>? ?? [];

    return SummaryModel(
      currentBalance: (json['currentBalance'] as num).toDouble(),
      openingBalance: (json['openingBalance'] as num).toDouble(),
      totalIncome: (json['totalIncome'] as num).toDouble(),
      totalExpenses: (json['totalExpenses'] as num).toDouble(),
      thisMonth: MonthSummary(
        income: (month['income'] as num).toDouble(),
        expenses: (month['expenses'] as num).toDouble(),
        transactionCount: month['transactionCount'] as int,
      ),
      recentTransactions: recentJson.map((e) {
        final m = e as Map<String, dynamic>;
        final cat = m['category'] as Map<String, dynamic>?;
        return RecentTransaction(
          id: m['id'] as String,
          title: m['title'] as String,
          amount: (m['amount'] as num).toDouble(),
          type: m['type'] as String,
          date: DateTime.parse(m['date'] as String),
          categoryName: cat?['name'] as String?,
          categoryEmoji: cat?['emoji'] as String?,
        );
      }).toList(),
      topCategories: topJson.map((e) {
        final m = e as Map<String, dynamic>;
        return TopCategory(
          categoryId: m['categoryId'] as String,
          name: m['name'] as String,
          emoji: m['emoji'] as String,
          type: m['type'] as String,
          total: (m['total'] as num).toDouble(),
          percentage: (m['percentage'] as num).toDouble(),
        );
      }).toList(),
    );
  }
}
