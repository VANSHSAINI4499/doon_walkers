/// Client-side mirror of the server-side `check_comment_blocklist`
/// trigger's word-boundary matching (0012_comments_moderation.sql) —
/// same semantics on purpose, so the client never warns on something
/// the trigger would allow, or stays silent on something the trigger
/// would reject.
///
/// UX friction reduction only — the trigger is the actual enforcement
/// and re-checks against the live table regardless of this function's
/// result (e.g. if [terms] here is a stale client-side cache).
///
/// Known limits (explicitly not solved by this or the trigger): spaced
/// ("a s s"), misspelled, or leetspeak evasions of a blocked term all
/// still get through — word-boundary matching only avoids the OTHER
/// common failure mode of a naive filter, false-positiving on an
/// innocent word that merely *contains* a blocked term as a substring
/// (e.g. blocking "ass" would otherwise also catch "class", "assess").
/// Admin moderation is the real backstop for what this misses.
bool commentMatchesBlocklist(String text, List<String> terms) {
  for (final term in terms) {
    if (term.isEmpty) continue;
    final pattern = RegExp(r'\b' + RegExp.escape(term) + r'\b', caseSensitive: false);
    if (pattern.hasMatch(text)) return true;
  }
  return false;
}
