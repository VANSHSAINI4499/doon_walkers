import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/community/data/repositories/community_repository_impl.dart';
import 'package:doon_walkers/features/community/domain/entities/community_leaderboard_entry.dart';
import 'package:doon_walkers/features/community/domain/entities/member_directory_entry.dart';
import 'package:doon_walkers/features/community/domain/repositories/community_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return CommunityRepositoryImpl(supabase);
});

final communityLeaderboardProvider = FutureProvider.family<
  List<CommunityLeaderboardEntry>,
  ({int limit, int offset})
>((ref, query) async {
  final repository = ref.watch(communityRepositoryProvider);
  return repository.getCommunityLeaderboard(
    limit: query.limit,
    offset: query.offset,
  );
});

final myCommunityRankProvider = FutureProvider<CommunityLeaderboardEntry?>((
  ref,
) async {
  final repository = ref.watch(communityRepositoryProvider);
  return repository.getMyCommunityRank();
});

final memberDirectoryProvider = FutureProvider.family<
  List<MemberDirectoryEntry>,
  ({int limit, int offset, String? search})
>((ref, query) async {
  final repository = ref.watch(communityRepositoryProvider);
  return repository.getMemberDirectory(
    limit: query.limit,
    offset: query.offset,
    search: query.search,
  );
});
