/// Core domain representation of a row in `public.comments`.
///
/// [userName]/[userAvatar] come from the row itself, not a join —
/// 0002_role_policies.sql denormalized them onto `comments` specifically
/// so rendering a comment thread never needs SELECT access to
/// `public.users` (which is locked to own-row-or-admin to protect
/// email/phone PII). A trigger keeps them in sync with the poster's
/// current name/avatar at insert time.
///
/// [trekTitle] is only populated where it's actually needed — the
/// cross-trek moderation queue, which joins `treks(title)` since it
/// spans every trek. The trek-scoped thread on Trek Detail already has
/// the trek in context and doesn't request the join, so this stays null
/// there.
class Comment {
  final String id;
  final String trekId;
  final String userId;
  final String commentText;
  final bool isVisible;
  final DateTime createdAt;
  final String userName;
  final String? userAvatar;
  final String? trekTitle;

  const Comment({
    required this.id,
    required this.trekId,
    required this.userId,
    required this.commentText,
    required this.isVisible,
    required this.createdAt,
    required this.userName,
    this.userAvatar,
    this.trekTitle,
  });
}

/// Thrown when the `check_comment_blocklist` trigger
/// (0012_comments_moderation.sql) rejects an insert or a comment-text
/// update because it matched a blocked term. The trigger is the real
/// enforcement — this exception exists so the UI can show a specific,
/// friendly message instead of a raw Postgres error, same pattern as
/// [DuplicateRegistrationException] elsewhere in this app.
///
/// Matched via `error.code == 'DWB01'`, a custom SQLSTATE the trigger
/// raises with explicitly — not the bare-RAISE default `P0001`, which
/// several *other* triggers on this project also produce and would be
/// ambiguous to match on.
class CommentBlocklistException implements Exception {
  const CommentBlocklistException();

  @override
  String toString() =>
      'This comment contains inappropriate language and cannot be posted. Please revise it.';
}

/// Thrown when [CommentRepository.addBlocklistTerm] is called with a
/// term (trimmed, lowercased) already present — `comment_blocklist`'s
/// PRIMARY KEY on `term` (0012) is what actually enforces uniqueness;
/// this maps the resulting 23505 to a message that reads as "already
/// covered" rather than a raw constraint-violation string.
class DuplicateBlocklistTermException implements Exception {
  const DuplicateBlocklistTermException();

  @override
  String toString() => 'That term is already in the blocklist.';
}
