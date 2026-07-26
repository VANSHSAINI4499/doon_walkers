import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/profile/domain/entities/points_ledger_entry.dart';
import 'package:doon_walkers/features/profile/domain/entities/points_summary.dart';
import 'package:doon_walkers/features/profile/domain/repositories/points_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Riverpod provider exposing the implementation of [PointsRepository].
final pointsRepositoryProvider = Provider<PointsRepository>(
  (ref) => PointsRepositoryImpl(ref.watch(supabaseClientProvider)),
  name: 'pointsRepositoryProvider',
);

/// Supabase implementation of [PointsRepository].
class PointsRepositoryImpl implements PointsRepository {
  final SupabaseClient _supabase;

  const PointsRepositoryImpl(this._supabase);

  @override
  Future<PointsSummary> fetchMySummary() async {
    if (_supabase.auth.currentUser == null) return PointsSummary.guest;

    final result = await _supabase.rpc(AppConstants.rpcGetMyPointsSummary);
    // The RPC returns TABLE(...), so PostgREST hands back a one-row list.
    final rows = result as List;
    if (rows.isEmpty) return PointsSummary.guest;
    return PointsSummary.fromRow(rows.first as Map<String, dynamic>);
  }

  @override
  Future<List<PointsLedgerEntry>> fetchMyHistoryPage({
    required int page,
    required int pageSize,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const [];

    final from = page * pageSize;
    final to = from + pageSize - 1;
    final rows = await _supabase
        .from(AppConstants.tablePointsLedger)
        .select('id, points, reason, reference_id, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(from, to);

    return (rows as List)
        .map((r) => PointsLedgerEntry.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}
