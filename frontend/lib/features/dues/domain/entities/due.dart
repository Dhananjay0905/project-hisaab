/// Due domain entity.
///
/// [type] is either 'I_OWE' (you owe someone) or 'THEY_OWE' (someone owes you).
library;

class Due {
  const Due({
    required this.id,
    required this.title,
    required this.personName,
    required this.amount,
    required this.type,
    required this.isPaid,
    required this.createdAt,
    this.note,
    this.dueDate,
    this.paidAt,
    this.categoryId,
    this.categoryName,
    this.categoryEmoji,
  });

  final String id;
  final String title;
  final String personName;
  final double amount;
  final String type;      // 'I_OWE' | 'THEY_OWE'
  final String? note;
  final DateTime? dueDate;
  final bool isPaid;
  final DateTime? paidAt;
  final DateTime createdAt;
  final String? categoryId;
  final String? categoryName;
  final String? categoryEmoji;

  bool get isIOwe => type == 'I_OWE';
  bool get isTheyOwe => type == 'THEY_OWE';

  /// True when dueDate is set and overdue (pending only).
  bool get isOverdue {
    if (isPaid || dueDate == null) return false;
    return dueDate!.isBefore(DateTime.now());
  }
}
