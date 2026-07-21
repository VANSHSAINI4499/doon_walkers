/// One rung of the loyalty ladder — reached once a member's attended-trek
/// count meets [minAttended].
class LoyaltyBadge {
  final String name;
  final int minAttended;

  const LoyaltyBadge({required this.name, required this.minAttended});
}

/// The loyalty ladder, ordered lowest to highest threshold. Adding a new
/// tier is a one-line insertion here — [loyaltyBadgeFor] always resolves
/// to the highest tier the member's attended count clears, so no other
/// code needs to change.
///
/// Thresholds count [RegistrationStats.totalAttended] (Part D's
/// date-based "attended" approximation), not raw registrations — a badge
/// is meant to reflect treks actually walked, not just signed up for.
const List<LoyaltyBadge> loyaltyBadgeLadder = [
  LoyaltyBadge(name: 'Beginner Explorer', minAttended: 0),
  LoyaltyBadge(name: 'Nature Enthusiast', minAttended: 3),
  LoyaltyBadge(name: 'Trail Seeker', minAttended: 6),
  LoyaltyBadge(name: 'Mountain Explorer', minAttended: 10),
  LoyaltyBadge(name: 'Adventure Master', minAttended: 15),
];

/// The highest badge [attendedCount] qualifies for. [loyaltyBadgeLadder]'s
/// first entry has `minAttended: 0`, so this always returns a badge —
/// never null, even for a brand-new member.
LoyaltyBadge loyaltyBadgeFor(int attendedCount) {
  var current = loyaltyBadgeLadder.first;
  for (final badge in loyaltyBadgeLadder) {
    if (attendedCount >= badge.minAttended) current = badge;
  }
  return current;
}

/// The next badge above [attendedCount]'s current one, or null if
/// [attendedCount] has already reached the top of the ladder — callers
/// use this to render "X more treks to (next badge)" and should hide
/// that line entirely when null.
LoyaltyBadge? nextLoyaltyBadgeAfter(int attendedCount) {
  for (final badge in loyaltyBadgeLadder) {
    if (badge.minAttended > attendedCount) return badge;
  }
  return null;
}
