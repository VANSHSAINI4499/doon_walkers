import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/home/domain/entities/community_stats.dart';
import 'package:doon_walkers/features/home/domain/repositories/community_stats_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Riverpod provider exposing the implementation of [CommunityStatsRepository].
final communityStatsRepositoryProvider = Provider<CommunityStatsRepository>(
  (ref) => CommunityStatsRepositoryImpl(ref.watch(supabaseClientProvider)),
  name: 'communityStatsRepositoryProvider',
);

/// Supabase implementation of [CommunityStatsRepository].
///
/// `get_community_stats()` is a `RETURNS TABLE(...)` function, so
/// PostgREST returns it as a single-row array rather than a bare object.
class CommunityStatsRepositoryImpl implements CommunityStatsRepository {
  final SupabaseClient _supabase;

  const CommunityStatsRepositoryImpl(this._supabase);

  @override
  Future<CommunityStats> fetchStats() async {
    final response = await _supabase.rpc('get_community_stats');
    final rows = response as List;
    if (rows.isEmpty) return CommunityStats.zero;
    return CommunityStats.fromJson(rows.first as Map<String, dynamic>);
  }
}
