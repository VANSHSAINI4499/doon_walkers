/// Core domain representation of a row in `public.notifications`.
///
/// Broadcast-only this phase — every row is community-wide, there is no
/// per-user/per-trek targeting concept (see the Phase 8 brief's
/// explicit scope boundary). [id] is included so a future phase could
/// add read-tracking or deep-linking without a schema change to this
/// entity.
class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
  });
}
