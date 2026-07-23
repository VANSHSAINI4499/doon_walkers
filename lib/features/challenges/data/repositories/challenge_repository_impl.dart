import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/challenges/data/models/challenge_model.dart';
import 'package:doon_walkers/features/challenges/data/models/challenge_progress_model.dart';
import 'package:doon_walkers/features/challenges/data/models/challenge_tier_achievement_model.dart';
import 'package:doon_walkers/features/challenges/data/models/leaderboard_entry_model.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_progress.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_tier_achievement.dart';
import 'package:doon_walkers/features/challenges/domain/entities/leaderboard_entry.dart';
import 'package:doon_walkers/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Riverpod provider exposing the implementation of
/// [ChallengeRepository].
final challengeRepositoryProvider = Provider<ChallengeRepository>(
  (ref) => ChallengeRepositoryImpl(ref.watch(supabaseClientProvider)),
  name: 'challengeRepositoryProvider',
);

/// Nested-join shape shared by every full-challenge read — pulls a
/// challenge's tiers in the same round trip, same pattern as
/// ProductRepositoryImpl's `_fullProductSelect`.
const _fullChallengeSelect = '*, challenge_tiers(*)';

/// Supabase implementation of [ChallengeRepository].
class ChallengeRepositoryImpl implements ChallengeRepository {
  final SupabaseClient _supabase;

  const ChallengeRepositoryImpl(this._supabase);

  @override
  Future<List<Challenge>> fetchAllChallenges() async {
    final rows = await _supabase
        .from(AppConstants.tableChallenges)
        .select(_fullChallengeSelect)
        .order('created_at', ascending: false);
    return rows.map(ChallengeModel.fromJson).toList();
  }

  @override
  Future<List<Challenge>> fetchActiveChallenges() async {
    final rows = await _supabase
        .from(AppConstants.tableChallenges)
        .select(_fullChallengeSelect)
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return rows.map(ChallengeModel.fromJson).toList();
  }

  @override
  Future<Challenge?> fetchChallengeById(String id) async {
    final row = await _supabase
        .from(AppConstants.tableChallenges)
        .select(_fullChallengeSelect)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return ChallengeModel.fromJson(row);
  }

  @override
  Future<Challenge> createChallenge({
    required String title,
    required String description,
    required ChallengeMetric metric,
    required ChallengeTimeWindow timeWindow,
    DateTime? startDate,
    DateTime? endDate,
    String? icon,
    required Map<ChallengeTier, double> tierThresholds,
  }) async {
    final row = await _supabase
        .from(AppConstants.tableChallenges)
        .insert(_writablePayload(
          title: title,
          description: description,
          metric: metric,
          timeWindow: timeWindow,
          startDate: startDate,
          endDate: endDate,
          icon: icon,
        ))
        .select()
        .single();
    final challengeId = row['id'] as String;

    await _supabase.from(AppConstants.tableChallengeTiers).insert(
          tierThresholds.entries
              .map((e) => {
                    'challenge_id': challengeId,
                    'tier': e.key.toDbString(),
                    'threshold_value': e.value,
                  })
              .toList(),
        );

    // Re-fetch rather than trust the pre-tiers-insert row, so the
    // returned Challenge actually carries its tiers.
    return (await fetchChallengeById(challengeId))!;
  }

  @override
  Future<void> updateChallenge({
    required String id,
    required String title,
    required String description,
    required ChallengeMetric metric,
    required ChallengeTimeWindow timeWindow,
    DateTime? startDate,
    DateTime? endDate,
    String? icon,
    required Map<ChallengeTier, double> tierThresholds,
  }) async {
    await _supabase
        .from(AppConstants.tableChallenges)
        .update(_writablePayload(
          title: title,
          description: description,
          metric: metric,
          timeWindow: timeWindow,
          startDate: startDate,
          endDate: endDate,
          icon: icon,
        ))
        .eq('id', id);

    await _supabase.from(AppConstants.tableChallengeTiers).upsert(
          tierThresholds.entries
              .map((e) => {
                    'challenge_id': id,
                    'tier': e.key.toDbString(),
                    'threshold_value': e.value,
                  })
              .toList(),
          onConflict: 'challenge_id,tier',
        );
  }

  @override
  Future<void> deleteChallenge(String id) async {
    // challenge_tiers cascades automatically (ON DELETE CASCADE) —
    // unlike treks/products, a challenge owns no Storage objects, so
    // there's nothing else to clean up first.
    await _supabase.from(AppConstants.tableChallenges).delete().eq('id', id);
  }

  @override
  Future<void> setActive(String id, bool isActive) async {
    await _supabase
        .from(AppConstants.tableChallenges)
        .update({'is_active': isActive}).eq('id', id);
  }

  @override
  Future<List<ChallengeProgress>> fetchMyProgress() async {
    final rows = await _supabase.rpc(AppConstants.rpcGetMyChallengeProgress);
    return (rows as List)
        .map((row) => ChallengeProgressModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ChallengeTierAchievement>> fetchMyTierHistory() async {
    final rows = await _supabase.rpc(AppConstants.rpcGetMyChallengeTierHistory);
    return (rows as List)
        .map((row) => ChallengeTierAchievementModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<LeaderboardEntry>> fetchLeaderboard(String challengeId) async {
    final rows = await _supabase.rpc(
      AppConstants.rpcGetChallengeLeaderboard,
      params: {'p_challenge_id': challengeId},
    );
    return (rows as List)
        .map((row) => LeaderboardEntryModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Map<String, dynamic> _writablePayload({
    required String title,
    required String description,
    required ChallengeMetric metric,
    required ChallengeTimeWindow timeWindow,
    DateTime? startDate,
    DateTime? endDate,
    String? icon,
  }) {
    return {
      'title': title,
      'description': description,
      'metric': metric.toDbString(),
      'time_window': timeWindow.toDbString(),
      // Postgres `date` accepts a plain "YYYY-MM-DD" string — same
      // pattern as TrekRepositoryImpl's trek_date handling.
      'start_date': _formatDate(startDate),
      'end_date': _formatDate(endDate),
      'icon': icon,
    };
  }

  String? _formatDate(DateTime? date) {
    if (date == null) return null;
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
