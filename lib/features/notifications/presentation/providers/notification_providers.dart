import 'dart:async';

import 'package:doon_walkers/core/providers/shared_preferences_provider.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:doon_walkers/features/notifications/data/services/notification_read_migration_service.dart';
import 'package:doon_walkers/features/notifications/data/services/notification_read_tracker.dart';
import 'package:doon_walkers/features/notifications/domain/entities/notification_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NotificationFilter {
  all,
  unread,
  updates,
  announcements;

  String get label => switch (this) {
        NotificationFilter.all => 'All',
        NotificationFilter.unread => 'Unread',
        NotificationFilter.updates => 'Trek Updates',
        NotificationFilter.announcements => 'Announcements',
      };
}

final notificationsProvider = FutureProvider<List<NotificationItem>>(
  (ref) => ref.watch(notificationRepositoryProvider).fetchNotifications(),
  name: 'notificationsProvider',
);

final notificationReadTrackerProvider = Provider<NotificationReadTracker>(
  (ref) => NotificationReadTracker(ref.watch(sharedPreferencesProvider)),
  name: 'notificationReadTrackerProvider',
);

/// One-time local to DB migration service provider
final notificationReadMigrationServiceProvider =
    Provider<NotificationReadMigrationService>((ref) {
  return NotificationReadMigrationService(
    prefs: ref.watch(sharedPreferencesProvider),
    tracker: ref.watch(notificationReadTrackerProvider),
    repository: ref.watch(notificationRepositoryProvider),
  );
});

/// Server-side read notification IDs
final readNotificationIdsProvider = FutureProvider<Set<String>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const {};

  // Trigger one-time migration if needed
  await ref
      .read(notificationReadMigrationServiceProvider)
      .migrateLocalReadsIfNeeded(userId);

  return ref.watch(notificationRepositoryProvider).fetchReadNotificationIds();
}, name: 'readNotificationIdsProvider');

/// Server-side unread count driving bell badge
final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return 0;
  return ref.watch(notificationRepositoryProvider).getUnreadCount();
}, name: 'unreadNotificationCountProvider');

final notificationFilterProvider = StateProvider<NotificationFilter>(
  (ref) => NotificationFilter.all,
  name: 'notificationFilterProvider',
);

final notificationReadControllerProvider =
    AsyncNotifierProvider<NotificationReadController, void>(
  NotificationReadController.new,
  name: 'notificationReadControllerProvider',
);

class NotificationReadController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> markRead(String notificationId) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    await ref.read(notificationRepositoryProvider).markAsRead(notificationId);
    ref.invalidate(readNotificationIdsProvider);
    ref.invalidate(unreadNotificationCountProvider);
  }

  Future<void> markAllRead() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    await ref.read(notificationRepositoryProvider).markAllAsRead();
    ref.invalidate(readNotificationIdsProvider);
    ref.invalidate(unreadNotificationCountProvider);
    ref.invalidate(notificationsProvider);
  }
}

final notificationControllerProvider =
    AsyncNotifierProvider<NotificationController, void>(
  NotificationController.new,
  name: 'notificationControllerProvider',
);

class NotificationController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

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
