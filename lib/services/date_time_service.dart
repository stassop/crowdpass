import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

/// A utility class that holds methods for working with dates and times
class DateTimeService {
  /// Returns a human-readable string representing how long ago the [dateTime] occurred.
  /// If [short] is true, uses abbreviated units (e.g. `3m`, `5h`).
  static String getTimeSince(DateTime dateTime, {bool short = false}) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return short ? '${minutes}m' : '$minutes minute${minutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return short ? '${hours}h' : '$hours hour${hours == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return short ? '${days}d' : '$days day${days == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 365) {
      final weeks = difference.inDays ~/ 7;
      return short ? '${weeks}w' : '$weeks week${weeks == 1 ? '' : 's'} ago';
    } else {
      final years = difference.inDays ~/ 365;
      return short ? '${years}y' : '$years year${years == 1 ? '' : 's'} ago';
    }
  }

  static String formatDateTimeRange(
    DateTimeRange dateRange, {
    Locale? locale,
  }) {
    final String localeString = locale?.toString() ?? Intl.getCurrentLocale();

    final DateTime startDateTime = dateRange.start;
    final DateTime endDateTime = dateRange.end;

    if (startDateTime.isAfter(endDateTime)) {
      throw ArgumentError('Start date must not be after end date');
    }

    // Normalize to date-only comparison (removes time component)
    final DateTime startDate = DateTime(
      startDateTime.year,
      startDateTime.month,
      startDateTime.day,
    );

    final DateTime endDate = DateTime(
      endDateTime.year,
      endDateTime.month,
      endDateTime.day,
    );

    // 1. Same Day → "May 20, 2026"
    if (startDate == endDate) {
      return DateFormat.yMMMd(localeString).format(startDate);
    }

    // 2. Same Year
    if (startDate.year == endDate.year) {
      final String formattedYear =
          DateFormat.y(localeString).format(startDate);

      // Same Month → "May 20–25, 2026"
      if (startDate.month == endDate.month) {
        final String formattedMonth =
            DateFormat.MMM(localeString).format(startDate);

        return '$formattedMonth '
            '${startDate.day}-${endDate.day}, '
            '$formattedYear';
      }

      // Different Month → "May 25 – Jun 3, 2026"
      final String formattedStartMonthDay =
          DateFormat.MMMd(localeString).format(startDate);

      final String formattedEndMonthDay =
          DateFormat.MMMd(localeString).format(endDate);

      return '$formattedStartMonthDay - '
          '$formattedEndMonthDay, '
          '$formattedYear';
    }

    // 3. Different Year → "Dec 30, 2025 – Jan 5, 2026"
    final String formattedFullStart =
        DateFormat.yMMMd(localeString).format(startDate);

    final String formattedFullEnd =
        DateFormat.yMMMd(localeString).format(endDate);

    return '$formattedFullStart - $formattedFullEnd';
  }

  static bool isDateTimeRangeWithinBounds(
    DateTimeRange bounds,
    DateTime start,
    DateTime end,
  ) {
    return (start.isAtSameMomentAs(bounds.start) || start.isAfter(bounds.start)) &&
        (end.isAtSameMomentAs(bounds.end) || end.isBefore(bounds.end));
  }
}
