import 'package:doon_walkers/features/profile/data/repositories/points_repository_impl.dart';
import 'package:doon_walkers/features/profile/domain/entities/points_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The signed-in user's points/level summary — Phase 22. Backs Profile's
/// points summary card and its progress-to-next-level bar.
final myPointsSummaryProvider = FutureProvider<PointsSummary>(
  (ref) => ref.watch(pointsRepositoryProvider).fetchMySummary(),
  name: 'myPointsSummaryProvider',
);
