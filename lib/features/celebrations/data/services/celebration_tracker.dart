import 'package:shared_preferences/shared_preferences.dart';

/// The four duplicate-protection flags the brief calls for (Part 6) —
/// one enum rather than four booleans scattered across call sites, so
/// [CelebrationTracker] has exactly one method pair to cover all of
/// them.
enum CelebrationFlag {
  goalCelebrationShown,
  goalNotificationSent,
  streakCelebrationShown,
  streakNotificationSent,
}

/// Local-only "has this already happened today" tracker — the
/// duplicate-protection layer behind every celebration and
/// celebration-notification in this system.
///
/// Same [SharedPreferences]-backed, per-user-keyed shape as
/// [ChallengeCelebrationTracker] (challenge_celebration_tracker.dart),
/// but stores today's date string under a single, permanent key per
/// (flag, user) rather than a key that itself encodes the date. A
/// bare bool wouldn't reset on its own, and a date-suffixed key would
/// accumulate one entry per calendar day forever; comparing the stored
/// date against today's IS the reset Part 6 asks for ("reset
/// automatically when the calendar day changes") — once the day rolls
/// over, the stored value simply no longer matches and the flag reads
/// as false again, with nothing to explicitly clear.
class CelebrationTracker {
  const CelebrationTracker(this._prefs);

  final SharedPreferences _prefs;

  String _key(CelebrationFlag flag, String userId) =>
      'celebration_${flag.name}_$userId';

  static String _dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// [now] is overridable purely for tests — every real call site uses
  /// the actual clock.
  bool hasHappenedToday(CelebrationFlag flag, String userId, {DateTime? now}) {
    final stored = _prefs.getString(_key(flag, userId));
    if (stored == null) return false;
    return stored == _dateString(now ?? DateTime.now());
  }

  Future<void> markHappenedToday(
    CelebrationFlag flag,
    String userId, {
    DateTime? now,
  }) {
    return _prefs.setString(
      _key(flag, userId),
      _dateString(now ?? DateTime.now()),
    );
  }
}
