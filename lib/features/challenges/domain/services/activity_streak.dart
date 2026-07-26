/// Current run of consecutive days with recorded activity.
///
/// ## Why this exists client-side
///
/// The Challenges tab's summary header shows a "current activity streak",
/// and there is **no RPC that returns one**. The two things that sound
/// like they would are not:
///
///  - `get_my_streak()` (0024, fixed in 0033) is the **trekking** streak —
///    consecutive calendar *months* containing a checked-in trek. That is
///    an attendance stat and belongs to Profile, not to fitness.
///  - The day-granular activity streak exists only *inside*
///    `get_my_challenge_progress()` (0028), as the `daily_streak` CTE's
///    value for challenges whose metric is `active_streak_days`. It is not
///    exposed on its own, and it is only computed at all when such a
///    challenge is active.
///
/// Adding an RPC was out of scope for Phase 12 (the engine and its RPCs
/// were explicitly not to be touched), and `daily_activity_summary` is
/// readable own-row by its own RLS policy — so the header computes this
/// from rows the client can already fetch.
///
/// ## Matching the engine, deliberately
///
/// [computeActiveStreak] reimplements 0028's `daily_streak` rule
/// **exactly**, so a streak-metric challenge's progress value and the
/// header never disagree:
///
///  1. an "active day" is any date with `steps > 0` (distinct dates);
///  2. group consecutive dates into runs;
///  3. take the run with the latest end date;
///  4. return its length if that end is today **or yesterday**, else 0.
///
/// Step 4 is the grace rule from the engine's own comment — "yesterday
/// still counts, today isn't over yet" — so a user who hasn't walked yet
/// this morning doesn't watch their streak read 0.
///
/// ## One known divergence, flagged not hidden
///
/// The engine evaluates step 4 against bare `CURRENT_DATE`, which on
/// Supabase is **UTC**. This runs against the device's local date. For
/// IST (UTC+5:30) the two disagree between 00:00 and 05:30 local, where
/// UTC is still on the previous day and the engine is therefore one day
/// more lenient. Within the ±1-day grace window that almost never changes
/// the answer, but it can. Aligning it means changing the engine to
/// `(now() AT TIME ZONE 'Asia/Kolkata')::date` — the same fix 0033 already
/// applied to `get_my_streak()` — which is a migration, not a Phase 12
/// change.
library;

/// One day's step count, as read from `daily_activity_summary`.
///
/// Deliberately not the full `DailyActivity` entity: this computation only
/// needs the date and whether the day was active, and taking a minimal
/// record keeps it a pure function that is trivial to test.
class ActiveDay {
  const ActiveDay({required this.date, required this.steps});

  final DateTime date;
  final int steps;
}

/// The user's current activity streak in whole days, per the rule above.
///
/// [today] is injectable so tests don't depend on the wall clock. Returns
/// 0 for an empty list, for a user with no active days, and for a streak
/// that ended before yesterday — all of which are normal states, not
/// errors.
int computeActiveStreak(List<ActiveDay> days, {DateTime? today}) {
  // Normalise to date-only and drop inactive days, then dedupe: two rows
  // for the same calendar date must not count twice, mirroring the
  // engine's `SELECT DISTINCT das.date`.
  final activeDates =
      days
          .where((d) => d.steps > 0)
          .map((d) => DateTime(d.date.year, d.date.month, d.date.day))
          .toSet()
          .toList()
        ..sort();

  if (activeDates.isEmpty) return 0;

  // Walk back from the newest date, extending while each previous date is
  // exactly one day earlier. Only the LATEST run matters, so there is no
  // need to group every island the way the SQL does.
  final latest = activeDates.last;
  var length = 1;
  for (var i = activeDates.length - 2; i >= 0; i--) {
    if (activeDates[i + 1].difference(activeDates[i]).inDays == 1) {
      length++;
    } else {
      break;
    }
  }

  final now = today ?? DateTime.now();
  final todayDate = DateTime(now.year, now.month, now.day);
  final yesterday = todayDate.subtract(const Duration(days: 1));

  // The grace rule: a run that ended before yesterday is over.
  if (latest.isBefore(yesterday)) return 0;

  return length;
}
