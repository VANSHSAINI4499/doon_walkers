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

  /// Whether [phone] has been confirmed via OTP (Version 2, Phase Auth
  /// Upgrade). Set exclusively by the verify-otp Edge Function (or the
  /// grandfather backfill) — see the `on_user_update_check_phone_verified`
  /// DB trigger, which rejects any attempt to set this from a normal user
  /// session. Reset to false automatically whenever [phone] changes.
  final bool phoneVerified;

  /// When [phoneVerified] became true. Null while unverified.
  final DateTime? phoneVerifiedAt;

  /// The user's own daily step target, backing every progress figure on
  /// the Activity tab (Redesign 2.0, Phase 11). Defaults to 6,500 at the
  /// DB column level (0034_daily_step_goal.sql) and is self-editable via
  /// the existing `users_update_own_or_admin` policy — same shape as
  /// [showOnLeaderboard].
  ///
  /// Weekly and monthly targets are **derived** from this, not stored:
  /// see `ActivityPeriod.stepGoal`.
  final int dailyStepGoal;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.profileImage,
    required this.createdAt,
    this.showOnLeaderboard = true,
    this.phoneVerified = false,
    this.phoneVerifiedAt,
    this.dailyStepGoal = defaultDailyStepGoal,
  });

  /// Mirrors the DB column default so a row fetched before the column
  /// existed (or a locally-constructed entity) agrees with the server.
  static const int defaultDailyStepGoal = 6500;

  bool get isAdmin => role == UserRole.admin;
  bool get isRegisteredUser => role == UserRole.user || role == UserRole.admin;
  bool get isGuest => role == UserRole.guest;

  /// Alias for profileImage matching Supabase column avatar_url (Phase 27).
  String? get avatarUrl => profileImage;
}
