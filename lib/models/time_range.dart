import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TimeRange implements Comparable<TimeRange> {
  final TimeOfDay start;
  final TimeOfDay end;

  const TimeRange({
    required this.start,
    required this.end,
  });

  // Helper to determine if the range crosses into the next day
  bool get isOvernight => (end.hour < start.hour) || 
                          (end.hour == start.hour && end.minute < start.minute);

  // --- Serialization ---

  factory TimeRange.fromJson(Map<String, dynamic> json) {
    return TimeRange(
      start: TimeOfDay(
        hour: json['startHour'] as int,
        minute: json['startMinute'] as int,
      ),
      end: TimeOfDay(
        hour: json['endHour'] as int,
        minute: json['endMinute'] as int,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'startHour': start.hour,
        'startMinute': start.minute,
        'endHour': end.hour,
        'endMinute': end.minute,
      };

  // --- Logic ---

  /// Converts a UTC-stored time range to local time
  TimeRange toLocal() {
    final now = DateTime.now();

    final startUtc = DateTime.utc(
      now.year,
      now.month,
      now.day,
      start.hour,
      start.minute,
    );

    final endUtc = DateTime.utc(
      now.year,
      now.month,
      now.day,
      end.hour,
      end.minute,
    );

    return TimeRange(
      start: TimeOfDay.fromDateTime(startUtc.toLocal()),
      end: TimeOfDay.fromDateTime(endUtc.toLocal()),
    );
  }

  /// Clamps this range between optional min and max times
  TimeRange clamp({TimeOfDay? min, TimeOfDay? max}) {
    TimeOfDay clampedStart = start;
    TimeOfDay clampedEnd = end;

    if (min != null) {
      if (clampedStart.isBefore(min)) clampedStart = min;
      if (clampedEnd.isBefore(min)) clampedEnd = min;
    }

    if (max != null) {
      if (clampedStart.isAfter(max)) clampedStart = max;
      if (clampedEnd.isAfter(max)) clampedEnd = max;
    }

    return TimeRange(start: clampedStart, end: clampedEnd);
  }

  /// Returns true if [time] is within this range (inclusive)
  bool isTimeWithin(TimeOfDay time) {
    if (!isOvernight) {
      return !time.isBefore(start) && !time.isAfter(end);
    }
    // Overnight logic: Time must be >= start OR <= end
    // e.g., 10PM - 3AM: 11PM (true) or 1AM (true)
    return !time.isBefore(start) || !time.isAfter(end);
  }

  /// Returns true if [other] is fully contained within this range
  bool isRangeWithin(TimeRange other) {
    // We use DateTime comparison to handle the day wrapping accurately
    final refDate = DateTime(2026, 1, 1);
    final thisFull = toDateTimeRange(refDate);
    final otherFull = other.toDateTimeRange(refDate);

    return (otherFull.start.isAtSameMomentAs(thisFull.start) || otherFull.start.isAfter(thisFull.start)) &&
           (otherFull.end.isAtSameMomentAs(thisFull.end) || otherFull.end.isBefore(thisFull.end));
  }

  DateTimeRange toDateTimeRange(DateTime date) {
    final startDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      start.hour,
      start.minute,
    );

    DateTime endDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      end.hour,
      end.minute,
    );

    // If the range is overnight, the end date must be the next day
    if (isOvernight) {
      endDateTime = endDateTime.add(const Duration(days: 1));
    }

    return DateTimeRange(start: startDateTime, end: endDateTime);
  }

  TimeRange fromDateTimeRange(DateTimeRange dateTimeRange) {
    return TimeRange(
      start: TimeOfDay.fromDateTime(dateTimeRange.start),
      end: TimeOfDay.fromDateTime(dateTimeRange.end),
    );
  }

  // --- Comparable ---

  @override
  int compareTo(TimeRange other) {
    final startComp = start.compareTo(other.start);
    if (startComp != 0) return startComp;
    return end.compareTo(other.end);
  }

  // --- Equality ---

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimeRange &&
        other.start.hour == start.hour &&
        other.start.minute == start.minute &&
        other.end.hour == end.hour &&
        other.end.minute == end.minute;
  }

  @override
  int get hashCode =>
      Object.hash(start.hour, start.minute, end.hour, end.minute);

  // --- Formatting ---

  /// Format time range depending on locale and whether start/end are in the same period
  /// e.g. "9:00 AM - 5:30 PM" or "9:00-11:00 AM" or "14:00 - 18:00" 
  String format({Locale? locale}) {
    final String localeString =
        (locale ?? Locale(Intl.getCurrentLocale())).toString();

    final DateTime startDateTime =
        DateTime(0, 1, 1, start.hour, start.minute);

    final DateTime endDateTime =
        DateTime(0, 1, 1, end.hour, end.minute);

    final DateFormat timeFormatter =
        DateFormat.jm(localeString);

    final DateFormat periodFormatter =
        DateFormat('a', localeString);

    final String startPeriod =
        periodFormatter.format(startDateTime);

    final String endPeriod =
        periodFormatter.format(endDateTime);

    final bool is24HourLocale = startPeriod.isEmpty;
    final bool isSamePeriod = startPeriod == endPeriod;

    // 24-hour locales → no AM/PM collapsing needed
    if (is24HourLocale) {
      return '${timeFormatter.format(startDateTime)} – '
          '${timeFormatter.format(endDateTime)}';
    }

    // Same AM/PM → collapse period
    if (isSamePeriod) {
      final DateFormat hourMinuteFormatter =
          DateFormat('jm', localeString);

      final String startFormatted =
          hourMinuteFormatter.format(startDateTime);

      final String endFormatted =
          hourMinuteFormatter.format(endDateTime);

      final String startWithoutPeriod =
          startFormatted.substring(
            0,
            startFormatted.length - startPeriod.length - 1,
          );

      final String endWithoutPeriod =
          endFormatted.substring(
            0,
            endFormatted.length - endPeriod.length - 1,
          );

      return '$startWithoutPeriod-$endWithoutPeriod $startPeriod';
    }

    // Different periods
    return '${timeFormatter.format(startDateTime)} - '
        '${timeFormatter.format(endDateTime)}';
  }

  @override
  String toString() => format();
}