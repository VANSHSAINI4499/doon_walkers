import 'package:doon_walkers/features/notifications/domain/entities/notification_item.dart';

/// Abstract interface for reading and sending broadcast notifications.
///
/// Backed by RLS on `public.notifications` (0001_baseline_schema.sql,
/// unchanged this phase): `notifications_select` allows any
/// authenticated user; insert/update/delete are admin-only. This
/// repository only ever reads and creates — nothing in this phase
/// edits or deletes an existing notification.
abstract class NotificationRepository {
  /// Every notification, newest first.
  Future<List<NotificationItem>> fetchNotifications();

  /// Admin-only: creates a notification row. This is what the database
  /// webhook (see supabase/functions/send-push-notification/) actually
  /// triggers on — inserting here is simultaneously "save the
  /// in-app-visible record" and "kick off the real push," by design,
  /// not two separate steps the client has to coordinate.
  Future<NotificationItem> createNotification({
    required String title,
    required String body,
  });
}
