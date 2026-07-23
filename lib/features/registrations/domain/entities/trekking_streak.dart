/// The signed-in user's attendance streak — a row from
/// `get_my_streak()` (0024_streaks.sql, Version 2, Phase C3).
///
/// A streak is measured in CONSECUTIVE CALENDAR MONTHS with at least
/// one attended trek (same "attended" definition used everywhere else
/// in this project). [currentMonths] has a one-month grace period
/// baked into the RPC — see that migration's doc — so it doesn't drop
/// to 0 just because the current month's trek hasn't happened yet.
class TrekkingStreak {
  final int currentMonths;
  final int longestMonths;

  const TrekkingStreak({required this.currentMonths, required this.longestMonths});

  /// A brand-new member, or a guest — no history to compute from.
  static const TrekkingStreak zero = TrekkingStreak(currentMonths: 0, longestMonths: 0);

  bool get isActive => currentMonths > 0;
}
