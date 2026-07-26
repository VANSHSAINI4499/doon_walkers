import 'package:doon_walkers/features/activity/domain/services/activity_period.dart';

/// Display formatting for the Activity tab.
///
/// Pure string helpers, kept out of the widgets so the labelling rules
/// (which are fiddly and user-visible) can be tested directly. No `intl`
/// dependency — the app has none, and these are a handful of fixed English
/// formats rather than real localisation.
abstract final class ActivityFormat {
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const _monthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  /// Single letter for a chart axis. Deliberately not unique (Tuesday and
  /// Thursday both give "T") — that is the accepted convention for a
  /// 7-column axis where position already disambiguates.
  static String weekdayInitial(DateTime date) =>
      _weekdays[date.weekday - 1][0];

  static String weekdayShort(DateTime date) =>
      _weekdays[date.weekday - 1].substring(0, 3);

  static String monthShort(DateTime date) => _monthsShort[date.month - 1];

  /// "26 Jul 2026"
  static String dayShort(DateTime date) =>
      '${date.day} ${monthShort(date)} ${date.year}';

  /// The header label for a period, relative where that reads better.
  ///
  /// "Today"/"Yesterday" beat a date for the day view because that is how
  /// people refer to them; a week or month gets its range. [now] is
  /// injectable so this is testable without the wall clock.
  static String periodLabel(ActivityPeriod period, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());

    switch (period.granularity) {
      case ActivityGranularity.day:
        final d = period.from;
        if (d == today) return 'Today';
        if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
        // Omit the year for the current year — "12 Mar" is less cluttered
        // and the year is only informative when it is not this one.
        return d.year == today.year
            ? '${d.day} ${monthShort(d)}'
            : dayShort(d);

      case ActivityGranularity.week:
        if (period.contains(today)) return 'This week';
        final from = period.from;
        final to = period.to;
        // Collapse the month when both ends share it: "6 – 12 Jul", not
        // "6 Jul – 12 Jul".
        if (from.month == to.month) {
          return '${from.day} – ${to.day} ${monthShort(to)}';
        }
        return '${from.day} ${monthShort(from)} – ${to.day} ${monthShort(to)}';

      case ActivityGranularity.month:
        if (period.contains(today)) return 'This month';
        final m = _months[period.from.month - 1];
        return period.from.year == today.year
            ? m
            : '$m ${period.from.year}';
    }
  }

  /// A full-precision step count with thousands separators: "8,432".
  ///
  /// Hand-rolled rather than via `intl`: one format, no dependency.
  static String steps(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer(value < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  /// Compact for tight spaces: "8.4k", "12k", "947".
  static String stepsCompact(int value) {
    if (value.abs() < 1000) return '$value';
    final k = value / 1000;
    return k.abs() >= 10 ? '${k.round()}k' : '${k.toStringAsFixed(1)}k';
  }

  /// "4.2 km" — one decimal, because Health Connect's precision beyond
  /// that is noise for a walking app.
  static String distance(double km) => '${km.toStringAsFixed(1)} km';

  /// "312 kcal" — whole numbers; a fractional calorie is meaningless.
  static String calories(double kcal) => '${kcal.round()} kcal';

  /// A signed percentage for a delta: "+12%", "-8%", "0%".
  static String delta(int percent) =>
      percent > 0 ? '+$percent%' : '$percent%';

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
