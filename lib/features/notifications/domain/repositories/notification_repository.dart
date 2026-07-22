import 'package:doon_walkers/features/notifications/domain/entities/notification_item.dart';

/// Abstract interface for reading and sending notifications — both
/// broadcast (everyone) and targeted (one user), as of
/// 0021_notifications_targeting.sql (Version 2, Phase M2 fix).
///
/// Backed by RLS on `public.notifications`: `notifications_select`
/// requires being signed in AND (the row is a broadcast OR it targets
/// the caller specifically) — see that migration's doc for why the
/// sign-in check and the targeting check are AND'd rather than the
/// targeting check alone. insert/update/delete are admin-only. This
/// repository only ever reads and creates — nothing edits or deletes
/// an existing notification.
abstract class NotificationRepository {
  /// Every notification the caller is allowed to see, newest first —
  /// broadcasts plus (if signed in) their own targeted notifications.
  Future<List<NotificationItem>> fetchNotifications();

  /// Admin-only: creates a notification row. This is what the database
  /// webhook (see supabase/functions/send-push-notification/) actually
  /// triggers on — inserting here is simultaneously "save the
  /// in-app-visible record" and "kick off the real push," by design,
  /// not two separate steps the client has to coordinate.
  ///
  /// [targetUserId] null (the default) is a broadcast to everyone —
  /// the original Phase 8 behavior, unchanged. A non-null value
  /// delivers only to that one user, both in-app (via
  /// `notifications_select`'s RLS filter) and as a push (via the Edge
  /// Function reading this same column — see its own doc). The first
  /// caller of targeted delivery is
  /// `MerchInquiryRepository.updateStatus`.
  Future<NotificationItem> createNotification({
    required String title,
    required String body,
    String? targetUserId,
  });
}
