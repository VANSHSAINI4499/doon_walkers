import 'package:doon_walkers/features/profile/domain/entities/points_ledger_entry.dart';
import 'package:doon_walkers/features/profile/domain/entities/points_summary.dart';

/// Read access to the signed-in user's points/level standing and ledger
/// history — Phase 22.
abstract class PointsRepository {
  /// Total points, level, and points-to-next-level, via
  /// `get_my_points_summary()`. Returns [PointsSummary.guest] when there
  /// is no signed-in user.
  Future<PointsSummary> fetchMySummary();

  /// One page of the caller's own `points_ledger` rows, newest first.
  Future<List<PointsLedgerEntry>> fetchMyHistoryPage({
    required int page,
    required int pageSize,
  });
}
