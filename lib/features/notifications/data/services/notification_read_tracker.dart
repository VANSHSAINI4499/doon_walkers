import 'package:shared_preferences/shared_preferences.dart';

/// Per-device, per-user record of which notifications this device has
/// shown the user.
///
/// ## Why this is local and not a column
///
/// `public.notifications` has no read state — no `read_at`, no
/// `notification_reads` join table (verified against the live schema in
/// Phase 13). An unread filter and a bell badge both need one, and Phase
/// 13 was explicitly a no-backend-change phase.
///
/// So read state is a **device-local UX concern**, exactly like
/// `ChallengeCelebrationTracker` (which records the last tier a device has
/// celebrated, for the same reason and with the same reasoning): "has this
/// device shown you this yet" is a question about the device, not about the
/// account.
///
/// **The trade-off this accepts:** read state does not follow you to
/// another device or survive a reinstall. Sign in on a new phone and every
/// notification reads as unread once. For a 24-row announcement list that
/// is a fair price for zero schema change; if it stops being fair, a
/// `notification_reads (user_id, notification_id, read_at)` table swaps in
/// behind this same interface without the UI changing.
///
/// Keyed per user id so two accounts on one device don't inherit each
/// other's read state.
class NotificationReadTracker {
  const NotificationReadTracker(this._prefs);

  final SharedPreferences _prefs;

  static String _key(String userId) => 'notifications_read_$userId';

  /// The ids this device has marked read for [userId].
  Set<String> readIds(String userId) =>
      (_prefs.getStringList(_key(userId)) ?? const <String>[]).toSet();

  bool isRead(String userId, String notificationId) =>
      readIds(userId).contains(notificationId);

  /// Marks [notificationIds] read, merging with whatever was already
  /// stored. Returns true when this actually changed something, so a
  /// caller can skip an invalidation that would rebuild for nothing.
  Future<bool> markRead(String userId, Iterable<String> notificationIds) async {
    final current = readIds(userId);
    final merged = {...current, ...notificationIds};
    if (merged.length == current.length) return false;

    // Bounded so the list cannot grow without limit across years of
    // announcements. Newest-first is the caller's ordering, so trimming
    // from the end drops the oldest ids — and an id old enough to be
    // trimmed is one whose notification is far past the point anyone would
    // notice it flipping back to unread.
    final trimmed =
        merged.length > _maxTrackedIds
            ? merged.toList().sublist(0, _maxTrackedIds)
            : merged.toList();

    await _prefs.setStringList(_key(userId), trimmed);
    return true;
  }

  /// Clears this device's read state for [userId] — used on sign-out so a
  /// shared device doesn't leak "already read" into the next session.
  Future<void> clear(String userId) => _prefs.remove(_key(userId));

  static const int _maxTrackedIds = 500;
}

/// How many of [notificationIds] are not in [readIds].
///
/// A plain function rather than a tracker method so the badge count's
/// arithmetic is testable with no SharedPreferences to fake — same split
/// as `isNewlyAchievedTier` in the challenges feature.
int unreadCount({
  required Iterable<String> notificationIds,
  required Set<String> readIds,
}) => notificationIds.where((id) => !readIds.contains(id)).length;
