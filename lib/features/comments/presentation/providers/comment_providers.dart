import 'dart:async';

import 'package:doon_walkers/features/comments/data/repositories/comment_repository_impl.dart';
import 'package:doon_walkers/features/comments/domain/entities/comment.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Every comment on one trek — Trek Detail's comment thread.
/// `autoDispose` since detail pages are visited transiently, same
/// reasoning as `trekGalleryProvider`.
///
/// Admin sees hidden comments here too — `comments_select`'s own
/// bypass, not a client-side filter (see [CommentRepository]'s doc) —
/// so [CommentTile] decides how a hidden one renders, this just
/// returns whatever RLS allowed through.
final trekCommentsProvider = FutureProvider.autoDispose.family<List<Comment>, String>(
  (ref, trekId) => ref.watch(commentRepositoryProvider).fetchCommentsForTrek(trekId),
  name: 'trekCommentsProvider',
);

/// Every currently-hidden comment across every trek — the admin
/// moderation queue (Admin Dashboard → Comment Moderation).
final hiddenCommentsProvider = FutureProvider<List<Comment>>(
  (ref) => ref.watch(commentRepositoryProvider).fetchHiddenComments(),
  name: 'hiddenCommentsProvider',
);

/// Blocklist terms for the client-side pre-submit check. Not
/// `autoDispose` — cheap, small, and reused by every comment box in the
/// app for the whole session; admin rarely edits it, so a session-long
/// cache is a reasonable tradeoff against refetching on every visit to
/// every trek. Purely a UX nicety either way — the
/// `check_comment_blocklist` trigger is the actual enforcement and
/// re-checks against the live table regardless of what this returns.
final commentBlocklistProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(commentRepositoryProvider).fetchBlocklistTerms(),
  name: 'commentBlocklistProvider',
);

/// Riverpod AsyncNotifier managing comment mutations (post, delete,
/// admin visibility toggle). Mirrors RegistrationController's shape.
final commentControllerProvider = AsyncNotifierProvider<CommentController, void>(
  CommentController.new,
  name: 'commentControllerProvider',
);

class CommentController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Posts a comment on [trekId]. Returns the created [Comment], or
  /// null on failure — in which case [state] carries the error, which
  /// may be a [CommentBlocklistException] the caller can show a
  /// specific message for.
  Future<Comment?> postComment({required String trekId, required String commentText}) async {
    state = const AsyncLoading();
    Comment? created;
    state = await AsyncValue.guard(() async {
      created = await ref.read(commentRepositoryProvider).createComment(
            trekId: trekId,
            commentText: commentText,
          );
    });
    if (created != null) {
      ref.invalidate(trekCommentsProvider(trekId));
    }
    return created;
  }

  Future<bool> deleteComment({required String id, required String trekId}) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await ref.read(commentRepositoryProvider).deleteComment(id);
      success = true;
    });
    if (success) {
      ref.invalidate(trekCommentsProvider(trekId));
      ref.invalidate(hiddenCommentsProvider);
    }
    return success;
  }

  /// Admin-only: hides or unhides a comment.
  Future<bool> setVisibility({
    required String id,
    required String trekId,
    required bool isVisible,
  }) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await ref.read(commentRepositoryProvider).setVisibility(id, isVisible);
      success = true;
    });
    if (success) {
      ref.invalidate(trekCommentsProvider(trekId));
      ref.invalidate(hiddenCommentsProvider);
    }
    return success;
  }
}
