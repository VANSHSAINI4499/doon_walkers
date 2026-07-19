import 'package:doon_walkers/features/home/domain/entities/community_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommunityStats.fromJson', () {
    test('parses the get_community_stats() RPC row', () {
      final stats = CommunityStats.fromJson({
        'member_count': 42,
        'published_trek_count': 7,
        'registration_count': 15,
      });

      expect(stats.memberCount, 42);
      expect(stats.publishedTrekCount, 7);
      expect(stats.registrationCount, 15);
    });

    test('missing fields default to 0 instead of throwing', () {
      final stats = CommunityStats.fromJson({});

      expect(stats.memberCount, 0);
      expect(stats.publishedTrekCount, 0);
      expect(stats.registrationCount, 0);
    });

    test('matches CommunityStats.zero for an empty database', () {
      final stats = CommunityStats.fromJson({
        'member_count': 0,
        'published_trek_count': 0,
        'registration_count': 0,
      });

      expect(stats.memberCount, CommunityStats.zero.memberCount);
      expect(stats.publishedTrekCount, CommunityStats.zero.publishedTrekCount);
      expect(stats.registrationCount, CommunityStats.zero.registrationCount);
    });
  });
}
