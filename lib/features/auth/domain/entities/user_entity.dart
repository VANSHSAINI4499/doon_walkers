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

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.profileImage,
    required this.createdAt,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isRegisteredUser => role == UserRole.user || role == UserRole.admin;
  bool get isGuest => role == UserRole.guest;
}
