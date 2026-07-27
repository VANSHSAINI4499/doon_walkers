import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/challenges/data/models/challenge_enrollment_model.dart';
import 'package:doon_walkers/features/challenges/data/models/challenge_model.dart';
import 'package:doon_walkers/features/challenges/data/models/challenge_progress_model.dart';
import 'package:doon_walkers/features/challenges/data/models/challenge_tier_achievement_model.dart';
import 'package:doon_walkers/features/challenges/data/models/challenge_top_participant_model.dart';
import 'package:doon_walkers/features/challenges/data/models/leaderboard_entry_model.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_enrollment.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_progress.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_tier_achievement.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_top_participant.dart';
import 'package:doon_walkers/features/challenges/domain/entities/leaderboard_entry.dart';
import 'package:doon_walkers/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:doon_walkers/features/challenges/domain/services/challenge_completion_award.dart';
import 'package:flutter/foundation.dart';
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

  // ── Convenience helpers ───────────────────────────────────────────

  /// Returns the current user's id, or null if not signed in.
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  // ── Read methods ──────────────────────────────────────────────────

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
    final row =
        await _supabase
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
    int pointValue = 50,
  }) async {
    final row =
        await _supabase
            .from(AppConstants.tableChallenges)
            .insert(
              _writablePayload(
                title: title,
                description: description,
                metric: metric,
                timeWindow: timeWindow,
                startDate: startDate,
                endDate: endDate,
                icon: icon,
                pointValue: pointValue,
              ),
            )
            .select()
            .single();
    final challengeId = row['id'] as String;

    await _supabase
        .from(AppConstants.tableChallengeTiers)
        .insert(
          tierThresholds.entries
              .map(
                (e) => {
                  'challenge_id': challengeId,
                  'tier': e.key.toDbString(),
                  'threshold_value': e.value,
                },
              )
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
    int pointValue = 50,
  }) async {
    await _supabase
        .from(AppConstants.tableChallenges)
        .update(
          _writablePayload(
            title: title,
            description: description,
            metric: metric,
            timeWindow: timeWindow,
            startDate: startDate,
            endDate: endDate,
            icon: icon,
            pointValue: pointValue,
          ),
        )
        .eq('id', id);

    await _supabase
        .from(AppConstants.tableChallengeTiers)
        .upsert(
          tierThresholds.entries
              .map(
                (e) => {
                  'challenge_id': id,
                  'tier': e.key.toDbString(),
                  'threshold_value': e.value,
                },
              )
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
        .update({'is_active': isActive})
        .eq('id', id);
  }

  @override
  Future<List<ChallengeProgress>> fetchMyProgress() async {
    final rows = await _supabase.rpc(AppConstants.rpcGetMyChallengeProgress);
    return (rows as List)
        .map(
          (row) => ChallengeProgressModel.fromJson(row as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<List<ChallengeTierAchievement>> fetchMyTierHistory() async {
    final rows = await _supabase.rpc(AppConstants.rpcGetMyChallengeTierHistory);
    return (rows as List)
        .map(
          (row) => ChallengeTierAchievementModel.fromJson(
            row as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  @override
  Future<List<LeaderboardEntry>> fetchLeaderboard(String challengeId) async {
    final rows = await _supabase.rpc(
      AppConstants.rpcGetChallengeLeaderboard,
      params: {'p_challenge_id': challengeId},
    );
    return (rows as List)
        .map(
          (row) => LeaderboardEntryModel.fromJson(row as Map<String, dynamic>),
        )
        .toList();
  }

  // ── Phase 21: Enrollment methods ─────────────────────────────────

  @override
  Future<ChallengeEnrollment> enrollInChallenge(String challengeId) async {
    final row = await _supabase.rpc(
      AppConstants.rpcEnrollInChallenge,
      params: {'p_challenge_id': challengeId},
    );
    // The RPC returns a single composite row, not a list — PostgREST
    // surfaces RETURNS record as a single JSON object.
    final json = (row as Map<String, dynamic>);
    return ChallengeEnrollmentModel.fromJson(json);
  }

  @override
  Future<void> unenrollFromChallenge(String challengeId) async {
    await _supabase.rpc(
      AppConstants.rpcUnenrollFromChallenge,
      params: {'p_challenge_id': challengeId},
    );
  }

  @override
  Future<bool> isEnrolled(String challengeId) async {
    final uid = _currentUserId;
    if (uid == null) return false;
    final row =
        await _supabase
            .from(AppConstants.tableChallengeEnrollments)
            .select('id')
            .eq('challenge_id', challengeId)
            .eq('user_id', uid)
            .maybeSingle();
    return row != null;
  }

  @override
  Future<List<ChallengeEnrollment>> fetchMyEnrollments() async {
    final uid = _currentUserId;
    if (uid == null) return const [];
    final rows = await _supabase
        .from(AppConstants.tableChallengeEnrollments)
        .select()
        .eq('user_id', uid)
        .order('enrolled_at', ascending: false);
    return (rows as List)
        .map(
          (row) =>
              ChallengeEnrollmentModel.fromJson(row as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<int> fetchParticipantCount(String challengeId) async {
    final result = await _supabase.rpc(
      AppConstants.rpcGetChallengeParticipantCount,
      params: {'p_challenge_id': challengeId},
    );
    return (result as num?)?.toInt() ?? 0;
  }

  @override
  Future<List<ChallengeTopParticipant>> fetchTopParticipants(
    String challengeId, {
    int limit = 10,
  }) async {
    final rows = await _supabase.rpc(
      AppConstants.rpcGetChallengeTopParticipants,
      params: {'p_challenge_id': challengeId, 'p_limit': limit},
    );
    return (rows as List)
        .map(
          (row) => ChallengeTopParticipantModel.fromJson(
            row as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  @override
  Future<List<Challenge>> fetchUpcomingChallenges({int limit = 3}) async {
    final today = _formatDate(DateTime.now());
    final rows = await _supabase
        .from(AppConstants.tableChallenges)
        .select(_fullChallengeSelect)
        .eq('is_active', true)
        .gt('start_date', today)
        .order('start_date', ascending: true)
        .limit(limit);
    return rows.map(ChallengeModel.fromJson).toList();
  }

  @override
  Future<List<Challenge>> fetchPopularChallenges({int limit = 5}) async {
    // Order active challenges by their enrollment count descending.
    // PostgREST doesn't support subquery ordering directly, so we
    // fetch with a count join and sort client-side — fine at this scale.
    final rows = await _supabase
        .from(AppConstants.tableChallenges)
        .select('$_fullChallengeSelect, challenge_enrollments(count)')
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(50); // fetch more than needed, then re-sort by count

    // Sort by enrollment count descending
    final list = rows.toList();
    list.sort((a, b) {
      final aCount = ((a['challenge_enrollments'] as List?)?.length ?? 0);
      final bCount = ((b['challenge_enrollments'] as List?)?.length ?? 0);
      return bCount.compareTo(aCount);
    });

    return list.take(limit).map(ChallengeModel.fromJson).toList();
  }

  @override
  Future<void> maybeAwardChallengeCompletedPoints({
    required String userId,
    required List<Challenge> challenges,
    required List<ChallengeProgress> progressList,
    required Set<String> enrolledChallengeIds,
  }) {
    return triggerChallengeCompletedPointsAward(
      userId: userId,
      challenges: challenges,
      progressList: progressList,
      enrolledChallengeIds: enrolledChallengeIds,
      gateway: _SupabaseChallengeCompletionAwardGateway(_supabase),
    );
  }

  // ── Private helpers ───────────────────────────────────────────────

  Map<String, dynamic> _writablePayload({
    required String title,
    required String description,
    required ChallengeMetric metric,
    required ChallengeTimeWindow timeWindow,
    DateTime? startDate,
    DateTime? endDate,
    String? icon,
    int pointValue = 50,
  }) {
    return {
      'title': title,
      'description': description,
      'metric': metric.toDbString(),
      'time_window': timeWindow.toDbString(),
      // Postgres `date` accepts a plain "YYYY-MM-DD" string — same
      // pattern as TrekRepositoryImpl's trek_date handling.
      'start_date': _formatDateNullable(startDate),
      'end_date': _formatDateNullable(endDate),
      'icon': icon,
      'point_value': pointValue,
    };
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String? _formatDateNullable(DateTime? date) {
    if (date == null) return null;
    return _formatDate(date);
  }
}

/// Real (Supabase-backed) implementation of
/// [ChallengeCompletionAwardGateway] — the points_ledger check and
/// award_points RPC call that used to live directly in
/// `_ChallengesScreenState._maybeTriggerChallengeCompletedPoints`
/// before Phase 24 extracted it here for direct test coverage of
/// `triggerChallengeCompletedPointsAward`.
class _SupabaseChallengeCompletionAwardGateway
    implements ChallengeCompletionAwardGateway {
  const _SupabaseChallengeCompletionAwardGateway(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<bool> hasAwardedChallengeCompleted(
    String userId,
    String challengeId,
  ) async {
    final existing = await _supabase
        .from('points_ledger')
        .select('id')
        .eq('user_id', userId)
        .eq('reason', 'challenge_completed')
        .eq('reference_id', challengeId)
        .limit(1);
    return (existing as List).isNotEmpty;
  }

  @override
  Future<void> awardChallengeCompleted(
    String userId,
    String challengeId,
    int points,
  ) async {
    try {
      await _supabase.rpc(
        'award_points',
        params: {
          'p_user_id': userId,
          'p_points': points,
          'p_reason': 'challenge_completed',
          'p_reference_id': challengeId,
        },
      );
    } catch (e) {
      debugPrint(
        'ChallengeRepositoryImpl: challenge_completed award failed for '
        'user $userId on challenge $challengeId (non-fatal): $e',
      );
      rethrow;
    }
  }
}
