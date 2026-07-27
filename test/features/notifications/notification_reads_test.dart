import 'package:doon_walkers/features/notifications/domain/entities/notification_item.dart';
import 'package:doon_walkers/features/notifications/presentation/providers/notification_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Notification Read State & Filters Tests', () {
    final broadcastItem = NotificationItem(
      id: 'notif-001',
      title: 'Community Announcement',
      body: 'New trek added to calendar!',
      createdAt: DateTime.now(),
      targetUserId: null,
    );

    final targetedItem = NotificationItem(
      id: 'notif-002',
      title: 'Trek Registration Confirmed',
      body: 'Your spot for Nag Tibba is confirmed.',
      createdAt: DateTime.now(),
      targetUserId: 'usr-123',
    );

    test('NotificationItem correctly distinguishes targeted vs broadcast', () {
      expect(broadcastItem.isTargeted, isFalse);
      expect(targetedItem.isTargeted, isTrue);
    });

    test('NotificationFilter labels match requirements', () {
      expect(NotificationFilter.all.label, 'All');
      expect(NotificationFilter.unread.label, 'Unread');
      expect(NotificationFilter.updates.label, 'Trek Updates');
      expect(NotificationFilter.announcements.label, 'Announcements');
    });

    test('Filter logic separates updates and announcements correctly', () {
      final list = [broadcastItem, targetedItem];

      final announcements = list.where((n) => !n.isTargeted).toList();
      final updates = list.where((n) => n.isTargeted).toList();

      expect(announcements.length, 1);
      expect(announcements.first.id, 'notif-001');

      expect(updates.length, 1);
      expect(updates.first.id, 'notif-002');
    });
  });
}
