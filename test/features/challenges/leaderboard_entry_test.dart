import 'package:doon_walkers/features/challenges/data/models/leaderboard_entry_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LeaderboardEntryModel.fromJson', () {
    test('parses a get_challenge_leaderboard() RPC row', () {
      final entry = LeaderboardEntryModel.fromJson({
        'display_name': 'Manju',
        'rank': 1,
        'score': '20.00',
      });

      expect(entry.displayName, 'Manju');
      expect(entry.rank, 1);
      expect(entry.score, 20.0);
    });

    test('a null display_name falls back to a placeholder, not an empty string', () {
      final entry = LeaderboardEntryModel.fromJson({
        'display_name': null,
        'rank': 4,
        'score': 3,
      });

      expect(entry.displayName, isNotEmpty);
    });

    test('score parses whether Postgres sends it as a number or a numeric string', () {
      final fromNum = LeaderboardEntryModel.fromJson({'display_name': 'A', 'rank': 1, 'score': 12.5});
      final fromString = LeaderboardEntryModel.fromJson({'display_name': 'A', 'rank': 1, 'score': '12.5'});

      expect(fromNum.score, 12.5);
      expect(fromString.score, 12.5);
    });
  });
}
