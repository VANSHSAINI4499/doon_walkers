import 'package:doon_walkers/features/home/data/repositories/community_stats_repository_impl.dart';
import 'package:doon_walkers/features/home/domain/entities/community_stats.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One-shot fetch of aggregate community stats for the Home screen.
///
/// Deliberately left as `AsyncValue` (not swallowed into a zero-fallback
/// here) so a genuine failure stays inspectable — the widget decides how
/// to soften that visually; the provider doesn't hide it.
final communityStatsProvider = FutureProvider<CommunityStats>(
  (ref) => ref.watch(communityStatsRepositoryProvider).fetchStats(),
  name: 'communityStatsProvider',
);
