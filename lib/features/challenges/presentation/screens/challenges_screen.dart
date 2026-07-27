import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/activity/presentation/providers/activity_providers.dart';
import 'package:doon_walkers/features/activity/presentation/widgets/activity_permission_banner.dart';
import 'package:doon_walkers/features/challenges/data/repositories/challenge_repository_impl.dart';
import 'package:doon_walkers/features/challenges/data/services/challenge_celebration_tracker.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_enrollment.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_progress.dart';
import 'package:doon_walkers/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_admin_actions.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_card.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_icon.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/explore_challenges_view.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/level_badge.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/tier_celebration_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Which half of the Challenges tab is showing.
enum _ChallengesView { mine, explore }

/// Challenges — one shared screen for every role. Guests/members see
/// active challenges; an admin sees the same screen plus inline management
/// (drafts included and marked, a per-challenge actions menu, an "Add
/// Challenge" FAB).
///
/// Phase 21 upgrades My Challenges from a flat list into a dashboard:
/// My Progress banner (active enrollment count + streak + points),
/// Enrolled Active Challenges list, Upcoming Challenges section, and
/// a Challenge Leaderboard preview. The Explore tab is unchanged.
class ChallengesScreen extends ConsumerStatefulWidget {
  const ChallengesScreen({super.key});

