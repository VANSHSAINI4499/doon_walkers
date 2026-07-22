import 'package:doon_walkers/features/comments/domain/entities/comment.dart';

/// Serialisation layer for [Comment].
///
/// [fromJson] handles two shapes: the trek-scoped thread's plain
/// `.select('*')` (no `treks` key at all), and the moderation queue's
/// `.select('*, treks(title)')` (nested `treks` map) — [trekTitle]
/// stays null in the first case rather than defaulting to a
/// placeholder string, since the trek is already known from context
/// there and a fabricated "Unknown trek" would be actively wrong.
class CommentModel {
  const CommentModel._();

  static Comment fromJson(Map<String, dynamic> json) {
    final trek = json['treks'] as Map<String, dynamic>?;

    return Comment(
      id: json['id'] as String,
      trekId: json['trek_id'] as String,
      userId: json['user_id'] as String,
      commentText: json['comment'] as String,
      isVisible: json['is_visible'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      userName: (json['user_name'] as String?)?.trim().isNotEmpty == true
          ? json['user_name'] as String
          : 'Unknown member',
      userAvatar: json['user_avatar'] as String?,
      trekTitle: trek?['title'] as String?,
    );
  }

  /// Payload for posting a comment. Deliberately omits `is_visible`
  /// (defaults `true`, admin-writable only) and `user_name`/
  /// `user_avatar` (populated by the `on_comment_insert_populate_user`
  /// trigger — see CommentRepository.createComment's doc).
  static Map<String, dynamic> toInsertJson({
    required String trekId,
    required String userId,
    required String commentText,
  }) {
    return {
      'trek_id': trekId,
      'user_id': userId,
      'comment': commentText,
    };
  }
}
