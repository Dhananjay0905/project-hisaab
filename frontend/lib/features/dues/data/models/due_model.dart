/// DueModel — DTO that parses the backend JSON response.
library;

import '../../domain/entities/due.dart';

class DueModel extends Due {
  const DueModel({
    required super.id,
    required super.title,
    required super.personName,
    required super.amount,
    required super.type,
    required super.isPaid,
    required super.createdAt,
    super.note,
    super.dueDate,
    super.paidAt,
    super.categoryId,
    super.categoryName,
    super.categoryEmoji,
  });

  factory DueModel.fromJson(Map<String, dynamic> json) {
    final cat = json['category'] as Map<String, dynamic>?;
    return DueModel(
      id: json['id'] as String,
      title: json['title'] as String,
      personName: json['personName'] as String,
      amount: json['amount'] is String
          ? double.parse(json['amount'] as String)
          : (json['amount'] as num).toDouble(),
      type: json['type'] as String,
      note: json['note'] as String?,
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      isPaid: json['isPaid'] as bool,
      paidAt: json['paidAt'] != null
          ? DateTime.parse(json['paidAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      categoryId: json['categoryId'] as String?,
      categoryName: cat?['name'] as String?,
      categoryEmoji: cat?['emoji'] as String?,
    );
  }
}

class DuesSummaryModel {
  final double iOweTotal;
  final double theyOweTotal;
  final double effectiveBalance;

  const DuesSummaryModel({
    required this.iOweTotal,
    required this.theyOweTotal,
    required this.effectiveBalance,
  });

  factory DuesSummaryModel.fromJson(Map<String, dynamic> json) {
    return DuesSummaryModel(
      iOweTotal: (json['iOweTotal'] as num).toDouble(),
      theyOweTotal: (json['theyOweTotal'] as num).toDouble(),
      effectiveBalance: (json['effectiveBalance'] as num).toDouble(),
    );
  }
}