  @override
  ConsumerState<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends ConsumerState<ChallengesScreen> {
  bool _celebrationQueueRunning = false;
  _ChallengesView _view = _ChallengesView.mine;

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final challengesProvider =
        isAdmin ? adminAllChallengesProvider : activeChallengesProvider;
    final challengesAsync = ref.watch(challengesProvider);
    final progressAsync = ref.watch(myChallengeProgressProvider);

    // Fires only on a real data change — see ChallengeCelebrationTracker
    // for why this keeps from re-celebrating on every screen visit.
    ref.listen<AsyncValue<List<ChallengeProgress>>>(
      myChallengeProgressProvider,
      (previous, next) {
        final progressList = next.valueOrNull;
        if (progressList == null) return;
        final challenges = ref.read(challengesProvider).valueOrNull;
        if (challenges == null) return;
        _detectAndCelebrate(challenges, progressList);
      },
    );

    // Phase 21: also listen for challenge_completed points opportunities.
    ref.listen<AsyncValue<List<ChallengeProgress>>>(
      myChallengeProgressProvider,
      (previous, next) {
        final progressList = next.valueOrNull;
        if (progressList == null) return;
        final challenges = ref.read(challengesProvider).valueOrNull;
        if (challenges == null) return;
        final enrollments = ref.read(myEnrollmentsProvider).valueOrNull;
        if (enrollments == null) return;
        _maybeTriggerChallengeCompletedPoints(
          challenges,
          progressList,
          enrollments,
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Challenges'),
        actions: [
          IconButton(
            icon: const AppIcon(AppIcons.medal),
            tooltip: 'My Achievements',
            onPressed: () => context.push(AppConstants.routeChallengeHistory),
          ),
        ],
      ),
      floatingActionButton:
          isAdmin
              ? FloatingActionButton.extended(
                onPressed:
                    () => context.push(AppConstants.routeAdminChallengesNew),
                icon: const AppIcon(AppIcons.add, size: 20),
                label: const Text('Add Challenge'),
              )
              : null,
      body: SafeArea(
        child: Column(
          children: [
            const ActivityPermissionBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: AppSegmentedControl<_ChallengesView>(
                value: _view,
                onChanged: (v) => setState(() => _view = v),
                segments: const [
                  (_ChallengesView.mine, 'My Challenges'),
                  (_ChallengesView.explore, 'Explore'),
                ],
              ),
            ),
            Expanded(
              child: switch (_view) {
                _ChallengesView.mine => _MyChallengesView(
                  challengesAsync: challengesAsync,
                  challengesProvider: challengesProvider,
                  progressAsync: progressAsync,
                  isAdmin: isAdmin,
                ),
                _ChallengesView.explore => const ExploreChallengesView(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _detectAndCelebrate(
    List<Challenge> challenges,
    List<ChallengeProgress> progressList,
  ) async {
    if (_celebrationQueueRunning) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final tracker = ref.read(challengeCelebrationTrackerProvider);
    final newlyAchieved = <(Challenge, ChallengeTier)>[];

    for (final progress in progressList) {
      Challenge? challenge;
      for (final c in challenges) {
        if (c.id == progress.challengeId) {
          challenge = c;
          break;
        }
      }
      if (challenge == null) continue;

      final hadBaseline = tracker.hasBaseline(userId, challenge.id);
      final previous = tracker.lastSeenTier(userId, challenge.id);
      if (isNewlyAchievedTier(
        hadBaseline: hadBaseline,
        previous: previous,
        current: progress.currentTier,
      )) {
        newlyAchieved.add((challenge, progress.currentTier!));
      }
      await tracker.markSeen(userId, challenge.id, progress.currentTier);
    }

    if (!mounted || newlyAchieved.isEmpty) return;

    _celebrationQueueRunning = true;
    for (final (challenge, tier) in newlyAchieved) {
      if (!mounted) break;
      await showTierCelebration(context, challenge: challenge, tier: tier);
    }
    _celebrationQueueRunning = false;
  }

  /// Phase 21/23/24: for any challenge the user is enrolled in where
  /// they have reached the top (platinum) tier, check the ledger and
  /// award challenge_completed points once if not yet awarded.
  /// Fire-and-forget.
  ///
  /// "Completed" is defined as `currentTier == platinum` — the tier
  /// engine has no separate 0–1 completion fraction (see
  /// [ChallengeProgress]'s doc: it only exposes `currentValue` and
  /// `currentTier`), so this reuses the existing tier data rather than
  /// inventing a new field on that entity.
  ///
  /// Phase 24 moved the actual ledger-check-and-award logic into
  /// [ChallengeRepository.maybeAwardChallengeCompletedPoints] /
  /// `triggerChallengeCompletedPointsAward` so it can be unit-tested
  /// with a fake gateway instead of a real Supabase client — this
  /// method is now just the trigger, unchanged in behavior.
  void _maybeTriggerChallengeCompletedPoints(
    List<Challenge> challenges,
    List<ChallengeProgress> progressList,
    List<ChallengeEnrollment> enrollments,
  ) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    ref
        .read(challengeRepositoryProvider)
        .maybeAwardChallengeCompletedPoints(
          userId: userId,
          challenges: challenges,
          progressList: progressList,
          enrolledChallengeIds: enrollments.map((e) => e.challengeId).toSet(),
        );
  }
}

/// The tracking half: My Progress banner + enrolled challenges + upcoming.
class _MyChallengesView extends ConsumerWidget {
  const _MyChallengesView({
    required this.challengesAsync,
    required this.challengesProvider,
    required this.progressAsync,
    required this.isAdmin,
  });

  final AsyncValue<List<Challenge>> challengesAsync;
  final FutureProvider<List<Challenge>> challengesProvider;
  final AsyncValue<List<ChallengeProgress>> progressAsync;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return challengesAsync.when(
      loading: () => const _ChallengeListSkeleton(),
      error: (error, stack) {
        debugPrint('ChallengesScreen: failed to load challenges: $error');
        return _ChallengesError(
          onRetry: () => ref.invalidate(challengesProvider),
        );
      },
      data: (challenges) {
        Future<void> onRefresh() {
          return ref.read(activitySyncControllerProvider.notifier).sync().then((
            _,
          ) {
            ref.invalidate(myChallengeProgressProvider);
            ref.invalidate(myActivityStreakProvider);
            ref.invalidate(myEnrollmentsProvider);
            ref.invalidate(myUserPointsProvider);
            return ref.refresh(challengesProvider.future);
          });
        }

        if (challenges.isEmpty) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [_EmptyChallenges(isAdmin: isAdmin)],
            ),
          );
        }

        final progressByChallenge = <String, ChallengeProgress>{
          for (final p
              in progressAsync.valueOrNull ?? const <ChallengeProgress>[])
            p.challengeId: p,
        };

        // Phase 21: build sections only for signed-in users.
        final isSignedIn = ref.watch(isSignedInProvider);
        final myEnrollmentsAsync = ref.watch(myEnrollmentsProvider);
        final enrolledIds =
            myEnrollmentsAsync.valueOrNull?.map((e) => e.challengeId).toSet() ??
            const <String>{};

        // Split enrolled active vs all
        final enrolledActiveChallenges =
            challenges
                .where((c) => c.isActive && enrolledIds.contains(c.id))
                .toList();

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              isAdmin ? 96 : AppSpacing.xxl,
            ),
            children: [
              // My Progress Banner — signed-in only
              if (isSignedIn)
                _MyProgressBanner(
                  enrolledCount: enrolledActiveChallenges.length,
                ),
              if (isSignedIn) const SizedBox(height: AppSpacing.xl),

              // Enrolled Active Challenges
              if (isSignedIn && enrolledActiveChallenges.isNotEmpty) ...[
                Text(
                  'Active Challenges',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppPalette.of(context).textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ...enrolledActiveChallenges.map(
                  (challenge) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: ChallengeCard(
                      challenge: challenge,
                      progress: progressByChallenge[challenge.id],
                      showMeta: true,
                      showPoints: true,
                      participantCount:
                          ref
                              .watch(
                                challengeParticipantCountProvider(challenge.id),
                              )
                              .valueOrNull,
                      onTap:
                          () => context.push(
                            AppConstants.challengeDetailLocation(challenge.id),
                          ),
                      adminActions:
                          isAdmin
                              ? ChallengeAdminActions(challenge: challenge)
                              : null,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Streak motivational card (non-enrolled state or after enrolled)
              if (isSignedIn) const _StreakMotivationCard(),
              if (isSignedIn) const SizedBox(height: AppSpacing.xl),

              // All challenges (admin or non-enrolled view)
              if (isAdmin ||
                  !isSignedIn ||
                  enrolledActiveChallenges.isEmpty) ...[
                Text(
                  isAdmin ? 'All Challenges' : 'Browse Challenges',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppPalette.of(context).textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ...challenges.map(
                  (challenge) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: ChallengeCard(
                      challenge: challenge,
                      progress: progressByChallenge[challenge.id],
                      showMeta: true,
                      showPoints: true,
                      participantCount:
                          ref
                              .watch(
                                challengeParticipantCountProvider(challenge.id),
                              )
                              .valueOrNull,
                      onTap:
                          () => context.push(
                            AppConstants.challengeDetailLocation(challenge.id),
                          ),
                      adminActions:
                          isAdmin
                              ? ChallengeAdminActions(challenge: challenge)
                              : null,
                    ),
                  ),
                ),
              ],

              // Upcoming Challenges section
              const _UpcomingChallengesSection(),
            ],
          ),
        );
      },
    );
  }
}

// ── My Progress Banner ────────────────────────────────────────────────────

class _MyProgressBanner extends ConsumerWidget {
  const _MyProgressBanner({required this.enrolledCount});

  final int enrolledCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final streakAsync = ref.watch(myActivityStreakProvider);
    final pointsAsync = ref.watch(myUserPointsProvider);

    final streak = streakAsync.valueOrNull ?? 0;
    final totalPoints = pointsAsync.valueOrNull?.totalPoints ?? 0;
    final level = pointsAsync.valueOrNull?.level ?? 1;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          // Enrollment count ring
          _EnrollmentRing(count: enrolledCount, palette: palette),
          const SizedBox(width: AppSpacing.lg),
          // Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'My Progress',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    LevelBadge(level: level),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    _StatChip(
                      icon: AppIcons.streak,
                      label: '$streak day streak',
                      color:
                          streak > 0 ? palette.accent : palette.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _StatChip(
                      icon: AppIcons.star,
                      label: '$totalPoints pts',
                      color: palette.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EnrollmentRing extends StatelessWidget {
  const _EnrollmentRing({required this.count, required this.palette});

  final int count;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.primarySubtle,
        border: Border.all(
          color: palette.primary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$count',
            style: AppTextStyles.statMedium.copyWith(color: palette.primary),
          ),
          Text(
            count == 1 ? 'active' : 'active',
            style: AppTextStyles.labelSmall.copyWith(
              color: palette.primary,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: color)),
      ],
    );
  }
}

// ── Streak Motivation Card ────────────────────────────────────────────────

class _StreakMotivationCard extends ConsumerWidget {
  const _StreakMotivationCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final streak = ref.watch(myActivityStreakProvider).valueOrNull ?? 0;
    if (streak == 0) return const SizedBox.shrink();

    final message = switch (streak) {
      1 => 'Great start — day 1! Keep it up tomorrow.',
      2 || 3 => '$streak-day streak! Momentum is building.',
      4 || 5 || 6 => '$streak days strong 🔥 — don\'t break it now!',
      7 => '1 week streak! That\'s commitment.',
      >= 30 => '$streak days — you\'re unstoppable!',
      _ => '$streak-day streak! Stay consistent.',
    };

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.accentContainer,
            ),
            child: AppIcon(AppIcons.streak, size: 20, color: palette.accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: palette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Upcoming Challenges Section ───────────────────────────────────────────

class _UpcomingChallengesSection extends ConsumerWidget {
  const _UpcomingChallengesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final upcomingAsync = ref.watch(upcomingChallengesProvider);

    return upcomingAsync.maybeWhen(
      data: (upcoming) {
        if (upcoming.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Upcoming',
              style: AppTextStyles.titleMedium.copyWith(
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...upcoming.map(
              (challenge) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: palette.cardHigh,
                        ),
                        child: AppIcon(
                          ChallengeIcon.forKey(challenge.icon),
                          size: 18,
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              challenge.title,
                              style: AppTextStyles.titleSmall.copyWith(
                                color: palette.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (challenge.startDate != null)
                              Text(
                                'Starts ${_formatDate(challenge.startDate!)}',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: palette.textSecondary,
                                ),
                              ),
                            if (ref
                                    .watch(
                                      challengeParticipantCountProvider(
                                        challenge.id,
                                      ),
                                    )
                                    .valueOrNull
                                case final count?)
                              Text(
                                count == 1
                                    ? '1 already joined'
                                    : '$count already joined',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: palette.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      _PointsPill(
                        points: challenge.pointValue,
                        palette: palette,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }
}

class _PointsPill extends StatelessWidget {
  const _PointsPill({required this.points, required this.palette});

  final int points;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: palette.primarySubtle,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '+$points pts',
        style: AppTextStyles.labelSmall.copyWith(color: palette.primary),
      ),
    );
  }
}

// ── Shared error / empty / skeleton ──────────────────────────────────────

class _ChallengesError extends StatelessWidget {
  const _ChallengesError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(AppIcons.error, size: 40, color: palette.danger),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Could not load challenges.',
              style: AppTextStyles.titleMedium.copyWith(
                color: palette.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Retry',
              icon: AppIcons.refresh,
              variant: AppButtonVariant.glass,
              size: AppButtonSize.small,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChallenges extends StatelessWidget {
  const _EmptyChallenges({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: palette.primarySubtle,
              shape: BoxShape.circle,
            ),
            child: AppIcon(
              AppIcons.challenges,
              size: 32,
              color: palette.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            isAdmin
                ? 'No challenges yet'
                : 'No challenges yet — check back soon',
            style: AppTextStyles.titleMedium.copyWith(
              color: palette.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          if (isAdmin) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tap "Add Challenge" to create the first one.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: palette.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _ChallengeListSkeleton extends StatelessWidget {
  const _ChallengeListSkeleton();

  @override
  Widget build(BuildContext context) => const SkeletonList(
    count: 4,
    showImages: false,
    padding: EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
  );
}
