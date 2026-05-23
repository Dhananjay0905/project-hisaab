/// UpiOcrService — runs ML Kit text recognition on a UPI payment screenshot
/// and extracts the transaction amount, date, time, and merchant name.
///
/// Supports screenshots from:
///   • Google Pay (GPay)  — both simple card and detailed receipt views
///   • PhonePe
///   • Paytm
///   • BHIM UPI
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'upi_transaction_data.dart';

class UpiOcrService {
  UpiOcrService._();
  static final UpiOcrService instance = UpiOcrService._();

  Future<UpiTransactionData> parseScreenshot(String filePath) async {
    final inputImage = InputImage.fromFile(File(filePath));
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText result = await recognizer.processImage(inputImage);
      final fullText = result.blocks.map((b) => b.text).join('\n');
      debugPrint('[UpiOcrService] OCR raw text:\n$fullText');

      final amount = _parseAmount(fullText);
      final date = _parseDate(fullText);
      final time = _parseTime(fullText);
      final isIncome = _detectIncome(fullText);

      // ── UPI receipt heuristic ──────────────────────────────────────────────
      // If the image has no UPI-related keywords AND no amount was parsed, it
      // is almost certainly not a payment screenshot (e.g. a random photo).
      // Flag it so the caller can show a snackbar instead of opening the modal.
      if (amount == null && !_looksLikeUpiReceipt(fullText)) {
        debugPrint('[UpiOcrService] Image does not appear to be a UPI receipt.');
        return const UpiTransactionData(isNotUpiReceipt: true);
      }

      return UpiTransactionData(
        amount: amount,
        date: date,
        time: time,
        merchantName: null, // never auto-filled
        isIncome: isIncome,
      );
    } finally {
      recognizer.close();
    }
  }

  // ─── UPI Receipt Keyword Check ─────────────────────────────────────────────

  /// Returns true if [text] contains at least one keyword strongly associated
  /// with a UPI/digital-payment receipt. A currency symbol (₹, Rs) alone is
  /// enough; otherwise we look for common payment verbs and app names.
  static bool _looksLikeUpiReceipt(String text) {
    final lower = text.toLowerCase();
    const keywords = [
      '₹', 'rs.', 'rs ',          // currency symbols / abbreviations
      'paid', 'sent', 'received',  // payment verbs
      'upi', 'utr', 'ref no',      // UPI identifiers
      'transaction', 'txn',        // generic transaction markers
      'gpay', 'google pay',        // GPay
      'phonepe', 'phone pe',       // PhonePe
      'paytm',                     // Paytm
      'bhim',                      // BHIM UPI
      'debited', 'credited',       // bank SMS style
      'transfer', 'payment',       // generic
      'bank',                      // catches bank transfer screens
      'inr',                       // INR abbreviation
    ];
    return keywords.any((kw) => lower.contains(kw));
  }

  // ─── Income Detection ──────────────────────────────────────────────────────

  static bool _detectIncome(String text) {
    final lower = text.toLowerCase();
    return lower.contains('money received') ||
        lower.contains('received from') ||
        lower.contains('you received') ||
        // GPay "From Dev Patel" at the very top of the card (the subtitle
        // directly under the avatar when someone pays you)
        RegExp(r'^From\s+[A-Z]', multiLine: true).hasMatch(text);
  }

  // ─── Amount Parsing ────────────────────────────────────────────────────────

  static double? _parseAmount(String text) {
    // Pattern order matters — most reliable first.
    // Strategy: for each pattern we take the FIRST valid match (left-to-right
    // in the text), not the largest. The "largest wins" strategy caused issues
    // where OCR noise (e.g. a misread checkmark circle → "7") produced a
    // spurious large number that beat the real amount.
    final patterns = [
      // ₹1,234.56 | ₹1234 | ₹ 1,234.56
      // ₹\n88.00 also matches because \s* includes newlines.
      RegExp(r'₹\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      // ML Kit sometimes misreads ₹ as ?, €, $, £
      RegExp(r'(?:[?€£$])\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      // ML Kit on some devices reads ₹ as a bare "R" (e.g. ₹88.00 → R88.00).
      // Negative lookbehind ensures we don't match R inside a word like MANOHAR.
      RegExp(r'(?<![A-Za-z])R(\d[\d,]*(?:\.\d{1,2})?)', caseSensitive: false),
      // Rs. 500 | Rs 500.00
      RegExp(r'Rs\.?\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      // INR 200
      RegExp(r'INR\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      // Standalone number with commas or explicit 2 decimals on its own line
      // e.g. "1,562.18" or "20.00" — only used when no currency prefix found.
      RegExp(r'^\s*([1-9]\d{0,2}(?:,\d{2,3})+(?:\.\d{1,2})?|\d+\.\d{2})\s*$',
          multiLine: true),
      // Plain integer alone on a line (GPay large font, ₹ is a separate block).
      // Only fires when no currency symbol was present anywhere in the text
      // (guarded below), and requires 2–7 digits to avoid ref numbers.
      RegExp(r'^\s*([1-9]\d{1,6})\s*$', multiLine: true),
    ];

    // If the text contains a currency symbol/keyword (including the "R" misread),
    // skip the plain-integer fallbacks (last 2 patterns) — the earlier patterns
    // should handle it, and the fallbacks risk matching OCR noise.
    final hasCurrencyContext = RegExp(
      r'[₹$€£]|Rs\.?|INR|(?<![A-Za-z])R\d',
      caseSensitive: false,
    ).hasMatch(text);
    final patternCount = hasCurrencyContext ? patterns.length - 2 : patterns.length;

    for (int i = 0; i < patternCount; i++) {
      final pattern = patterns[i];
      for (final m in pattern.allMatches(text)) {
        final raw = m.group(1)!.replaceAll(',', '');
        final value = double.tryParse(raw);
        if (value != null && value > 0) {
          return value; // first valid match wins
        }
      }
    }
    return null;
  }


  // ─── Date Parsing ──────────────────────────────────────────────────────────

  static DateTime? _parseDate(String text) {
    final monthNames = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4,
      'may': 5, 'jun': 6, 'jul': 7, 'aug': 8,
      'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };

    // "18 May 2025" | "18th May 2025" | "18 May, 2025" | "18 May 2025, 9:53 pm"
    final wordDate = RegExp(
      r'\b(\d{1,2})(?:st|nd|rd|th)?\s+'
      r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[,\s]+'
      r'(\d{4})\b',
      caseSensitive: false,
    );

    // "May 18, 2025"
    final usDate = RegExp(
      r'\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+'
      r'(\d{1,2}),?\s+(\d{4})\b',
      caseSensitive: false,
    );

    // "18/05/2025" | "18-05-2025"
    final numDate = RegExp(r'\b(\d{2})[/\-](\d{2})[/\-](\d{4})\b');

    // "2025-05-18" ISO
    final isoDate = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b');

    final wm = wordDate.firstMatch(text);
    if (wm != null) {
      final d = int.tryParse(wm.group(1)!);
      final m = monthNames[wm.group(2)!.toLowerCase().substring(0, 3)];
      final y = int.tryParse(wm.group(3)!);
      if (d != null && m != null && y != null) return _safeDate(y, m, d);
    }

    final um = usDate.firstMatch(text);
    if (um != null) {
      final m = monthNames[um.group(1)!.toLowerCase().substring(0, 3)];
      final d = int.tryParse(um.group(2)!);
      final y = int.tryParse(um.group(3)!);
      if (d != null && m != null && y != null) return _safeDate(y, m, d);
    }

    final nm = numDate.firstMatch(text);
    if (nm != null) {
      final d = int.tryParse(nm.group(1)!);
      final m = int.tryParse(nm.group(2)!);
      final y = int.tryParse(nm.group(3)!);
      if (d != null && m != null && y != null) return _safeDate(y, m, d);
    }

    final im = isoDate.firstMatch(text);
    if (im != null) {
      final y = int.tryParse(im.group(1)!);
      final m = int.tryParse(im.group(2)!);
      final d = int.tryParse(im.group(3)!);
      if (d != null && m != null && y != null) return _safeDate(y, m, d);
    }

    return null;
  }

  static DateTime? _safeDate(int year, int month, int day) {
    try {
      if (month < 1 || month > 12 || day < 1 || day > 31) return null;
      final d = DateTime(year, month, day);
      if (d.isAfter(DateTime.now().add(const Duration(days: 2)))) return null;
      return d;
    } catch (_) {
      return null;
    }
  }

  // ─── Time Parsing ──────────────────────────────────────────────────────────

  static TimeOfDay? _parseTime(String text) {
    final ampm = RegExp(
      r'\b(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)\b',
      caseSensitive: false,
    );
    final h24 = RegExp(r'\b([01]?\d|2[0-3]):([0-5]\d)(?::\d{2})?\b');

    final am = ampm.firstMatch(text);
    if (am != null) {
      var hour = int.parse(am.group(1)!);
      final minute = int.parse(am.group(2)!);
      final isPm = am.group(3)!.toUpperCase() == 'PM';
      if (hour == 12) {
        hour = isPm ? 12 : 0;
      } else if (isPm) {
        hour += 12;
      }
      if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }

    final hm = h24.firstMatch(text);
    if (hm != null) {
      final hour = int.parse(hm.group(1)!);
      final minute = int.parse(hm.group(2)!);
      if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }

    return null;
  }
}
