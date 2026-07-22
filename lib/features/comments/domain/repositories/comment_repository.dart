import 'package:doon_walkers/features/comments/domain/entities/comment.dart';

/// Abstract interface for reading and managing trek comments.
///
/// Every method here is backed by RLS on `public.comments`
/// (0002_role_policies.sql) — the UI gating is convenience, the
/// policies are the boundary:
///   - `comments_select`: `is_visible = TRUE OR is_admin()` — a hidden
///     comment is invisible to everyone except admin at the ROW level,
///     not just hidden by the client, so [fetchCommentsForTrek] and
///     [fetchHiddenComments] never need to filter client-side.
///   - `comments_insert`: `auth.uid() = user_id AND is_registered_user_or_admin()`
///   - `comments_update`: own row or admin, **and** `is_visible` is
///     additionally restricted to admins by the
///     `prevent_visibility_self_edit` trigger (0003)
///   - `comments_delete`: own row or admin
///   - INSERT/UPDATE OF comment additionally goes through the
///     `check_comment_blocklist` trigger (0012) — see
///     [CommentBlocklistException].
abstract class CommentRepository {
  /// Every comment on one trek, newest first. Returns hidden comments
  /// too when the caller is admin — `comments_select`'s own admin
  /// bypass, not a client-side filter — so [CommentTile] is what
  /// decides how a hidden one renders, not this fetch.
  Future<List<Comment>> fetchCommentsForTrek(String trekId);

  /// Every currently-hidden comment across every trek, newest first —
  /// the admin moderation queue. Joined with the trek title since this
  /// spans every trek, unlike [fetchCommentsForTrek].
  Future<List<Comment>> fetchHiddenComments();

  /// The blocklist terms from `public.comment_blocklist`, for the
  /// client-side pre-submit check (UX friction reduction only — the
  /// `check_comment_blocklist` trigger is what actually enforces this).
  Future<List<String>> fetchBlocklistTerms();

  /// Posts a comment as the signed-in user.
  ///
  /// `is_visible`/`user_name`/`user_avatar` are intentionally not
  /// parameters — `is_visible` defaults `true` server-side and is
  /// admin-writable only; `user_name`/`user_avatar` are populated by
  /// the `on_comment_insert_populate_user` trigger (0002), which
  /// overwrites whatever the client sends anyway.
  ///
  /// Throws [CommentBlocklistException] if the text matches a blocked
  /// term.
  Future<Comment> createComment({
    required String trekId,
    required String commentText,
  });

  /// Deletes a comment row — how a user removes their own comment
  /// (`comments_delete` allows own-row or admin; no "hide vs delete"
  /// distinction for a user's own content, only admin gets the
  /// reversible hide/show tool).
  Future<void> deleteComment(String id);

  /// Admin-only: sets `is_visible`. The
  /// `prevent_visibility_self_edit` trigger rejects this for any
  /// non-admin caller, so this fails server-side even if the UI were
  /// mis-gated.
  Future<void> setVisibility(String id, bool isVisible);

  /// Admin-only: adds a term to the blocklist —
  /// `comment_blocklist_insert_admin` (0012) rejects this for any
  /// non-admin caller. This is what makes ongoing list maintenance
  /// (Hindi/Hinglish terms, anything the starter list missed) a normal
  /// in-app admin action rather than something requiring a migration
  /// or direct Supabase dashboard access — see
  /// AdminBlocklistScreen.
  ///
  /// Throws [DuplicateBlocklistTermException] if the term (trimmed,
  /// lowercased) is already in the list.
  Future<void> addBlocklistTerm(String term);

  /// Admin-only: removes a term from the blocklist.
  Future<void> removeBlocklistTerm(String term);
}
