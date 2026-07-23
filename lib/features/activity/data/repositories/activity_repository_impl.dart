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

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
