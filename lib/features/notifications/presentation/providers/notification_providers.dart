import 'dart:async';

import 'package:doon_walkers/core/providers/shared_preferences_provider.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:doon_walkers/features/notifications/data/services/notification_read_tracker.dart';
import 'package:doon_walkers/features/notifications/domain/entities/notification_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which notifications the list is showing.
enum NotificationFilter {
  all,
  unread;

  String get label => switch (this) {
    NotificationFilter.all => 'All',
    NotificationFilter.unread => 'Unread',
  };
}

/// Every notification visible to the caller, newest first — the in-app
/// list.
///
/// One-shot fetch, not a live stream — same reasoning as every other
/// admin-authored content list in this app (treks, gallery): a small
/// admin team posts these occasionally, not worth an open websocket per
/// session. Refresh via pull-to-refresh or the error state's Retry.
///
/// The repository applies the `target_user_id` filter (own targeted rows
/// plus every broadcast) on top of RLS — see its own doc. Nothing here
/// filters by recipient, and nothing should.
final notificationsProvider = FutureProvider<List<NotificationItem>>(
  (ref) => ref.watch(notificationRepositoryProvider).fetchNotifications(),
  name: 'notificationsProvider',
);

/// Per-device read state. See [NotificationReadTracker] for why read state
/// is local rather than a column.
final notificationReadTrackerProvider = Provider<NotificationReadTracker>(
  (ref) => NotificationReadTracker(ref.watch(sharedPreferencesProvider)),
  name: 'notificationReadTrackerProvider',
);

/// The ids this device has marked read for the signed-in user.
///
/// A [StateProvider] rather than a plain read of the tracker so marking
/// something read re-renders the list and the badge immediately —
/// SharedPreferences has no change notification of its own.
final readNotificationIdsProvider = StateProvider<Set<String>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const {};
  return ref.watch(notificationReadTrackerProvider).readIds(userId);
}, name: 'readNotificationIdsProvider');

/// How many visible notifications this device hasn't shown yet — drives
/// the bell badge in the app shell.
///
/// 0 while the list is still loading and 0 for a guest, so the badge never
/// flashes a number it then has to correct.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider).valueOrNull;
  if (notifications == null) return 0;
  return unreadCount(
    notificationIds: notifications.map((n) => n.id),
    readIds: ref.watch(readNotificationIdsProvider),
  );
}, name: 'unreadNotificationCountProvider');

/// The list's All/Unread selection. Screen-local in spirit, but a provider
/// so the filter survives a pull-to-refresh rebuild.
final notificationFilterProvider = StateProvider<NotificationFilter>(
  (ref) => NotificationFilter.all,
  name: 'notificationFilterProvider',
);

/// Marks notifications read on this device.
///
/// Used by the Notifications screen when it opens: everything currently in
/// the list becomes read, which is what clears the bell badge. Deliberately
/// **not** per-row-on-scroll — the user opened the list, that is the
/// signal, and per-row tracking would mean an unread item scrolled past
/// silently stays unread forever.
final notificationReadControllerProvider =
    AsyncNotifierProvider<NotificationReadController, void>(
      NotificationReadController.new,
      name: 'notificationReadControllerProvider',
    );

class NotificationReadController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Marks every id in [ids] read for the signed-in user.
  ///
  /// A no-op for a guest and when nothing changed, so calling it on every
  /// screen open is cheap.
  Future<void> markRead(Iterable<String> ids) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final changed = await ref
        .read(notificationReadTrackerProvider)
        .markRead(userId, ids);
    if (!changed) return;

    // Push the new set into the StateProvider so the badge and the unread
    // filter update without waiting for a rebuild from elsewhere.
    ref.read(readNotificationIdsProvider.notifier).state = ref
        .read(notificationReadTrackerProvider)
        .readIds(userId);
  }
}

/// Riverpod AsyncNotifier managing the admin composer's submit action.
final notificationControllerProvider =
    AsyncNotifierProvider<NotificationController, void>(
      NotificationController.new,
      name: 'notificationControllerProvider',
    );

class NotificationController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Broadcasts a notification: inserts into `public.notifications`,
  /// which is simultaneously the in-app record AND what the database
  /// webhook (send-push-notification Edge Function) triggers real pushes
  /// from. Untouched by Phase 13 — zero backend change.
  Future<NotificationItem?> sendNotification({
    required String title,
    required String body,
  }) async {
    state = const AsyncLoading();
    NotificationItem? created;
    state = await AsyncValue.guard(() async {
      created = await ref
          .read(notificationRepositoryProvider)
          .createNotification(title: title, body: body);
    });
    if (created != null) ref.invalidate(notificationsProvider);
    return created;
  }
}
