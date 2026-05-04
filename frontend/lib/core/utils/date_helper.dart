/// Date formatting and grouping utilities.
library;

import 'package:flutter/material.dart' show DateUtils;
import 'package:intl/intl.dart';

abstract final class DateHelper {
  // ─── Formatters ───────────────────────────────────────────────────────────
  static final _dayFull = DateFormat('EEEE, d MMM'); // Monday, 14 Apr
  static final _dayShort = DateFormat('d MMM');       // 14 Apr
  static final _monthYear = DateFormat('MMMM yyyy');  // April 2024
  static final _monthKey = DateFormat('yyyy-MM');     // 2024-04
  static final _dateKey = DateFormat('yyyy-MM-dd');   // 2024-04-14
  static final _time = DateFormat('h:mm a');          // 3:45 PM
  static final _dateLong = DateFormat('d MMM yyyy');  // 14 Apr 2024
  static final _inputFormat = DateFormat('dd/MM/yyyy'); // 14/04/2024

  static String formatDayFull(DateTime dt) => _dayFull.format(dt);
  static String formatDayShort(DateTime dt) => _dayShort.format(dt);
  static String formatMonthYear(DateTime dt) => _monthYear.format(dt);
  static String formatMonthKey(DateTime dt) => _monthKey.format(dt);
  static String formatDateKey(DateTime dt) => _dateKey.format(dt);
  static String formatTime(DateTime dt) => _time.format(dt);
  static String formatDateLong(DateTime dt) => _dateLong.format(dt);
  static String formatInput(DateTime dt) => _inputFormat.format(dt);

  // ─── Group label for transaction lists ───────────────────────────────────
  /// Returns a human-friendly group label:
  ///   "Today" | "Yesterday" | "Mon, 14 Apr" | for past months → "April 2024"
  static String groupLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(date).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (dt.month == now.month && dt.year == now.year) {
      return DateFormat('EEE, d MMM').format(dt); // e.g. Mon, 14 Apr
    }
    // Different month — show month label for the "all time" grouped view
    return formatMonthYear(dt);
  }

  /// Month label for the "grouped by month" all-time view.
  static String monthLabel(DateTime dt) => formatMonthYear(dt);

  // ─── Period helpers ────────────────────────────────────────────────────────

  static DateTime beginningOfWeek(DateTime dt) {
    final day = dt.weekday; // 1 = Mon, 7 = Sun
    return DateTime(dt.year, dt.month, dt.day - (day - 1));
  }

  static DateTime beginningOfMonth(DateTime dt) =>
      DateTime(dt.year, dt.month, 1);

  static DateTime endOfMonth(DateTime dt) =>
      DateTime(dt.year, dt.month + 1, 0, 23, 59, 59);

  static DateTime endOfDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day, 23, 59, 59);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  static bool isToday(DateTime dt) => isSameDay(dt, DateTime.now());

  /// Returns a list of DateTime for each day in the given month.
  static List<DateTime> daysInMonth(int year, int month) {
    final days = <DateTime>[];
    final daysCount = DateUtils.getDaysInMonth(year, month);
    for (var d = 1; d <= daysCount; d++) {
      days.add(DateTime(year, month, d));
    }
    return days;
  }

  /// Relative time label for dues: "Due in 2 days", "Overdue 3d", "Due today"
  static String dueLabel(DateTime dueDate) {
    final now = DateTime.now();
    final date = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = date.difference(today).inDays;

    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    if (diff > 1) return 'Due in $diff days';
    return 'Overdue ${(-diff)}d';
  }
}
