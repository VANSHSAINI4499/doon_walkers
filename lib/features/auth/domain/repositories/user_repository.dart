/// Abstract interface for the signed-in user's own `public.users` row
/// self-service updates. Every method here is backed by the existing
/// `users_update_own_or_admin` RLS policy (auth.uid() = id OR
/// is_admin()) — no new policy was needed for the field this repository
/// adds (Version 2, Phase C3's `show_on_leaderboard`), same as how
/// `name`/`phone`/`profile_image` were already self-editable at the DB
/// layer before any Dart code existed to write them.
abstract class UserRepository {
  /// Sets the signed-in user's own leaderboard-visibility preference.
  /// Takes no user id — always updates the caller's own row (derived
  /// from the live session), same "no way to act on anyone but
  /// yourself" shape as every self-service write in this project.
  Future<void> updateShowOnLeaderboard(bool value);
}
