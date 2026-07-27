import 'package:doon_walkers/features/community/domain/entities/community_leaderboard_entry.dart';
import 'package:doon_walkers/features/community/domain/entities/member_directory_entry.dart';

abstract class CommunityRepository {
  Future<List<CommunityLeaderboardEntry>> getCommunityLeaderboard({
    int limit = 50,
    int offset = 0,
  });

  Future<CommunityLeaderboardEntry?> getMyCommunityRank();

  Future<List<MemberDirectoryEntry>> getMemberDirectory({
    int limit = 30,
    int offset = 0,
    String? search,
  });
}
