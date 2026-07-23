/// Roles available within the DoonWalkers application.
/// Maps 1-to-1 with the `user_role` enum in Postgres (`guest`, `user`, `admin`).
enum UserRole {
  guest,
  user,
  admin;

  static UserRole fromString(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'user':
        return UserRole.user;
      default:
        return UserRole.guest;
    }
  }

  String toDbString() {
    switch (this) {
      case UserRole.admin:
        return 'admin';
      case UserRole.user:
        return 'user';
      case UserRole.guest:
        return 'guest';
    }
  }
}

/// Core domain representation of a DoonWalkers user.
class UserEntity {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final UserRole role;
  final String? profileImage;
  final DateTime createdAt;

  /// The user's own privacy preference for challenge leaderboards
  /// (Version 2, Phase C3) — defaults TRUE at the DB column level
  /// (0025_leaderboard.sql), self-editable via the existing
  /// `users_update_own_or_admin` policy. Enforced server-side inside
  /// `get_challenge_leaderboard()` itself, not just read here for
  /// display — this field only drives the Profile toggle's initial
  /// state.
  final bool showOnLeaderboard;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.profileImage,
    required this.createdAt,
    this.showOnLeaderboard = true,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isRegisteredUser => role == UserRole.user || role == UserRole.admin;
  bool get isGuest => role == UserRole.guest;
}
