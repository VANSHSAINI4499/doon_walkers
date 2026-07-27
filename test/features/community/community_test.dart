import 'package:doon_walkers/features/community/domain/entities/community_leaderboard_entry.dart';
import 'package:doon_walkers/features/community/domain/entities/member_directory_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Community Entities & Models Tests', () {
    test('CommunityLeaderboardEntry parses JSON correctly', () {
      final json = {
        'user_id': 'usr-100',
        'display_name': 'Aarav Sharma',
        'avatar_url': 'https://example.com/avatar1.jpg',
        'total_points': 1450,
        'level': 6,
        'rank': 1,
      };

      final entry = CommunityLeaderboardEntry.fromJson(json);
      expect(entry.userId, 'usr-100');
      expect(entry.displayName, 'Aarav Sharma');
      expect(entry.avatarUrl, 'https://example.com/avatar1.jpg');
      expect(entry.totalPoints, 1450);
      expect(entry.level, 6);
      expect(entry.rank, 1);
    });

    test('MemberDirectoryEntry parses JSON correctly', () {
      final json = {
        'user_id': 'usr-200',
        'display_name': 'Ananya Verma',
        'avatar_url': null,
        'total_points': 520,
        'level': 3,
        'created_at': '2026-06-15T10:30:00.000Z',
      };

      final entry = MemberDirectoryEntry.fromJson(json);
      expect(entry.userId, 'usr-200');
      expect(entry.displayName, 'Ananya Verma');
      expect(entry.avatarUrl, isNull);
      expect(entry.totalPoints, 520);
      expect(entry.level, 3);
      expect(entry.createdAt.year, 2026);
    });
  });
}
