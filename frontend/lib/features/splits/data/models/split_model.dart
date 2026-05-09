/// Data Transfer Object for SplitGroup API responses.
library;

import '../../domain/entities/split.dart';

class SplitParticipantModel extends SplitParticipant {
  const SplitParticipantModel({
    required super.id,
    required super.splitId,
    required super.name,
    required super.amount,
    required super.hasPaid,
    super.paidAt,
    super.transactionId,
    required super.createdAt,
  });

  factory SplitParticipantModel.fromJson(Map<String, dynamic> json, String splitId) {
    return SplitParticipantModel(
      id: json['id'] as String,
      splitId: splitId,
      name: json['name'] as String,
      amount: json['amount'] is String
          ? double.parse(json['amount'] as String)
          : (json['amount'] as num).toDouble(),
      hasPaid: json['hasPaid'] as bool,
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt'] as String) : null,
      transactionId: json['transactionId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'splitId': splitId,
        'name': name,
        'amount': amount,
        'hasPaid': hasPaid,
        'paidAt': paidAt?.toIso8601String(),
        'transactionId': transactionId,
        'createdAt': createdAt.toIso8601String(),
      };
}

class SplitGroupModel extends SplitGroup {
  const SplitGroupModel({
    required super.id,
    required super.userId,
    required super.title,
    required super.totalAmount,
    required super.participants,
    super.note,
    required super.date,
    required super.createdAt,
  });

  factory SplitGroupModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final rawParticipants = json['participants'] as List<dynamic>? ?? [];
    final participants = rawParticipants
        .map((p) => SplitParticipantModel.fromJson(p as Map<String, dynamic>, id))
        .toList();

    return SplitGroupModel(
      id: id,
      userId: json['userId'] as String,
      title: json['title'] as String,
      totalAmount: (json['totalAmount'] as num).toDouble(),
      participants: participants,
      note: json['note'] as String?,
      date: DateTime.parse(json['date'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Copy with updated participants (e.g. after marking one as paid).
  SplitGroupModel copyWithParticipant(SplitParticipantModel updated) {
    final newParticipants = participants
        .map((p) => p.id == updated.id ? updated : p)
        .toList();
    return SplitGroupModel(
      id: id,
      userId: userId,
      title: title,
      totalAmount: totalAmount,
      participants: newParticipants,
      note: note,
      date: date,
      createdAt: createdAt,
    );
  }
}
