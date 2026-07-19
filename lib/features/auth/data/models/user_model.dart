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
  });

  /// Creates a [UserModel] from a database row (JSON map).
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      phone: json['phone'] as String?,
      role: UserRole.fromString(json['role'] as String?),
      profileImage: json['profile_image'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
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
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Creates a copy of this [UserModel] with the given fields replaced.
  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    String? profileImage,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt,
    );
  }
}
