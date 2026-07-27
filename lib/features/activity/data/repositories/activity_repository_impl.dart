import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/activity/domain/entities/daily_activity.dart';
import 'package:doon_walkers/features/activity/domain/entities/user_achievement.dart';
import 'package:doon_walkers/features/activity/domain/repositories/activity_repository.dart';
import 'package:flutter/foundation.dart';
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
                    'active_minutes': a.activeMinutes,
                    'synced_at': DateTime.now().toIso8601String(),
                  })
              .toList(),
          onConflict: 'user_id,date',
        );

    // Phase 21: Award 25 points when today's step count meets or
    // exceeds the user's daily goal — once per calendar day, guarded
    // by checking points_ledger for an existing entry today. This is
    // fire-and-forget: a failure here should never block the sync.
    _maybeAwardDailyStepGoalPoints(userId, activity);
  }

  /// Awards `daily_step_goal` points if today's data in [activity] meets
  /// the user's daily step goal AND no award has been given today yet.
  /// Fire-and-forget — called without await.
  void _maybeAwardDailyStepGoalPoints(
    String userId,
    List<DailyActivity> activity,
  ) {
    // Find today's activity in the synced batch.
    final today = DateTime.now();
    final todayStr = _formatDate(today);
    final todayEntry = activity.where(
      (a) => _formatDate(a.date) == todayStr,
    );
    if (todayEntry.isEmpty) return;
    final todaySteps = todayEntry.first.steps;
    if (todaySteps <= 0) return;

    // Async check-and-award: do not await, do not propagate errors.
    () async {
      try {
        // Fetch user's daily step goal.
        final goalRow = await _supabase.rpc(
          'get_or_create_user_goal',
          params: {'p_user_id': userId, 'p_goal_type': 'daily_steps'},
        );
        final goalTarget = (goalRow as Map<String, dynamic>?)?['target_value'] as int? ?? 6500;
        if (todaySteps < goalTarget) return;

        // Check for existing ledger entry today (once-per-day guard).
        final existingRows = await _supabase
            .from('points_ledger')
            .select('id')
            .eq('user_id', userId)
            .eq('reason', 'daily_step_goal')
            .gte('created_at', '${todayStr}T00:00:00Z')
            .lt('created_at', '${_formatDate(today.add(const Duration(days: 1)))}T00:00:00Z')
            .limit(1);
        if ((existingRows as List).isNotEmpty) return;

        // Award 25 points.
        await _supabase.rpc('award_points', params: {
          'p_user_id': userId,
          'p_points': 25,
          'p_reason': 'daily_step_goal',
          'p_reference_id': null,
        });
        debugPrint('ActivityRepository: awarded daily_step_goal points for $userId');
      } catch (e) {
        debugPrint('ActivityRepository: daily_step_goal award failed (non-fatal): $e');
      }
    }();
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
        .select('date, steps, distance_km, calories, active_minutes')
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
        .select('date, steps, distance_km, calories, active_minutes')
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

  @override
  Future<int?> fetchDailyPercentile(DateTime date) async {
    if (_supabase.auth.currentUser == null) return null;

    final result = await _supabase.rpc(
      AppConstants.rpcGetDailyActivityPercentile,
      params: {'p_date': _formatDate(date)},
    );

    return (result as num?)?.toInt();
  }

  @override
  Future<DailyActivity?> fetchBestDay({
    required int year,
    required int month,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final start = _formatDate(DateTime(year, month, 1));
    final lastDay = DateTime(year, month + 1, 0).day;
    final end = _formatDate(DateTime(year, month, lastDay));

    final rows = await _supabase
        .from(AppConstants.tableDailyActivitySummary)
        .select('date, steps, distance_km, calories, active_minutes')
        .eq('user_id', userId)
        .gte('date', start)
        .lte('date', end)
        .order('steps', ascending: false)
        .limit(1);

    final list = rows as List;
    if (list.isEmpty) return null;
    return _rowToActivity(list.first);
  }

  @override
  Future<int> fetchActiveDays({
    required int year,
    required int month,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    final start = _formatDate(DateTime(year, month, 1));
    final lastDay = DateTime(year, month + 1, 0).day;
    final end = _formatDate(DateTime(year, month, lastDay));

    final rows = await _supabase
        .from(AppConstants.tableDailyActivitySummary)
        .select('date')
        .eq('user_id', userId)
        .gte('date', start)
        .lte('date', end)
        .gt('steps', 0);

    return (rows as List).length;
  }

  @override
  Future<List<DailyActivity>> fetchWeeklyAggregates({
    required int year,
    required int month,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const [];

    final start = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0).day;
    final end = DateTime(year, month, lastDay);

    final rows = await fetchDailyActivityRange(from: start, to: end);

    // Group into 7-day buckets
    final weekly = <DailyActivity>[];
    for (var w = 0; w < 5; w++) {
      final wStart = start.add(Duration(days: w * 7));
      if (wStart.isAfter(end)) break;
      var wEnd = wStart.add(const Duration(days: 6));
      if (wEnd.isAfter(end)) wEnd = end;

      final bucketRows = rows.where(
        (r) => !r.date.isBefore(wStart) && !r.date.isAfter(wEnd),
      );

      var steps = 0;
      var dist = 0.0;
      var cal = 0.0;
      var actMin = 0;

      for (final r in bucketRows) {
        steps += r.steps;
        dist += r.distanceKm;
        cal += r.calories;
        actMin += r.activeMinutes;
      }

      weekly.add(DailyActivity(
        date: wStart,
        steps: steps,
        distanceKm: dist,
        calories: cal,
        activeMinutes: actMin,
      ));
    }
    return weekly;
  }

  @override
  Future<Map<String, double>> fetchMonthComparison({
    required int year,
    required int month,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {};

    final currentStart = DateTime(year, month, 1);
    final currentEnd = DateTime(year, month + 1, 0);

    final priorStart = DateTime(year, month - 1, 1);
    final priorEnd = DateTime(year, month, 0);

    final currentRows = await fetchDailyActivityRange(
      from: currentStart,
      to: currentEnd,
    );
    final priorRows = await fetchDailyActivityRange(
      from: priorStart,
      to: priorEnd,
    );

    double sum(List<DailyActivity> list, double Function(DailyActivity a) fn) =>
        list.fold(0.0, (prev, elem) => prev + fn(elem));

    return {
      'current_steps': sum(currentRows, (a) => a.steps.toDouble()),
      'prior_steps': sum(priorRows, (a) => a.steps.toDouble()),
      'current_dist': sum(currentRows, (a) => a.distanceKm),
      'prior_dist': sum(priorRows, (a) => a.distanceKm),
      'current_cal': sum(currentRows, (a) => a.calories),
      'prior_cal': sum(priorRows, (a) => a.calories),
      'current_active': sum(currentRows, (a) => a.activeMinutes.toDouble()),
      'prior_active': sum(priorRows, (a) => a.activeMinutes.toDouble()),
    };
  }

  @override
  Future<List<UserAchievement>> fetchUserAchievements() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const [];

    final rows = await _supabase
        .from('user_achievements')
        .select('*, achievement_definitions(*)')
        .eq('user_id', userId);

    return (rows as List)
        .map((row) => UserAchievement.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<UserAchievement>> fetchMyAchievements({
    int limit = 20,
    int offset = 0,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const [];

    final result = await _supabase.rpc(
      'get_my_achievements',
      params: {
        'p_limit': limit,
        'p_offset': offset,
      },
    );

    return (result as List)
        .map((row) => UserAchievement.fromJson(row as Map<String, dynamic>))
        .toList();
  }


  @override
  Future<dynamic> getOrCreateUserGoal(String goalType) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final result = await _supabase.rpc(
      'get_or_create_user_goal',
      params: {
        'p_user_id': userId,
        'p_goal_type': goalType,
      },
    );

    return result;
  }

  static DailyActivity _rowToActivity(Object? row) {
    final map = row! as Map<String, dynamic>;
    return DailyActivity(
      date: DateTime.parse(map['date'] as String),
      steps: (map['steps'] as num?)?.toInt() ?? 0,
      distanceKm: _toDouble(map['distance_km']),
      calories: _toDouble(map['calories']),
      activeMinutes: (map['active_minutes'] as num?)?.toInt() ?? 0,
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
