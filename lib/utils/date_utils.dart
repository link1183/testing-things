// lib/utils/date_utils.dart
import 'package:intl/intl.dart';

class MediaDateUtils {
  // Standard date formatters
  static final DateFormat _standardDateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _standardDateTimeFormat =
      DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat _monthYearFormat = DateFormat('MMMM yyyy');
  static final DateFormat _dayMonthFormat = DateFormat('d MMM');
  static final DateFormat _timeFormat = DateFormat('HH:mm');

  /// Format date using standard date format (yyyy-MM-dd)
  static String formatDate(DateTime date) {
    return _standardDateFormat.format(date);
  }

  /// Format date and time
  static String formatDateTime(DateTime date) {
    return _standardDateTimeFormat.format(date);
  }

  /// Format date for month-year view (e.g. "January 2023")
  static String formatMonthYear(DateTime date) {
    return _monthYearFormat.format(date);
  }

  /// Format date for day-month view (e.g. "15 Jan")
  static String formatDayMonth(DateTime date) {
    return _dayMonthFormat.format(date);
  }

  /// Format time only (e.g. "14:30")
  static String formatTime(DateTime date) {
    return _timeFormat.format(date);
  }

  /// Get a DateTime with time set to start of day
  static DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Check if two dates are the same day
  static bool isSameDay(DateTime? date1, DateTime? date2) {
    if (date1 == null || date2 == null) {
      return false;
    }

    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Get a human-readable relative date string
  static String getRelativeDateString(DateTime date) {
    final now = DateTime.now();
    final today = dateOnly(now);
    final yesterday = today.subtract(Duration(days: 1));
    final dateToCheck = dateOnly(date);

    if (isSameDay(dateToCheck, today)) {
      return 'Today, ${formatTime(date)}';
    } else if (isSameDay(dateToCheck, yesterday)) {
      return 'Yesterday, ${formatTime(date)}';
    } else if (dateToCheck.year == today.year) {
      // Same year, show day and month
      return '${formatDayMonth(date)}, ${formatTime(date)}';
    } else {
      // Different year, show full date
      return formatDateTime(date);
    }
  }

  /// Get list of months between two dates
  static List<DateTime> getMonthsBetween(DateTime start, DateTime end) {
    final months = <DateTime>[];
    var current = DateTime(start.year, start.month, 1);
    final endDate = DateTime(end.year, end.month, 1);

    while (!current.isAfter(endDate)) {
      months.add(current);
      current = DateTime(current.month < 12 ? current.year : current.year + 1,
          current.month < 12 ? current.month + 1 : 1, 1);
    }

    return months;
  }

  /// Get first day of the month
  static DateTime firstDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  /// Get last day of the month
  static DateTime lastDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }

  /// Calculate time difference between two dates in a human-readable format
  static String getTimeDifference(DateTime start, DateTime end) {
    final diff = end.difference(start);

    if (diff.inDays > 365) {
      final years = (diff.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'}';
    } else if (diff.inDays > 30) {
      final months = (diff.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'}';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'}';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} ${diff.inMinutes == 1 ? 'minute' : 'minutes'}';
    } else {
      return 'Just now';
    }
  }

  /// Get formatted age from a date until now (e.g. "2 years ago")
  static String getAgeString(DateTime date) {
    return '${getTimeDifference(date, DateTime.now())} ago';
  }
}
