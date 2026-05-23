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
    this.isNotUpiReceipt = false,
  });

  /// The transaction amount in INR (e.g. 750.00).
  final double? amount;

  /// The date of the transaction (time portion should be ignored; use [time]).
  final DateTime? date;

  /// The time of the transaction (optional, null if not found in screenshot).\
  final TimeOfDay? time;

  /// The recipient/merchant name parsed from the screenshot (e.g. "Swiggy").
  final String? merchantName;

  /// Whether this was a received payment (income).
  final bool isIncome;

  /// True when the shared image does not appear to be a UPI payment receipt
  /// (e.g. a random photo or scenery). When true, the app should NOT open the
  /// Add Transaction modal — it should show a friendly snackbar instead.
  final bool isNotUpiReceipt;

  /// At least one field was parsed — used as a coarse "we got something" check.
  bool get hasAnyData =>
      amount != null || date != null || time != null || merchantName != null;

  /// An amount was parsed. Without an amount the form would be nearly empty
  /// and confusing — callers should show a "partial data" warning in this case.
  /// Date/time alone (no amount) is considered partial.
  bool get hasMinimumData => amount != null;

  @override
  String toString() =>
      'UpiTransactionData(amount: $amount, date: $date, time: $time, '
      'merchant: $merchantName, isIncome: $isIncome, '
      'isNotUpiReceipt: $isNotUpiReceipt)';
}
