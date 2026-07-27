import 'package:doon_walkers/features/notifications/domain/entities/notification_item.dart';

abstract class NotificationRepository {
  Future<List<NotificationItem>> fetchNotifications();

  Future<NotificationItem> createNotification({
    required String title,
    required String body,
    String? targetUserId,
  });

  Future<Set<String>> fetchReadNotificationIds();

  Future<void> markAsRead(String notificationId);

  Future<int> markAllAsRead();

  Future<int> getUnreadCount();
}
