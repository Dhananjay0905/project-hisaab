/// [User] entity — pure domain object, no JSON, no framework dependencies.
library;

import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String name;
  final bool isVerified;
  final String currency;       // e.g. "USD"
  final String currencySymbol; // e.g. "$"
  final double openingBalance;
  final double? monthlyBudget;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.isVerified,
    required this.currency,
    required this.currencySymbol,
    required this.openingBalance,
    this.monthlyBudget,
    required this.createdAt,
  });

  User copyWith({
    String? id,
    String? email,
    String? name,
    bool? isVerified,
    String? currency,
    String? currencySymbol,
    double? openingBalance,
    double? monthlyBudget,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      isVerified: isVerified ?? this.isVerified,
      currency: currency ?? this.currency,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      openingBalance: openingBalance ?? this.openingBalance,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        name,
        isVerified,
        currency,
        currencySymbol,
        openingBalance,
        monthlyBudget,
        createdAt,
      ];
}
