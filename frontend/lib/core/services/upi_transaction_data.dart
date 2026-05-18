/// Data extracted from a UPI payment screenshot via OCR.
library;

import 'package:flutter/material.dart';

class UpiTransactionData {
  const UpiTransactionData({
    this.amount,
    this.date,
    this.time,
    this.merchantName,
    this.isIncome = false,
  });

  /// The transaction amount in INR (e.g. 750.00).
  final double? amount;

  /// The date of the transaction (time portion should be ignored; use [time]).
  final DateTime? date;

  /// The time of the transaction (optional, null if not found in screenshot).
  final TimeOfDay? time;

  /// The recipient/merchant name parsed from the screenshot (e.g. "Swiggy").
  final String? merchantName;

  /// Whether this was a received payment (income).
  final bool isIncome;

  bool get hasAnyData =>
      amount != null || date != null || time != null || merchantName != null;

  @override
  String toString() =>
      'UpiTransactionData(amount: $amount, date: $date, time: $time, merchant: $merchantName, isIncome: $isIncome)';
}
