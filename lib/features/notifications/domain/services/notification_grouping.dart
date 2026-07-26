import 'package:doon_walkers/features/notifications/domain/entities/notification_item.dart';

/// Which day-bucket a notification falls into.
///
/// Three buckets, not one-heading-per-date: with 24 rows spread over
/// months, a heading per date would produce more headings than content.
/// Today / Yesterday / Earlier is the smallest split that still answers
/// "is this new".
enum NotificationDayGroup {
  today,
  yesterday,
  earlier;

  String get label => switch (this) {
    NotificationDayGroup.today => 'Today',
    NotificationDayGroup.yesterday => 'Yesterday',
    NotificationDayGroup.earlier => 'Earlier',
  };
}

/// One heading plus the notifications under it.
class NotificationGroup {
  const NotificationGroup({required this.group, required this.items});

  final NotificationDayGroup group;
  final List<NotificationItem> items;
}

/// Buckets [notifications] into Today / Yesterday / Earlier, preserving
/// the input order within each bucket.
///
/// The caller fetches newest-first, so preserving order keeps each section
/// newest-first too without a second sort.
///
/// Comparison is done on **local** dates. `created_at` is `TIMESTAMPTZ`, so
/// a notification sent at 23:00 UTC is already the next day in IST — using
/// the UTC date would file it under the wrong heading for exactly the
/// members this app has. Empty groups are omitted rather than rendered as
/// bare headings.
List<NotificationGroup> groupNotificationsByDay(
  List<NotificationItem> notifications, {
  DateTime? now,
}) {
  final today = _localDate(now ?? DateTime.now());
  final yesterday = today.subtract(const Duration(days: 1));

  final buckets = <NotificationDayGroup, List<NotificationItem>>{
    NotificationDayGroup.today: [],
    NotificationDayGroup.yesterday: [],
    NotificationDayGroup.earlier: [],
  };

  for (final item in notifications) {
    final date = _localDate(item.createdAt);
    if (date == today) {
      buckets[NotificationDayGroup.today]!.add(item);
    } else if (date == yesterday) {
      buckets[NotificationDayGroup.yesterday]!.add(item);
    } else if (date.isAfter(today)) {
      // A future-dated row (clock skew, or an admin backdating) belongs
      // with the newest content, not filed under "Earlier" where nobody
      // would look for it.
      buckets[NotificationDayGroup.today]!.add(item);
    } else {
      buckets[NotificationDayGroup.earlier]!.add(item);
    }
  }

  return [
    for (final group in NotificationDayGroup.values)
      if (buckets[group]!.isNotEmpty)
        NotificationGroup(group: group, items: buckets[group]!),
  ];
}

/// A short relative timestamp for a notification row: "Just now", "5m",
/// "3h", "Yesterday", "12 Jul", "12 Jul 2025".
///
/// Deliberately terse — it sits at the end of a row next to a title, so it
/// has to stay narrow. The day heading above already carries the coarse
/// grouping, which is why this can drop to a bare time-ago for recent
/// items without losing context.
String formatNotificationTime(DateTime createdAt, {DateTime? now}) {
  final localNow = (now ?? DateTime.now()).toLocal();
  final local = createdAt.toLocal();
  final diff = localNow.difference(local);

  // A future timestamp (clock skew) reads as "Just now" rather than a
  // negative duration.
  if (diff.isNegative || diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';

  final today = _localDate(localNow);
  final date = _localDate(local);
  if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final label = '${local.day} ${months[local.month - 1]}';
  // The year only earns its space when it isn't the current one.
  return local.year == localNow.year ? label : '$label ${local.year}';
}

DateTime _localDate(DateTime dt) {
  final local = dt.toLocal();
  return DateTime(local.year, local.month, local.day);
}
