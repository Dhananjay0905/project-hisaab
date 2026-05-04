/// Savings entity — a single manually-managed pot per user.
library;

class Savings {
  const Savings({
    required this.id,
    required this.rawTotal,
    required this.cashDeduction,
    required this.wishlistDeduction,
    required this.effectiveTotal,
    required this.deductFromBalance,
    required this.updatedAt,
  });

  final String id;
  final double rawTotal;
  final double cashDeduction;
  final double wishlistDeduction;
  final double effectiveTotal;

  /// Whether to subtract rawTotal from the home page balance display.
  /// Cash-in-hand is NOT included in this deduction.
  final bool deductFromBalance;

  final DateTime updatedAt;

  static final empty = Savings(
    id: '',
    rawTotal: 0,
    cashDeduction: 0,
    wishlistDeduction: 0,
    effectiveTotal: 0,
    deductFromBalance: false,
    updatedAt: DateTime.now(),
  );
}
