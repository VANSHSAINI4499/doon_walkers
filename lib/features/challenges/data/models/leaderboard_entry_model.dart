import 'package:doon_walkers/features/challenges/domain/entities/leaderboard_entry.dart';

/// Data model for one row returned by `get_challenge_leaderboard()`.
class LeaderboardEntryModel extends LeaderboardEntry {
  const LeaderboardEntryModel({required super.displayName, required super.rank, required super.score});

  factory LeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntryModel(
      displayName: json['display_name'] as String? ?? 'A member',
      rank: (json['rank'] as num).toInt(),
      score: switch (json['score']) {
        final num n => n.toDouble(),
        final Object v => double.tryParse(v.toString()) ?? 0,
        null => 0,
      },
    );
  }
}
