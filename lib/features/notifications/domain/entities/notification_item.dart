/// Core domain representation of a row in `public.notifications`.
///
/// The table is exactly `id, title, body, created_at, target_user_id` —
/// there is no `type`, no `read_at`, no deep-link payload. Everything the
/// UI shows is derived from those five columns.
///
/// ## The two real kinds of notification
///
/// [targetUserId] is what distinguishes them, and it is the only typing
/// signal that exists:
///
///  - **null** → a community broadcast, authored by an admin in the Send
///    Notification composer. Everyone sees it.
///  - **set** → a message meant for one member. In practice today that is
///    a merch-inquiry status update. Only that member sees it, enforced by
///    RLS *and* by an explicit filter in the repository.
///
/// Redesign 2.0 Phase 13 surfaces this field (it was previously parsed on
/// insert but dropped on read) so the list can give the two a different
/// icon and tint. That is a read-only addition — no schema change.
class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;

  /// The single member this is addressed to, or null for a broadcast.
  ///
  /// Never used for filtering in the UI — the query already guarantees a
  /// caller only ever receives their own targeted rows. It is here purely
  /// so the presentation can tell the two apart.
  final String? targetUserId;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.targetUserId,
  });

  /// True when this was addressed to one member rather than broadcast.
  bool get isTargeted => targetUserId != null;
}
