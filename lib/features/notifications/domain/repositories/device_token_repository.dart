/// Abstract interface for registering/removing this device's FCM token.
///
/// Backed by RLS on `public.device_tokens` (0014_device_tokens.sql) —
/// own-row INSERT/UPDATE/DELETE only, no SELECT policy at all for
/// anyone (including admin) through the client. Actual push delivery
/// reads this table server-side via the Edge Function's service-role
/// client, which bypasses RLS entirely.
///
/// Used internally by [PushNotificationService] — UI screens never
/// touch this directly, there's nothing for a user to see or manage
/// about their own device token.
abstract class DeviceTokenRepository {
  /// Upserts (insert or update) the current device's token, scoped to
  /// the signed-in user. Conflict target is `fcm_token`, not `user_id`
  /// — see the migration's doc for why (a token can be reassigned to a
  /// different user on the same device over time).
  Future<void> upsertToken(String fcmToken);

  /// Removes a token row — called before sign-out (see
  /// AuthController.signOut), since `auth.uid()` must still resolve to
  /// the signing-out user for the own-row DELETE policy to allow it;
  /// calling this after sign-out completes would always fail RLS.
  Future<void> removeToken(String fcmToken);
}
