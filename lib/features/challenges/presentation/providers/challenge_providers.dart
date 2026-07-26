import 'dart:async';

import 'package:doon_walkers/core/providers/shared_preferences_provider.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/activity/data/repositories/activity_repository_impl.dart';
import 'package:doon_walkers/features/challenges/data/repositories/challenge_repository_impl.dart';
import 'package:doon_walkers/features/challenges/data/services/challenge_celebration_tracker.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_enrollment.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_progress.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_tier_achievement.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_top_participant.dart';
import 'package:doon_walkers/features/challenges/domain/entities/leaderboard_entry.dart';
import 'package:doon_walkers/features/challenges/domain/services/activity_streak.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// All challenges (active + draft) — admin management list only.
final adminAllChallengesProvider = FutureProvider<List<Challenge>>(
  (ref) => ref.watch(challengeRepositoryProvider).fetchAllChallenges(),
  name: 'adminAllChallengesProvider',
);

/// Active challenges only — feeds the public Challenges tab.
final activeChallengesProvider = FutureProvider<List<Challenge>>(
  (ref) => ref.watch(challengeRepositoryProvider).fetchActiveChallenges(),
  name: 'activeChallengesProvider',
);

/// A single challenge by id, for the admin edit form and detail screen.
final challengeByIdProvider = FutureProvider.autoDispose.family<Challenge?, String>(
  (ref, id) => ref.watch(challengeRepositoryProvider).fetchChallengeById(id),
  name: 'challengeByIdProvider',
);

/// The signed-in user's own progress across every active challenge.
final myChallengeProgressProvider = FutureProvider<List<ChallengeProgress>>(
  (ref) => ref.watch(challengeRepositoryProvider).fetchMyProgress(),
  name: 'myChallengeProgressProvider',
);

/// The signed-in user's full tier-achievement history.
final myTierHistoryProvider = FutureProvider<List<ChallengeTierAchievement>>(
  (ref) => ref.watch(challengeRepositoryProvider).fetchMyTierHistory(),
  name: 'myTierHistoryProvider',
);

/// The signed-in user's current activity streak in consecutive days.
final myActivityStreakProvider = FutureProvider<int>((ref) async {
  final from = DateTime.now().subtract(const Duration(days: 400));
  final rows = await ref
      .watch(activityRepositoryProvider)
      .fetchDailyActivitySince(from);
  return computeActiveStreak(
    rows.map((r) => ActiveDay(date: r.date, steps: r.steps)).toList(),
  );
}, name: 'myActivityStreakProvider');

final challengeCelebrationTrackerProvider = Provider<ChallengeCelebrationTracker>(
  (ref) => ChallengeCelebrationTracker(ref.watch(sharedPreferencesProvider)),
  name: 'challengeCelebrationTrackerProvider',
);

/// One challenge's leaderboard. `autoDispose` since the leaderboard
/// screen is visited transiently.
final challengeLeaderboardProvider = FutureProvider.autoDispose.family<List<LeaderboardEntry>, String>(
  (ref, challengeId) => ref.watch(challengeRepositoryProvider).fetchLeaderboard(challengeId),
  name: 'challengeLeaderboardProvider',
);

// ── Phase 21: Enrollment providers ───────────────────────────────────────

/// All of the signed-in user's current enrollments. Empty for a guest.
final myEnrollmentsProvider = FutureProvider<List<ChallengeEnrollment>>(
  (ref) => ref.watch(challengeRepositoryProvider).fetchMyEnrollments(),
  name: 'myEnrollmentsProvider',
);

/// Whether the signed-in user is enrolled in a specific challenge.
final challengeEnrollmentStatusProvider =
    FutureProvider.autoDispose.family<bool, String>(
  (ref, challengeId) =>
      ref.watch(challengeRepositoryProvider).isEnrolled(challengeId),
  name: 'challengeEnrollmentStatusProvider',
);

/// Participant count for a challenge. autoDispose — detail screen only.
final challengeParticipantCountProvider =
    FutureProvider.autoDispose.family<int, String>(
  (ref, challengeId) =>
      ref.watch(challengeRepositoryProvider).fetchParticipantCount(challengeId),
  name: 'challengeParticipantCountProvider',
);

/// Top participants for a challenge. autoDispose — detail screen only.
final challengeTopParticipantsProvider =
    FutureProvider.autoDispose.family<List<ChallengeTopParticipant>, String>(
  (ref, challengeId) =>
      ref.watch(challengeRepositoryProvider).fetchTopParticipants(challengeId),
  name: 'challengeTopParticipantsProvider',
);

