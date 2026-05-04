/// SavingsModel — JSON ↔ Savings entity mapping.
library;

import '../../domain/entities/savings.dart';

class SavingsModel extends Savings {
  const SavingsModel({
    required super.id,
    required super.rawTotal,
    required super.cashDeduction,
    required super.wishlistDeduction,
    required super.effectiveTotal,
    required super.deductFromBalance,
    required super.updatedAt,
  });

  factory SavingsModel.fromJson(Map<String, dynamic> json) {
    return SavingsModel(
      id: json['id'] as String? ?? '',
      rawTotal: (json['rawTotal'] as num).toDouble(),
      cashDeduction: (json['cashDeduction'] as num).toDouble(),
      wishlistDeduction: (json['wishlistDeduction'] as num).toDouble(),
      effectiveTotal: (json['effectiveTotal'] as num).toDouble(),
      deductFromBalance: json['deductFromBalance'] as bool? ?? false,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
