/// TransactionModel — DTO that knows how to parse JSON from the backend.
library;

import '../../domain/entities/transaction.dart';

class TransactionCategoryModel extends TransactionCategory {
  const TransactionCategoryModel({
    required super.id,
    required super.name,
    required super.emoji,
    required super.type,
    super.excludeFromAnalytics = false,
  });

  factory TransactionCategoryModel.fromJson(Map<String, dynamic> json) {
    return TransactionCategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      type: json['type'] as String,
      excludeFromAnalytics: json['excludeFromAnalytics'] as bool? ?? false,
    );
  }
}

class TransactionModel extends Transaction {
  const TransactionModel({
    required super.id,
    required super.title,
    required super.amount,
    required super.type,
    required super.date,
    required super.createdAt,
    required super.updatedAt,
    super.excludeFromAnalytics = false,
    super.note,
    super.categoryId,
    super.category,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    final catJson = json['category'];
    return TransactionModel(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: json['amount'] is String
          ? double.parse(json['amount'] as String)
          : (json['amount'] as num).toDouble(),
      type: json['type'] as String,
      note: json['note'] as String?,
      categoryId: json['categoryId'] as String?,
      excludeFromAnalytics: json['excludeFromAnalytics'] as bool? ?? false,
      category: catJson != null
          ? TransactionCategoryModel.fromJson(catJson as Map<String, dynamic>)
          : null,
      date: DateTime.parse(json['date'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class TransactionPageModel extends TransactionPage {
  /// Typed as [List<TransactionModel>] for covariant access to model-specific methods.
  @override
  final List<TransactionModel> items;

  const TransactionPageModel({
    required this.items,
    required int total,
    required int page,
    required int limit,
    required int pages,
    required bool hasNext,
    required bool hasPrev,
    super.incomeTotal = 0.0,
    super.expenseTotal = 0.0,
  }) : super(
          items: items,
          total: total,
          page: page,
          limit: limit,
          pages: pages,
          hasNext: hasNext,
          hasPrev: hasPrev,
        );

  factory TransactionPageModel.fromJson(Map<String, dynamic> json) {
    final pagination = json['pagination'] as Map<String, dynamic>;
    final totals = json['totals'] as Map<String, dynamic>? ?? {};
    return TransactionPageModel(
      items: (json['items'] as List<dynamic>)
          .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: pagination['total'] as int,
      page: pagination['page'] as int,
      limit: pagination['limit'] as int,
      pages: pagination['pages'] as int,
      hasNext: pagination['hasNext'] as bool,
      hasPrev: pagination['hasPrev'] as bool,
      incomeTotal: (totals['incomeTotal'] as num?)?.toDouble() ?? 0.0,
      expenseTotal: (totals['expenseTotal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
