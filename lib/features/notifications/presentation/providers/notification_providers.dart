import 'dart:async';

import 'package:doon_walkers/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:doon_walkers/features/notifications/domain/entities/notification_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Every notification, newest first — the in-app list.
///
/// One-shot fetch, not a live stream — same reasoning as every other
/// admin-authored content list in this app (treks, gallery): a small
/// admin team posts these occasionally, not worth an open websocket
/// per session. Refresh via pull-to-refresh or the error state's Retry
/// button.
final notificationsProvider = FutureProvider<List<NotificationItem>>(
  (ref) => ref.watch(notificationRepositoryProvider).fetchNotifications(),
  name: 'notificationsProvider',
);

/// Riverpod AsyncNotifier managing the admin composer's submit action.
final notificationControllerProvider = AsyncNotifierProvider<NotificationController, void>(
  NotificationController.new,
  name: 'notificationControllerProvider',
);

class NotificationController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Broadcasts a notification: inserts into `public.notifications`,
  /// which is simultaneously the in-app record AND what the database
  /// webhook (send-push-notification Edge Function — see the Phase 8
  /// report, NOT YET DEPLOYED) triggers real pushes from.
  Future<NotificationItem?> sendNotification({
    required String title,
    required String body,
  }) async {
    state = const AsyncLoading();
    NotificationItem? created;
    state = await AsyncValue.guard(() async {
      created = await ref.read(notificationRepositoryProvider).createNotification(
            title: title,
            body: body,
          );
    });
    if (created != null) ref.invalidate(notificationsProvider);
    return created;
  }
}
