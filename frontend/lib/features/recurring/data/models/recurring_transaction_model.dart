/// RecurringTransactionModel — JSON ↔ entity mapping.
library;

import '../../domain/entities/recurring_transaction.dart';

class RecurringTransactionModel extends RecurringTransaction {
  const RecurringTransactionModel({
    required super.id,
    required super.title,
    required super.amount,
    required super.type,
    required super.frequency,
    required super.startDate,
    required super.nextDueDate,
    required super.isActive,
    required super.createdAt,
    super.category,
  });

  factory RecurringTransactionModel.fromJson(Map<String, dynamic> json) {
    RecurringCategory? cat;
    if (json['category'] is Map<String, dynamic>) {
      final c = json['category'] as Map<String, dynamic>;
      cat = RecurringCategory(
        id: c['id'] as String,
        name: c['name'] as String,
        emoji: c['emoji'] as String,
        type: c['type'] as String,
      );
    }

    return RecurringTransactionModel(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: json['type'] as String,
      frequency: json['frequency'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      nextDueDate: DateTime.parse(json['nextDueDate'] as String),
      isActive: json['isActive'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      category: cat,
    );
  }
}
