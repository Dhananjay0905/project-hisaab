/// UserModel — DTO that maps JSON ↔ User entity.
library;

import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    required super.name,
    required super.isVerified,
    required super.currency,
    required super.currencySymbol,
    required super.openingBalance,
    super.monthlyBudget,
    required super.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      isVerified: json['isVerified'] as bool? ?? false,
      currency: json['currency'] as String? ?? 'USD',
      currencySymbol: json['currencySymbol'] as String? ?? '\$',
      openingBalance: _parseDouble(json['openingBalance']),
      monthlyBudget: json['monthlyBudget'] != null
          ? _parseDouble(json['monthlyBudget'])
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'isVerified': isVerified,
        'currency': currency,
        'currencySymbol': currencySymbol,
        'openingBalance': openingBalance,
        'monthlyBudget': monthlyBudget,
        'createdAt': createdAt.toIso8601String(),
      };

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}
