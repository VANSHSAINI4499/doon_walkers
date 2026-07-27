import 'package:doon_walkers/features/community/domain/entities/community_leaderboard_entry.dart';
import 'package:doon_walkers/features/community/domain/entities/member_directory_entry.dart';
import 'package:doon_walkers/features/community/domain/repositories/community_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityRepositoryImpl implements CommunityRepository {
  CommunityRepositoryImpl(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<List<CommunityLeaderboardEntry>> getCommunityLeaderboard({
    int limit = 50,
    int offset = 0,
  }) async {
    final response =
        await _supabase.rpc(
              'get_community_leaderboard',
              params: {'p_limit': limit, 'p_offset': offset},
            )
            as List<dynamic>;

    return response
        .map(
          (e) => CommunityLeaderboardEntry.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<CommunityLeaderboardEntry?> getMyCommunityRank() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final response =
        await _supabase.rpc('get_my_community_rank') as List<dynamic>;
    if (response.isEmpty) return null;

    return CommunityLeaderboardEntry.fromJson(
      response.first as Map<String, dynamic>,
    );
  }

  @override
  Future<List<MemberDirectoryEntry>> getMemberDirectory({
    int limit = 30,
    int offset = 0,
    String? search,
  }) async {
    final response =
        await _supabase.rpc(
              'get_member_directory',
              params: {
                'p_limit': limit,
                'p_offset': offset,
                'p_search': search,
              },
            )
            as List<dynamic>;

    return response
        .map((e) => MemberDirectoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