/// Upcoming challenges (start_date > today, up to 3).
final upcomingChallengesProvider = FutureProvider<List<Challenge>>(
  (ref) => ref.watch(challengeRepositoryProvider).fetchUpcomingChallenges(),
  name: 'upcomingChallengesProvider',
);

/// Popular challenges ordered by enrollment count descending.
final popularChallengesProvider = FutureProvider<List<Challenge>>(
  (ref) => ref.watch(challengeRepositoryProvider).fetchPopularChallenges(),
  name: 'popularChallengesProvider',
);

/// The signed-in user's total_points and level from user_points table.
/// Returns (0, 1) for a guest or when no points row exists yet.
final myUserPointsProvider = FutureProvider<({int totalPoints, int level})>(
  (ref) async {
    final uid = ref.watch(supabaseClientProvider).auth.currentUser?.id;
    if (uid == null) return (totalPoints: 0, level: 1);
    final row = await ref
        .watch(supabaseClientProvider)
        .from('user_points')
        .select('total_points, level')
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) return (totalPoints: 0, level: 1);
    return (
      totalPoints: (row['total_points'] as num?)?.toInt() ?? 0,
      level: (row['level'] as num?)?.toInt() ?? 1,
    );
  },
  name: 'myUserPointsProvider',
);

// ── Phase 21: Admin controller ────────────────────────────────────────────

/// AsyncNotifier managing admin challenge mutations.
final challengeAdminControllerProvider = AsyncNotifierProvider<ChallengeAdminController, void>(
  ChallengeAdminController.new,
  name: 'challengeAdminControllerProvider',
);

class ChallengeAdminController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<Challenge?> createChallenge({
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
    state = const AsyncLoading();
    Challenge? created;
    state = await AsyncValue.guard(() async {
      created = await ref.read(challengeRepositoryProvider).createChallenge(
            title: title,
            description: description,
            metric: metric,
            timeWindow: timeWindow,
            startDate: startDate,
            endDate: endDate,
            icon: icon,
            tierThresholds: tierThresholds,
            pointValue: pointValue,
          );
    });
    if (created != null) ref.invalidate(adminAllChallengesProvider);
    return created;
  }

  Future<bool> updateChallenge({
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
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await ref.read(challengeRepositoryProvider).updateChallenge(
            id: id,
            title: title,
            description: description,
            metric: metric,
            timeWindow: timeWindow,
            startDate: startDate,
            endDate: endDate,
            icon: icon,
            tierThresholds: tierThresholds,
            pointValue: pointValue,
          );
      success = true;
    });
    if (success) {
      ref.invalidate(adminAllChallengesProvider);
      ref.invalidate(challengeByIdProvider(id));
    }
    return success;
  }

  Future<bool> deleteChallenge(String id) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await ref.read(challengeRepositoryProvider).deleteChallenge(id);
      success = true;
    });
    if (success) ref.invalidate(adminAllChallengesProvider);
    return success;
  }

  Future<bool> setActive(String id, bool isActive) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await ref.read(challengeRepositoryProvider).setActive(id, isActive);
      success = true;
    });
    if (success) {
      ref.invalidate(adminAllChallengesProvider);
      ref.invalidate(challengeByIdProvider(id));
    }
    return success;
  }
}

// ── Phase 21: Enrollment controller ──────────────────────────────────────

/// AsyncNotifier managing user enrollment mutations (enroll/unenroll).
/// Invalidates enrollment status and my-enrollments on success.
final enrollmentControllerProvider =
    AsyncNotifierProvider<EnrollmentController, void>(
  EnrollmentController.new,
  name: 'enrollmentControllerProvider',
);

class EnrollmentController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> enroll(String challengeId) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await ref.read(challengeRepositoryProvider).enrollInChallenge(challengeId);
      success = true;
    });
    if (success) {
      ref.invalidate(myEnrollmentsProvider);
      ref.invalidate(challengeEnrollmentStatusProvider(challengeId));
      ref.invalidate(challengeParticipantCountProvider(challengeId));
      ref.invalidate(myUserPointsProvider);
    }
    return success;
  }

  Future<bool> unenroll(String challengeId) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await ref.read(challengeRepositoryProvider).unenrollFromChallenge(challengeId);
      success = true;
    });
    if (success) {
      ref.invalidate(myEnrollmentsProvider);
      ref.invalidate(challengeEnrollmentStatusProvider(challengeId));
      ref.invalidate(challengeParticipantCountProvider(challengeId));
    }
    return success;
  }
}
