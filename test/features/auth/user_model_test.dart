import 'package:doon_walkers/features/auth/data/models/user_model.dart';
import 'package:doon_walkers/features/auth/domain/entities/user_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserRole enum mapping', () {
    test('fromString parses correctly', () {
      expect(UserRole.fromString('admin'), UserRole.admin);
      expect(UserRole.fromString('ADMIN'), UserRole.admin);
      expect(UserRole.fromString('user'), UserRole.user);
      expect(UserRole.fromString('USER'), UserRole.user);
      expect(UserRole.fromString('guest'), UserRole.guest);
      expect(UserRole.fromString('random'), UserRole.guest);
      expect(UserRole.fromString(null), UserRole.guest);
    });

    test('toDbString outputs exact Postgres enum value', () {
      expect(UserRole.admin.toDbString(), 'admin');
      expect(UserRole.user.toDbString(), 'user');
      expect(UserRole.guest.toDbString(), 'guest');
    });
  });

  group('UserModel serialization & getters', () {
    final testDate = DateTime.utc(2026, 7, 19, 12, 0, 0);
    final jsonMap = {
      'id': 'uuid-123-abc',
      'name': 'Test Trekker',
      'email': 'trekker@doonwalkers.com',
      'phone': '+919876543210',
      'role': 'user',
      'profile_image': 'https://supabase.co/storage/v1/object/public/avatar.jpg',
      'created_at': testDate.toIso8601String(),
    };

    test('fromJson creates exact UserModel', () {
      final model = UserModel.fromJson(jsonMap);

      expect(model.id, 'uuid-123-abc');
      expect(model.name, 'Test Trekker');
      expect(model.email, 'trekker@doonwalkers.com');
      expect(model.phone, '+919876543210');
      expect(model.role, UserRole.user);
      expect(model.profileImage, 'https://supabase.co/storage/v1/object/public/avatar.jpg');
      expect(model.createdAt, testDate);
      expect(model.isAdmin, isFalse);
      expect(model.isRegisteredUser, isTrue);
      expect(model.isGuest, isFalse);
    });

    test('toJson outputs valid map matching schema', () {
      final model = UserModel.fromJson(jsonMap);
      final output = model.toJson();

      expect(output['id'], 'uuid-123-abc');
      expect(output['name'], 'Test Trekker');
      expect(output['email'], 'trekker@doonwalkers.com');
      expect(output['phone'], '+919876543210');
      expect(output['role'], 'user');
      expect(output['profile_image'], 'https://supabase.co/storage/v1/object/public/avatar.jpg');
      expect(output['created_at'], testDate.toIso8601String());
    });

    test('admin user returns isAdmin = true', () {
      final adminModel = UserModel.fromJson({
        ...jsonMap,
        'role': 'admin',
      });

      expect(adminModel.role, UserRole.admin);
      expect(adminModel.isAdmin, isTrue);
      expect(adminModel.isRegisteredUser, isTrue);
      expect(adminModel.isGuest, isFalse);
    });
  });
}
