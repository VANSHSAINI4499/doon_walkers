/// Outcome of a sign-up attempt.
enum SignUpResult {
  /// A session was created immediately — email confirmation is disabled
  /// on this Supabase project, so the user is already signed in.
  sessionCreated,

  /// Sign-up succeeded, but no session was created because the account
  /// is awaiting email confirmation ("Confirm email" is enabled).
  confirmationPending,
}

/// Abstract interface for authentication operations.
abstract class AuthRepository {
  /// Signs in with email and password.
  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  });

  /// Signs up with email, password, and full name.
  /// Passes `full_name` in user metadata so the database trigger sets `public.users.name`.
  ///
  /// Returns a [SignUpResult] so callers can distinguish an immediate
  /// session from a pending email confirmation — Supabase does not throw
  /// in either case, so this can't be inferred from an exception.
  Future<SignUpResult> signUpWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
  });

  /// Signs in (or, on first use, signs up) with a native Google account
  /// picker. Supabase verifies the returned ID token and creates the
  /// `auth.users` row itself; `public.users` is populated by the same
  /// `handle_new_user` trigger email/password sign-up uses, reading
  /// `full_name`/`avatar_url` out of the token's claims instead of a
  /// caller-supplied `data:` map.
  ///
  /// Returns normally (without throwing) if the user dismisses the
  /// account picker — that's a deliberate cancel, not a failure, so it
  /// shouldn't surface as an error to the caller.
  Future<void> signInWithGoogle();

  /// Signs out the active user session.
  Future<void> signOut();

  /// Sends a password reset email to [email].
  Future<void> sendPasswordResetEmail(String email);
}
