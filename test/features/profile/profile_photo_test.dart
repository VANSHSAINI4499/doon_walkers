import 'package:doon_walkers/features/auth/data/models/user_model.dart';
import 'package:doon_walkers/features/auth/domain/entities/user_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Profile Photo & UserModel Tests', () {
    test('UserModel parses avatar_url from JSON correctly', () {
      final json = {
        'id': 'user-123',
        'name': 'Doon Walker',
        'email': 'walker@doon.org',
        'role': 'user',
        'avatar_url': 'https://example.com/avatars/user-123/avatar.jpg',
        'created_at': '2026-07-27T00:00:00.000Z',
      };

      final model = UserModel.fromJson(json);
      expect(model.avatarUrl, 'https://example.com/avatars/user-123/avatar.jpg');
      expect(model.profileImage, 'https://example.com/avatars/user-123/avatar.jpg');
    });

    test('UserModel falls back to profile_image if avatar_url is missing', () {
      final json = {
        'id': 'user-456',
        'name': 'Old Walker',
        'email': 'old@doon.org',
        'role': 'user',
        'profile_image': 'https://example.com/old/photo.jpg',
        'created_at': '2026-07-27T00:00:00.000Z',
      };

      final model = UserModel.fromJson(json);
      expect(model.avatarUrl, 'https://example.com/old/photo.jpg');
    });

    test('UserEntity avatarUrl returns null when no photo is set', () {
      final user = UserEntity(
        id: 'user-789',
        name: 'Guest User',
        email: 'guest@doon.org',
        role: UserRole.guest,
        createdAt: DateTime.parse('2026-07-27T00:00:00.000Z'),
      );

      expect(user.avatarUrl, isNull);
    });
  });
}
