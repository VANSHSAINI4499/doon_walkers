/// Abstract interface for authentication operations.
abstract class AuthRepository {
  /// Signs in with email and password.
  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  });

  /// Signs up with email, password, and full name.
  /// Passes `full_name` in user metadata so the database trigger sets `public.users.name`.
  Future<void> signUpWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
  });

  /// Signs out the active user session.
  Future<void> signOut();

  /// Sends a password reset email to [email].
  Future<void> sendPasswordResetEmail(String email);
}
