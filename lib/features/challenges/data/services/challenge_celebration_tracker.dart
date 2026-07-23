import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pure decision: does [current] represent a genuine tier increase
/// since this device last checked?
///
/// [hadBaseline] is the key distinction from a plain tier-rank
/// comparison: it separates "this device confirmed the user was at
/// [previous] (possibly no tier at all) on a prior visit" from "this
/// device has never checked before." Without it, a user who already
/// held Gold before ever opening the Challenges tab on THIS device
/// (e.g. a reinstall, or their very first visit after months of
/// attending treks) would see a false "just achieved!" celebration for
/// progress made before this device was watching. Only a real
/// observed increase — confirmed baseline to a higher tier — counts.
///
/// The trade-off this accepts: a user's very first EVER tier
/// (achieved before their very first Challenges tab visit) never
/// animates, since there's no prior observation to diff against. Every
/// crossing after that first visit animates correctly. Deliberately
/// not solved with a server-side "first seen" timestamp — that's
/// exactly the kind of maintained state Challenges' progress engine
/// otherwise avoids (see 0022_challenges.sql's doc), for one cosmetic
/// edge case.
///
/// A plain top-level function (not a [ChallengeCelebrationTracker]
/// method) so ChallengesScreen's detection loop and this file's own
/// unit tests exercise the exact same pure logic with no widget/prefs
/// dependency to fake.
bool isNewlyAchievedTier({
  required bool hadBaseline,
  required ChallengeTier? previous,
  required ChallengeTier? current,
}) {
  if (!hadBaseline || current == null) return false;
  final previousRank = previous == null ? -1 : ChallengeTier.values.indexOf(previous);
  final currentRank = ChallengeTier.values.indexOf(current);
  return currentRank > previousRank;
}

/// Per-device, per-user record of "the last tier this device saw for
/// each challenge" — purely a local UX concern (has this device shown
/// the celebration yet), not server state; see 0023_challenge_tier_
/// history.sql's doc for why that split is deliberate.
///
/// Backed by [SharedPreferences] rather than a Supabase table: this is
/// exactly the kind of state that's fine to lose (a reinstall just
/// means "don't celebrate on the very next visit," not a correctness
/// problem — [isNewlyAchievedTier]'s doc covers the trade-off), so the
/// cost of a real table (another RLS surface, another thing to keep in
/// sync) isn't worth paying for it.
class ChallengeCelebrationTracker {
  const ChallengeCelebrationTracker(this._prefs);

  final SharedPreferences _prefs;

  /// Sentinel stored when a challenge was checked but the user hadn't
  /// reached bronze yet — distinct from the key being entirely absent
  /// (never checked at all), which is what [hasBaseline] tests for.
  static const _noneSentinel = 'none';

  String _key(String userId, String challengeId) => 'challenge_tier_seen_${userId}_$challengeId';

  bool hasBaseline(String userId, String challengeId) =>
      _prefs.containsKey(_key(userId, challengeId));

  ChallengeTier? lastSeenTier(String userId, String challengeId) {
    final raw = _prefs.getString(_key(userId, challengeId));
    if (raw == null || raw == _noneSentinel) return null;
    for (final tier in ChallengeTier.values) {
      if (tier.name == raw) return tier;
    }
    return null;
  }

  Future<void> markSeen(String userId, String challengeId, ChallengeTier? tier) {
    return _prefs.setString(_key(userId, challengeId), tier?.name ?? _noneSentinel);
  }
}
