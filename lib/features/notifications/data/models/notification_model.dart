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
