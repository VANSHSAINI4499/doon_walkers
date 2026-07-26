import 'package:doon_walkers/features/profile/domain/entities/points_ledger_entry.dart';

/// Which day-bucket a points-ledger row falls into — same three-bucket
/// shape as `NotificationDayGroup` (Today / Yesterday / Earlier), kept as
/// its own copy here rather than a shared generic: the notifications
/// feature is out of scope for Phase 22, and duplicating ~40 lines is
/// cheaper than coupling two unrelated features through a shared type.
enum PointsDayGroup {
  today,
  yesterday,
  earlier;

  String get label => switch (this) {
    PointsDayGroup.today => 'Today',
    PointsDayGroup.yesterday => 'Yesterday',
    PointsDayGroup.earlier => 'Earlier',
  };
}

class PointsHistoryGroup {
  const PointsHistoryGroup({required this.group, required this.items});

  final PointsDayGroup group;
  final List<PointsLedgerEntry> items;
}

/// Buckets [entries] into Today / Yesterday / Earlier, preserving the
/// input order within each bucket. The caller fetches newest-first, so
/// preserving order keeps each section newest-first too.
///
/// Comparison is done on **local** dates, same reasoning as
/// `groupNotificationsByDay`: `created_at` is TIMESTAMPTZ, so a row
/// written late UTC can already be "tomorrow" locally.
List<PointsHistoryGroup> groupPointsHistoryByDay(
  List<PointsLedgerEntry> entries, {
  DateTime? now,
}) {
  final today = _localDate(now ?? DateTime.now());
  final yesterday = today.subtract(const Duration(days: 1));

  final buckets = <PointsDayGroup, List<PointsLedgerEntry>>{
    PointsDayGroup.today: [],
    PointsDayGroup.yesterday: [],
    PointsDayGroup.earlier: [],
  };

  for (final entry in entries) {
    final date = _localDate(entry.createdAt);
    if (date == today) {
      buckets[PointsDayGroup.today]!.add(entry);
    } else if (date == yesterday) {
      buckets[PointsDayGroup.yesterday]!.add(entry);
    } else if (date.isAfter(today)) {
      // Clock skew — file with the newest content, not under "Earlier"
      // where nobody would look for it.
      buckets[PointsDayGroup.today]!.add(entry);
    } else {
      buckets[PointsDayGroup.earlier]!.add(entry);
    }
  }

  return [
    for (final group in PointsDayGroup.values)
      if (buckets[group]!.isNotEmpty)
        PointsHistoryGroup(group: group, items: buckets[group]!),
  ];
}

/// A short relative timestamp for a ledger row: "Just now", "5m", "3h",
/// "Yesterday", "12 Jul", "12 Jul 2025" — same shape as
/// `formatNotificationTime`.
String formatPointsHistoryTime(DateTime createdAt, {DateTime? now}) {
  final localNow = (now ?? DateTime.now()).toLocal();
  final local = createdAt.toLocal();
  final diff = localNow.difference(local);

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
  return local.year == localNow.year ? label : '$label ${local.year}';
}

DateTime _localDate(DateTime dt) {
  final local = dt.toLocal();
  return DateTime(local.year, local.month, local.day);
}
