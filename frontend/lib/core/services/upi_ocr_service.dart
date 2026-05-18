/// UpiOcrService — runs ML Kit text recognition on a UPI payment screenshot
/// and extracts the transaction amount, date, time, and merchant name.
///
/// Supports screenshots from:
///   • Google Pay (GPay)
///   • PhonePe
///   • Paytm
///   • BHIM UPI
///   • Most other Indian UPI apps (common formatting patterns)
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'upi_transaction_data.dart';

class UpiOcrService {
  UpiOcrService._();
  static final UpiOcrService instance = UpiOcrService._();

  /// Processes an image file and returns the parsed UPI transaction data.
  /// Returns a [UpiTransactionData] with all fields null if nothing could be parsed.
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
      final isIncome = fullText.toLowerCase().contains('money received') || 
                       fullText.toLowerCase().contains('received from');
      final merchant = _parseMerchant(fullText, isIncome);

      return UpiTransactionData(
        amount: amount,
        date: date,
        time: time,
        merchantName: merchant,
        isIncome: isIncome,
      );
    } finally {
      recognizer.close();
    }
  }

  // ─── Amount Parsing ────────────────────────────────────────────────────────

  static double? _parseAmount(String text) {
    // Patterns:
    //   ₹1,234.56 | ₹1234 | ₹ 1,234.56
    //   Rs. 500 | Rs 500.00 | INR 200
    //   Paid ₹750 | Sent ₹500 | Paid Rs.200
    //   "Amount\n₹500" (multi-line, label then value)
    final patterns = [
      // ₹ with optional space, optional commas, optional decimals
      RegExp(r'₹\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      // Often ML Kit drops the ₹ or reads it as ?, €, $, or £.
      RegExp(r'(?:[?€£$])\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      // Rs. / Rs with optional dot
      RegExp(r'Rs\.?\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      // INR prefix
      RegExp(r'INR\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      // Standalone number on a line that has a decimal or comma (looks like money)
      RegExp(r'^\s*([1-9]\d{0,2}(?:,\d{2,3})+(?:\.\d{1,2})?|\d+(?:\.\d{2}))\s*$', multiLine: true),
    ];

    for (final pattern in patterns) {
      final matches = pattern.allMatches(text);
      // Take the largest amount found (to avoid matching small fee amounts)
      double? best;
      for (final m in matches) {
        final raw = m.group(1)!.replaceAll(',', '');
        final value = double.tryParse(raw);
        if (value != null && value > 0) {
          if (best == null || value > best) best = value;
        }
      }
      if (best != null) return best;
    }
    return null;
  }

  // ─── Date Parsing ──────────────────────────────────────────────────────────

  static DateTime? _parseDate(String text) {
    // GPay:    "18 May 2025"  |  "May 18, 2025"
    // PhonePe: "18/05/2025"   |  "18-05-2025"
    // Paytm:   "18 May, 2025" |  "18th May 2025"

    final monthNames = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4,
      'may': 5, 'jun': 6, 'jul': 7, 'aug': 8,
      'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };

    // Pattern 1: "18 May 2025" or "18th May 2025" or "18 May, 2025"
    final wordDateRegex = RegExp(
      r'\b(\d{1,2})(?:st|nd|rd|th)?\s+'
      r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[,\s]+'
      r'(\d{4})\b',
      caseSensitive: false,
    );

    // Pattern 2: "May 18, 2025"
    final usDateRegex = RegExp(
      r'\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+'
      r'(\d{1,2}),?\s+(\d{4})\b',
      caseSensitive: false,
    );

    // Pattern 3: "18/05/2025" or "18-05-2025"
    final numericDateRegex = RegExp(
      r'\b(\d{2})[/\-](\d{2})[/\-](\d{4})\b',
    );

    // Pattern 4: "2025-05-18" (ISO)
    final isoDateRegex = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b');

    // Try word-based formats first (more reliable)
    final wordMatch = wordDateRegex.firstMatch(text);
    if (wordMatch != null) {
      final day = int.tryParse(wordMatch.group(1)!);
      final month = monthNames[wordMatch.group(2)!.toLowerCase().substring(0, 3)];
      final year = int.tryParse(wordMatch.group(3)!);
      if (day != null && month != null && year != null) {
        return _safeDate(year, month, day);
      }
    }

    final usMatch = usDateRegex.firstMatch(text);
    if (usMatch != null) {
      final month = monthNames[usMatch.group(1)!.toLowerCase().substring(0, 3)];
      final day = int.tryParse(usMatch.group(2)!);
      final year = int.tryParse(usMatch.group(3)!);
      if (day != null && month != null && year != null) {
        return _safeDate(year, month, day);
      }
    }

    final numMatch = numericDateRegex.firstMatch(text);
    if (numMatch != null) {
      final day = int.tryParse(numMatch.group(1)!);
      final month = int.tryParse(numMatch.group(2)!);
      final year = int.tryParse(numMatch.group(3)!);
      if (day != null && month != null && year != null) {
        return _safeDate(year, month, day);
      }
    }

    final isoMatch = isoDateRegex.firstMatch(text);
    if (isoMatch != null) {
      final year = int.tryParse(isoMatch.group(1)!);
      final month = int.tryParse(isoMatch.group(2)!);
      final day = int.tryParse(isoMatch.group(3)!);
      if (day != null && month != null && year != null) {
        return _safeDate(year, month, day);
      }
    }

    return null;
  }

  static DateTime? _safeDate(int year, int month, int day) {
    try {
      if (month < 1 || month > 12 || day < 1 || day > 31) return null;
      final d = DateTime(year, month, day);
      // Reject dates in the distant future (likely a misparse)
      if (d.isAfter(DateTime.now().add(const Duration(days: 2)))) return null;
      return d;
    } catch (_) {
      return null;
    }
  }

  // ─── Time Parsing ──────────────────────────────────────────────────────────

  static TimeOfDay? _parseTime(String text) {
    // "3:45 PM" | "03:45 PM" | "3:45PM" | "15:45" | "15:45:30"
    final ampmRegex = RegExp(
      r'\b(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)\b',
      caseSensitive: false,
    );
    final h24Regex = RegExp(r'\b([01]?\d|2[0-3]):([0-5]\d)(?::\d{2})?\b');

    final ampmMatch = ampmRegex.firstMatch(text);
    if (ampmMatch != null) {
      var hour = int.parse(ampmMatch.group(1)!);
      final minute = int.parse(ampmMatch.group(2)!);
      final isPm = ampmMatch.group(3)!.toUpperCase() == 'PM';
      if (hour == 12) { hour = isPm ? 12 : 0; }
      else if (isPm) { hour += 12; }
      if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }

    final h24Match = h24Regex.firstMatch(text);
    if (h24Match != null) {
      final hour = int.parse(h24Match.group(1)!);
      final minute = int.parse(h24Match.group(2)!);
      if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }

    return null;
  }

  // ─── Merchant Parsing ──────────────────────────────────────────────────────

  static String? _parseMerchant(String text, bool isIncome) {
    // GPay:    "Paid to Swiggy"  | "You paid Swiggy" | "To MANOHAR..."
    // PhonePe: "Sent to Amazon"  | "Transferred to John Doe"
    // Paytm:   "Payment to XYZ"  | "Paid to Paytm Mall" | "From: XYZ" (if received)
    // UPI ref: "To XYZ@upi"

    final patterns = [
      if (isIncome) RegExp(r"(?:Received from|From:)\s+([A-Za-z][A-Za-z0-9 &'\-]{1,40})", caseSensitive: false),
      RegExp(r"(?:Paid to|Sent to|Transferred to|Payment to|You paid|Paying)\s+([A-Za-z][A-Za-z0-9 &'\-]{1,40})", caseSensitive: false),
      RegExp(r"To:\s+([A-Za-z][A-Za-z0-9 &'\-]{1,40})", caseSensitive: false),
      RegExp(r"To\s+([A-Za-z][A-Za-z0-9 &'\-]{1,40})@", caseSensitive: false),
      RegExp(r"^To\s+([A-Za-z][A-Za-z0-9 &'\-]{1,40})$", caseSensitive: false, multiLine: true),
    ];


    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final name = match.group(1)!.trim();
        // Filter out generic words that aren't merchant names
        final excluded = {'upi', 'bank', 'payment', 'account', 'wallet'};
        if (!excluded.contains(name.toLowerCase())) {
          // Capitalize words
          return name.split(' ').map((w) {
            if (w.isEmpty) return w;
            return w[0].toUpperCase() + w.substring(1).toLowerCase();
          }).join(' ');
        }
      }
    }

    return null;
  }
}
