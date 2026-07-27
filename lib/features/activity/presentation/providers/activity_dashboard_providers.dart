import 'dart:async';

import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/activity/data/repositories/activity_repository_impl.dart';
import 'package:doon_walkers/features/activity/domain/entities/daily_activity.dart';
import 'package:doon_walkers/features/activity/domain/entities/user_achievement.dart';
import 'package:doon_walkers/features/activity/domain/services/activity_period.dart';
import 'package:doon_walkers/features/activity/domain/services/activity_summary.dart';
import 'package:doon_walkers/features/auth/domain/entities/user_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Providers for the Activity dashboard (Redesign 2.0, Phase 11).
///
/// Separate file from `activity_providers.dart`, which owns the *sync*
/// side (provider availability, permissions, the sync controller). This
/// one owns *reading* what was synced. Keeping them apart means the
/// dashboard's family providers don't get invalidated by sync plumbing
/// they don't depend on, and vice versa.

/// The user's daily step goal, or the column default while the row is
/// still loading.
///
/// Comes off `currentUserProvider`, which is already watched app-wide, so
/// this costs no extra query — the whole reason the goal is a column on
/// `users` rather than its own table.
final dailyStepGoalProvider = Provider<int>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  return user?.dailyStepGoal ?? UserEntity.defaultDailyStepGoal;
}, name: 'dailyStepGoalProvider');

/// The raw rows for one period, straight from `daily_activity_summary`.
///
/// Keyed by the period itself. `autoDispose` because a user paging back
/// through months would otherwise accumulate a cache entry per month for
/// the session; the data is small and re-fetching is cheap.
final activityRangeProvider = FutureProvider.autoDispose
    .family<List<DailyActivity>, ActivityPeriod>((ref, period) {
      return ref
          .watch(activityRepositoryProvider)
          .fetchDailyActivityRange(from: period.from, to: period.to);
    }, name: 'activityRangeProvider');

/// The aggregated summary for one period.
final activitySummaryProvider = FutureProvider.autoDispose
    .family<ActivitySummary, ActivityPeriod>((ref, period) async {
      final rows = await ref.watch(activityRangeProvider(period).future);
      return ActivitySummary.from(period, rows);
    }, name: 'activitySummaryProvider');

/// The trailing 7 days ending on [ActivityPeriod.to] — the Day view's
/// context chart.
///
/// A *rolling* window, deliberately not the calendar week: the Day view is
/// answering "how does today compare with recent days", and a Monday would
/// otherwise show a chart of one bar.
final trailingWeekProvider = FutureProvider.autoDispose
    .family<List<DailyActivity>, DateTime>((ref, endDate) {
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      final start = end.subtract(const Duration(days: 6));
      return ref
          .watch(activityRepositoryProvider)
          .fetchDailyActivityRange(from: start, to: end);
    }, name: 'trailingWeekProvider');

/// The caller's percentile among tracking members for a month, or null
/// when it cannot be said.
///
/// See `get_my_activity_percentile()` (0035) — null means either fewer
/// than 5 members tracked that month, or the caller has no data for it.
/// **Both render as nothing**, never as 0%.
final activityPercentileProvider = FutureProvider.autoDispose
    .family<int?, DateTime>((ref, month) {
      return ref
          .watch(activityRepositoryProvider)
          .fetchActivityPercentile(month);
    }, name: 'activityPercentileProvider');

/// Daily percentile provider.
final dailyPercentileProvider = FutureProvider.autoDispose
    .family<int?, DateTime>((ref, date) {
      return ref
          .watch(activityRepositoryProvider)
          .fetchDailyPercentile(date);
    }, name: 'dailyPercentileProvider');

/// Best day provider for a given month.
final bestDayProvider = FutureProvider.autoDispose
    .family<DailyActivity?, DateTime>((ref, month) {
      return ref
          .watch(activityRepositoryProvider)
          .fetchBestDay(year: month.year, month: month.month);
    }, name: 'bestDayProvider');

/// Active days count for a given month.
final activeDaysProvider = FutureProvider.autoDispose
    .family<int, DateTime>((ref, month) {
      return ref
          .watch(activityRepositoryProvider)
          .fetchActiveDays(year: month.year, month: month.month);
    }, name: 'activeDaysProvider');

/// Weekly aggregates provider for a given month.
final weeklyAggregatesProvider = FutureProvider.autoDispose
    .family<List<DailyActivity>, DateTime>((ref, month) {
      return ref
          .watch(activityRepositoryProvider)
          .fetchWeeklyAggregates(year: month.year, month: month.month);
    }, name: 'weeklyAggregatesProvider');

/// Month-over-month comparison metrics provider.
final monthComparisonProvider = FutureProvider.autoDispose
    .family<Map<String, double>, DateTime>((ref, month) {
      return ref
          .watch(activityRepositoryProvider)
          .fetchMonthComparison(year: month.year, month: month.month);
    }, name: 'monthComparisonProvider');

/// Unlocked achievements provider.
final userAchievementsProvider = FutureProvider.autoDispose<List<UserAchievement>>((ref) {
  return ref.watch(activityRepositoryProvider).fetchUserAchievements();
}, name: 'userAchievementsProvider');

/// Unlocked achievements via RPC (supporting milestones & platinums)
final myAchievementsProvider = FutureProvider.autoDispose.family<List<UserAchievement>, ({int limit, int offset})>((ref, args) {
  return ref.watch(activityRepositoryProvider).fetchMyAchievements(
        limit: args.limit,
        offset: args.offset,
      );
}, name: 'myAchievementsProvider');


/// User goal provider via Phase 19 RPC.
final userGoalProvider = FutureProvider.autoDispose
    .family<dynamic, String>((ref, goalType) {
      return ref
          .watch(activityRepositoryProvider)
          .getOrCreateUserGoal(goalType);
    }, name: 'userGoalProvider');

/// Writes the user's daily step goal.
///
/// Goes straight to `public.users` through the existing
/// `users_update_own_or_admin` policy — no RPC, no new policy. Mirrors
/// LeaderboardVisibilityController's shape: an AsyncNotifier so the UI can
/// show a pending state and surface a failure.
final stepGoalControllerProvider =
    AsyncNotifierProvider<StepGoalController, void>(
      StepGoalController.new,
      name: 'stepGoalControllerProvider',
    );

class StepGoalController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Clamps to the same 500–100,000 band as the DB CHECK constraint
  /// (0034), so an out-of-range value fails fast client-side with a
  /// sensible number rather than as a Postgres constraint violation.
  static int clampGoal(int goal) => goal.clamp(500, 100000);

  Future<bool> setGoal(int goal) async {
    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return false;

    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await client
          .from(AppConstants.tableUsers)
          .update({'daily_step_goal': clampGoal(goal)})
          .eq('id', userId);
      success = true;
    });

    if (success) {
      ref.invalidate(currentUserProvider);
    }
    return success;
  }
}
