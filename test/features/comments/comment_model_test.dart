import 'package:doon_walkers/features/comments/data/models/comment_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommentModel.toInsertJson', () {
    final payload = CommentModel.toInsertJson(
      trekId: 'trek-1',
      userId: 'user-1',
      commentText: 'Great trek, loved every bit of it!',
    );

    test('carries trek, user and the comment text', () {
      expect(payload['trek_id'], 'trek-1');
      expect(payload['user_id'], 'user-1');
      expect(payload['comment'], 'Great trek, loved every bit of it!');
    });

    test('never sends is_visible — that column is admin-only', () {
      // prevent_visibility_self_edit rejects this for any non-admin
      // caller; the client must rely on the DB default ('true') instead
      // of setting it, so its presence here would be a real bug.
      expect(payload.containsKey('is_visible'), isFalse);
    });

    test('never sends user_name/user_avatar — the insert trigger owns those', () {
      // on_comment_insert_populate_user overwrites whatever the client
      // sends anyway; sending them would be misleading dead weight.
      expect(payload.containsKey('user_name'), isFalse);
      expect(payload.containsKey('user_avatar'), isFalse);
    });
  });

  group('CommentModel.fromJson', () {
    final fullJson = {
      'id': 'comment-1',
      'trek_id': 'trek-1',
      'user_id': 'user-1',
      'comment': 'Beautiful views, highly recommend!',
      'is_visible': true,
      'created_at': '2026-07-20T09:30:00.000Z',
      'user_name': 'Aarav Sharma',
      'user_avatar': 'https://example.com/avatar.jpg',
    };

    test('parses every field from a full row without a treks join', () {
      final comment = CommentModel.fromJson(fullJson);

      expect(comment.id, 'comment-1');
      expect(comment.trekId, 'trek-1');
      expect(comment.userId, 'user-1');
      expect(comment.commentText, 'Beautiful views, highly recommend!');
      expect(comment.isVisible, isTrue);
      expect(comment.createdAt, DateTime.parse('2026-07-20T09:30:00.000Z'));
      expect(comment.userName, 'Aarav Sharma');
      expect(comment.userAvatar, 'https://example.com/avatar.jpg');
      expect(comment.trekTitle, isNull);
    });

    test('parses the joined trek title when present (moderation queue shape)', () {
      final json = {...fullJson, 'treks': {'title': 'Kedarkantha Trek'}};
      expect(CommentModel.fromJson(json).trekTitle, 'Kedarkantha Trek');
    });

    test('missing is_visible defaults to true, not false', () {
      final json = Map<String, dynamic>.from(fullJson)..remove('is_visible');
      expect(CommentModel.fromJson(json).isVisible, isTrue);
    });

    test('a blank user_name falls back to a placeholder, not an empty string', () {
      final json = {...fullJson, 'user_name': ''};
      expect(CommentModel.fromJson(json).userName, 'Unknown member');
    });

    test('a null user_avatar stays null (column is nullable)', () {
      final json = {...fullJson, 'user_avatar': null};
      expect(CommentModel.fromJson(json).userAvatar, isNull);
    });
  });
}
