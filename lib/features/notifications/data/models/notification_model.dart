import 'package:doon_walkers/features/notifications/domain/entities/notification_item.dart';

/// Serialisation layer for [NotificationItem].
class NotificationModel {
  const NotificationModel._();

  static NotificationItem fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      // Read back as of Phase 13 — previously written on insert but
      // discarded on read, so the list couldn't tell a targeted message
      // from a broadcast.
      targetUserId: json['target_user_id'] as String?,
    );
  }

  static Map<String, dynamic> toInsertJson({
    required String title,
    required String body,
    String? targetUserId,
  }) {
    return {
      'title': title,
      'body': body,
      'target_user_id': targetUserId,
    };
  }
}
