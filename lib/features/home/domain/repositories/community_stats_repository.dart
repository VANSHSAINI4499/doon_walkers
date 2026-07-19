import 'package:doon_walkers/features/home/domain/entities/community_stats.dart';

/// Abstract interface for fetching aggregate community statistics.
abstract class CommunityStatsRepository {
  /// Fetches the current aggregate counts via the `get_community_stats()`
  /// RPC. Callable by guests — no auth required, no PII returned.
  Future<CommunityStats> fetchStats();
}
