/// Date-range maths for the Activity tab's Day / Week / Month views.
///
/// Pure and self-contained: no Riverpod, no widgets, no Supabase. Every
/// off-by-one that would misattribute a day's steps to the wrong week or
/// silently drop the 31st of a month lives in here, so it is all directly
/// testable.
///
/// ## Conventions, fixed in one place
///
///  - **Weeks run Monday → Sunday.** That matches
///    `ChallengeTimeWindow.weekly`'s own documented rule ("the current
///    week (Monday to Sunday)"), so a week total on this tab agrees with
///    a weekly-steps challenge rather than quietly differing by a day.
///  - **Ranges are inclusive of both ends** ([from], [to] are both real
///    days that count). The repository query uses `>= from AND <= to`.
///  - **Everything is date-only.** Times are stripped on construction, so
///    a range can never half-include a day depending on the hour.
library;

/// Which granularity the Activity tab is showing.
enum ActivityGranularity {
  day,
  week,
  month;

  String get label => switch (this) {
    ActivityGranularity.day => 'Day',
    ActivityGranularity.week => 'Week',
    ActivityGranularity.month => 'Month',
  };
}

/// A concrete, navigable window of days.
class ActivityPeriod {
  ActivityPeriod._({
    required this.granularity,
    required DateTime from,
    required DateTime to,
  }) : from = _dateOnly(from),
       to = _dateOnly(to);

  final ActivityGranularity granularity;

  /// First day in the window, inclusive.
  final DateTime from;

  /// Last day in the window, inclusive.
  final DateTime to;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// The single day containing [date].
  factory ActivityPeriod.day(DateTime date) {
    final d = _dateOnly(date);
    return ActivityPeriod._(
      granularity: ActivityGranularity.day,
      from: d,
      to: d,
    );
  }

  /// The Monday–Sunday week containing [date].
  factory ActivityPeriod.week(DateTime date) {
    final d = _dateOnly(date);
    // DateTime.weekday is 1 (Mon) … 7 (Sun), so this lands on Monday for
    // every input including Sunday itself (7 - 1 = 6 days back).
    final monday = d.subtract(Duration(days: d.weekday - 1));
    return ActivityPeriod._(
      granularity: ActivityGranularity.week,
      from: monday,
      to: monday.add(const Duration(days: 6)),
    );
  }

  /// The calendar month containing [date].
  factory ActivityPeriod.month(DateTime date) {
    final first = DateTime(date.year, date.month);
    // Day 0 of the *next* month is the last day of this one — correct for
    // 28/29/30/31 without a leap-year table.
    final last = DateTime(date.year, date.month + 1, 0);
    return ActivityPeriod._(
      granularity: ActivityGranularity.month,
      from: first,
      to: last,
    );
  }

  /// The period of [granularity] containing [date].
  factory ActivityPeriod.of(ActivityGranularity granularity, DateTime date) =>
      switch (granularity) {
        ActivityGranularity.day => ActivityPeriod.day(date),
        ActivityGranularity.week => ActivityPeriod.week(date),
        ActivityGranularity.month => ActivityPeriod.month(date),
      };

  /// How many days this window spans (1, 7, or 28–31).
  int get dayCount => to.difference(from).inDays + 1;

  /// Every day in the window, ascending.
  List<DateTime> get days => [
    for (var i = 0; i < dayCount; i++) from.add(Duration(days: i)),
  ];

  /// The window immediately before this one, same granularity.
  ///
  /// Steps by *calendar* unit, not by [dayCount] — the month before March
  /// is February, not "31 days earlier", which would land in late January.
  ActivityPeriod get previous => switch (granularity) {
    ActivityGranularity.day => ActivityPeriod.day(
      from.subtract(const Duration(days: 1)),
    ),
    ActivityGranularity.week => ActivityPeriod.week(
      from.subtract(const Duration(days: 7)),
    ),
    ActivityGranularity.month => ActivityPeriod.month(
      DateTime(from.year, from.month - 1),
    ),
  };

  /// The window immediately after this one, same granularity.
  ActivityPeriod get next => switch (granularity) {
    ActivityGranularity.day => ActivityPeriod.day(
      from.add(const Duration(days: 1)),
    ),
    ActivityGranularity.week => ActivityPeriod.week(
      from.add(const Duration(days: 7)),
    ),
    ActivityGranularity.month => ActivityPeriod.month(
      DateTime(from.year, from.month + 1),
    ),
  };

  /// Whether [date] falls inside this window.
  bool contains(DateTime date) {
    final d = _dateOnly(date);
    return !d.isBefore(from) && !d.isAfter(to);
  }

  /// True when this window contains [now] — used to disable "next" so the
  /// user can't page into the future, where there is nothing to show.
  bool isCurrent(DateTime now) => contains(now);

  /// True when the whole window is in the future relative to [now].
  bool isFuture(DateTime now) => from.isAfter(_dateOnly(now));

  /// The step target for this window, derived from a single stored
  /// [dailyGoal] rather than three separately-stored goals.
  ///
  /// Month uses this period's own [dayCount], so February's target is
  /// genuinely smaller than March's instead of assuming 30.
  int stepGoal(int dailyGoal) => dailyGoal * dayCount;

  // Value equality matters: this type is a Riverpod `family` key. Without
  // it, two structurally identical periods would be different cache keys,
  // so every rebuild would re-fetch and the screen would flicker between
  // loading and data on any unrelated setState.
  @override
  bool operator ==(Object other) =>
      other is ActivityPeriod &&
      other.granularity == granularity &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(granularity, from, to);

  @override
  String toString() =>
      'ActivityPeriod(${granularity.name}, $from..$to)';
}
