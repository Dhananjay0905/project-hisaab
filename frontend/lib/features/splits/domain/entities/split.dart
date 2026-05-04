/// Domain entities for Splits feature.
/// Named SplitGroup (not Split) to avoid conflict with Flutter's Split curve.
library;

class SplitParticipant {
  const SplitParticipant({
    required this.id,
    required this.splitId,
    required this.name,
    required this.amount,
    required this.hasPaid,
    this.paidAt,
    this.transactionId,
    required this.createdAt,
  });

  final String id;
  final String splitId;
  final String name;
  final double amount;
  final bool hasPaid;
  final DateTime? paidAt;
  final String? transactionId;
  final DateTime createdAt;
}

class SplitGroup {
  const SplitGroup({
    required this.id,
    required this.userId,
    required this.title,
    required this.totalAmount,
    required this.participants,
    this.note,
    required this.date,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final double totalAmount;
  final List<SplitParticipant> participants;
  final String? note;
  final DateTime date;
  final DateTime createdAt;

  /// Number of participants who have paid.
  int get paidCount => participants.where((p) => p.hasPaid).length;

  /// Total number of participants (excluding you).
  int get totalCount => participants.length;

  /// Amount still outstanding (sum of unpaid participants).
  double get outstandingAmount =>
      participants.where((p) => !p.hasPaid).fold(0.0, (s, p) => s + p.amount);

  /// Amount already collected.
  double get collectedAmount =>
      participants.where((p) => p.hasPaid).fold(0.0, (s, p) => s + p.amount);

  /// True when all participants have paid.
  bool get isFullyPaid => paidCount == totalCount;

  /// Per-person share (same for all since we do equal splits).
  double get perPersonAmount =>
      participants.isNotEmpty ? participants.first.amount : 0.0;
}
