import 'package:doon_walkers/features/activity/domain/entities/user_achievement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserAchievement.fromJson', () {
    test('parses standard badge achievements correctly', () {
      final json = {
        'id': 'a1b2c3d4-e5f6-7a8b-9c0d-e1f2a3b4c5d6',
        'unlocked_at': '2026-07-26T12:00:00Z',
        'achievement_type': 'badge',
        'achievement_definitions': {
          'key': 'step_master',
          'title': 'Step Master',
          'description': '10,000 steps in a day',
          'icon_asset': 'assets/icons/badges/step_master.png',
          'unlock_metric': 'daily_steps',
          'unlock_value': 10000,
          'points_reward': 50,
        },
      };

      final achievement = UserAchievement.fromJson(json);

      expect(achievement.id, 'a1b2c3d4-e5f6-7a8b-9c0d-e1f2a3b4c5d6');
      expect(achievement.achievementType, 'badge');
      expect(achievement.key, 'step_master');
      expect(achievement.title, 'Step Master');
      expect(achievement.description, '10,000 steps in a day');
      expect(achievement.iconAsset, 'assets/icons/badges/step_master.png');
      expect(achievement.unlockMetric, 'daily_steps');
      expect(achievement.unlockValue, 10000);
      expect(achievement.pointsReward, 50);
      expect(achievement.unlockedAt.year, 2026);
    });

    test('parses level milestone achievements correctly', () {
      final json = {
        'id': 'b2c3d4e5-f6a7-8b9c-0d1e-2f3a4b5c6d7e',
        'achieved_at': '2026-07-26T14:30:00Z',
        'achievement_type': 'level_milestone',
        'reference_id': null,
        'metadata': {'level': 5},
        'key': 'level_milestone_5',
        'title': 'Level 5 Milestone',
        'description': 'Reached the level 5 milestone!',
        'icon_asset': 'assets/icons/badges/level_5.png',
      };

      final achievement = UserAchievement.fromJson(json);

      expect(achievement.id, 'b2c3d4e5-f6a7-8b9c-0d1e-2f3a4b5c6d7e');
      expect(achievement.achievementType, 'level_milestone');
      expect(achievement.key, 'level_milestone_5');
      expect(achievement.title, 'Level 5 Milestone');
      expect(achievement.description, 'Reached the level 5 milestone!');
      expect(achievement.iconAsset, 'assets/icons/badges/level_5.png');
      expect(achievement.unlockMetric, '');
      expect(achievement.unlockValue, 0);
      expect(achievement.pointsReward, 0);
      expect(achievement.metadata?['level'], 5);
      expect(achievement.unlockedAt.hour, 14);
    });

    test('parses challenge platinum achievements correctly', () {
      final json = {
        'id': 'c3d4e5f6-a7b8-9c0d-1e2f-3a4b5c6d7e8f',
        'achieved_at': '2026-07-26T15:45:00Z',
        'achievement_type': 'challenge_platinum',
        'reference_id': 'd4e5f6a7-b8c9-0d1e-2f3a-4b5c6d7e8f9a',
        'metadata': null,
        'key': 'challenge_platinum_d4e5f6a7-b8c9-0d1e-2f3a-4b5c6d7e8f9a',
        'title': 'Challenge Completed',
        'description':
            'Mastered a fitness challenge by reaching the Platinum tier!',
        'icon_asset': 'assets/icons/badges/platinum_challenge.png',
      };

      final achievement = UserAchievement.fromJson(json);

      expect(achievement.id, 'c3d4e5f6-a7b8-9c0d-1e2f-3a4b5c6d7e8f');
      expect(achievement.achievementType, 'challenge_platinum');
      expect(achievement.referenceId, 'd4e5f6a7-b8c9-0d1e-2f3a-4b5c6d7e8f9a');
      expect(achievement.title, 'Challenge Completed');
      expect(
        achievement.description,
        'Mastered a fitness challenge by reaching the Platinum tier!',
      );
      expect(
        achievement.iconAsset,
        'assets/icons/badges/platinum_challenge.png',
      );
      expect(achievement.unlockedAt.minute, 45);
    });
  });
}
