import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/activity/domain/entities/daily_activity.dart';
import 'package:doon_walkers/features/activity/domain/repositories/activity_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Riverpod provider exposing the implementation of [ActivityRepository].
final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => ActivityRepositoryImpl(ref.watch(supabaseClientProvider)),
  name: 'activityRepositoryProvider',
);

/// Supabase implementation of [ActivityRepository].
class ActivityRepositoryImpl implements ActivityRepository {
  final SupabaseClient _supabase;

  const ActivityRepositoryImpl(this._supabase);

  @override
  Future<void> upsertDailyActivity(List<DailyActivity> activity) async {
    if (activity.isEmpty) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('upsertDailyActivity called with no signed-in user');
    }

    await _supabase.from(AppConstants.tableDailyActivitySummary).upsert(
          activity
              .map((a) => {
                    'user_id': userId,
                    'date': _formatDate(a.date),
                    'steps': a.steps,
                    'distance_km': a.distanceKm,
                    'calories': a.calories,
                    'synced_at': DateTime.now().toIso8601String(),
                  })
              .toList(),
          onConflict: 'user_id,date',
        );
  }

  @override
  Future<DateTime?> fetchLastSyncedAt() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _supabase
        .from(AppConstants.tableDailyActivitySummary)
        .select('synced_at')
        .eq('user_id', userId)
        .order('synced_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) return null;
    return DateTime.parse(row['synced_at'] as String);
  }

  @override
  Future<List<DailyActivity>> fetchDailyActivitySince(DateTime from) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const [];

    final rows = await _supabase
        .from(AppConstants.tableDailyActivitySummary)
        .select('date, steps, distance_km, calories')
        .eq('user_id', userId)
        .gte('date', _formatDate(from))
        .order('date');

    return (rows as List).map(_rowToActivity).toList();
  }

  @override
  Future<List<DailyActivity>> fetchDailyActivityRange({
    required DateTime from,
    required DateTime to,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const [];

    final rows = await _supabase
        .from(AppConstants.tableDailyActivitySummary)
        .select('date, steps, distance_km, calories')
        .eq('user_id', userId)
        .gte('date', _formatDate(from))
        // `lte`, not `lt`: ActivityPeriod's range is inclusive at both
        // ends, so a `lt` here would silently drop the last day of every
        // week and month.
        .lte('date', _formatDate(to))
        .order('date');

    return (rows as List).map(_rowToActivity).toList();
  }

  @override
  Future<int?> fetchActivityPercentile(DateTime month) async {
    if (_supabase.auth.currentUser == null) return null;

    final result = await _supabase.rpc(
      AppConstants.rpcGetMyActivityPercentile,
      // The RPC truncates to the month itself; passing the 1st keeps the
      // cache key stable regardless of which day the caller was on.
      params: {'p_month': _formatDate(DateTime(month.year, month.month))},
    );

    // NULL is a real, expected answer ("cannot say") — not an error, and
    // deliberately not coerced to 0.
    return (result as num?)?.toInt();
  }

  static DailyActivity _rowToActivity(Object? row) {
    final map = row! as Map<String, dynamic>;
    return DailyActivity(
      date: DateTime.parse(map['date'] as String),
      steps: (map['steps'] as num?)?.toInt() ?? 0,
      distanceKm: _toDouble(map['distance_km']),
      calories: _toDouble(map['calories']),
    );
  }

  static double _toDouble(Object? value) => switch (value) {
    final num n => n.toDouble(),
    final String s => double.tryParse(s) ?? 0,
    _ => 0,
  };

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
