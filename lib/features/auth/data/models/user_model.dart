import 'package:doon_walkers/features/auth/domain/entities/user_entity.dart';

/// Data model representing a row in the Postgres `public.users` table,
/// extending [UserEntity] with JSON serialization capabilities.
class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
    super.phone,
    required super.role,
    super.profileImage,
    required super.createdAt,
    super.showOnLeaderboard,
    super.phoneVerified,
    super.phoneVerifiedAt,
    super.dailyStepGoal,
  });

  /// Creates a [UserModel] from a database row (JSON map).
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      phone: json['phone'] as String?,
      role: UserRole.fromString(json['role'] as String?),
      profileImage:
          (json['avatar_url'] as String?) ?? (json['profile_image'] as String?),
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now(),
      // Missing (older cached row shape) defaults true, matching the
      // DB column's own default — never silently opts someone out.
      showOnLeaderboard: json['show_on_leaderboard'] as bool? ?? true,
      phoneVerified: json['phone_verified'] as bool? ?? false,
      phoneVerifiedAt:
          json['phone_verified_at'] != null
              ? DateTime.parse(json['phone_verified_at'] as String)
              : null,
      // Same "missing means the column default" treatment as
      // show_on_leaderboard above — a cached row from before 0034 must
      // not resolve to a 0 goal, which would divide by zero downstream.
      dailyStepGoal:
          (json['daily_step_goal'] as num?)?.toInt() ??
          UserEntity.defaultDailyStepGoal,
    );
  }

  /// Converts this [UserModel] to a JSON map suitable for database insertion/update.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      if (phone != null) 'phone': phone,
      'role': role.toDbString(),
      if (profileImage != null) 'profile_image': profileImage,
      if (profileImage != null) 'avatar_url': profileImage,
      'created_at': createdAt.toIso8601String(),
      'show_on_leaderboard': showOnLeaderboard,
      'daily_step_goal': dailyStepGoal,
    };
  }

  /// Creates a copy of this [UserModel] with the given fields replaced.
  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    String? profileImage,
    bool? showOnLeaderboard,
    int? dailyStepGoal,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt,
      showOnLeaderboard: showOnLeaderboard ?? this.showOnLeaderboard,
      phoneVerified: phoneVerified,
      phoneVerifiedAt: phoneVerifiedAt,
      dailyStepGoal: dailyStepGoal ?? this.dailyStepGoal,
    );
  }
}
