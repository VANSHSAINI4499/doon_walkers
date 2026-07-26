import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/activity/presentation/providers/activity_providers.dart';
import 'package:doon_walkers/features/activity/presentation/widgets/activity_permission_banner.dart';
import 'package:doon_walkers/features/challenges/data/services/challenge_celebration_tracker.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_progress.dart';
import 'package:doon_walkers/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_admin_actions.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_card.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/explore_challenges_view.dart';
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
/// ## Redesign 2.0 Phase 12
///
/// Two changes: the presentation moves to the calm system (flat cards, no
/// tier glow, light + dark), and the tab gains a **My Challenges /
/// Explore** split — previously there was only the flat list, with no
/// search and no way to narrow by metric. See [ExploreChallengesView].
///
/// **The celebration detection is untouched**: the `ref.listen` on live
/// progress, the [isNewlyAchievedTier] diff against the persisted
/// per-device baseline, and the queued overlay all behave exactly as
/// before, and deliberately keep running regardless of which view is on
/// screen — a tier earned while browsing Explore should still celebrate.
///
/// ## No points, no join
///
/// The reference for this phase showed points totals and Join buttons.
/// Neither exists: the engine awards tiers, and active challenges apply to
/// everyone with progress computed from activity data. Both are omitted
/// rather than stubbed — see [ChallengeCard]'s doc.
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
    final challengesProvider = isAdmin
        ? adminAllChallengesProvider
        : activeChallengesProvider;
    final challengesAsync = ref.watch(challengesProvider);
    final progressAsync = ref.watch(myChallengeProgressProvider);

    // Fires only on a real data change (a FutureProvider's value actually
    // changing), never on a plain rebuild — see ChallengeCelebrationTracker
    // for why that, combined with a persisted per-device baseline, keeps
    // this from re-celebrating the same tier on every screen visit.
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
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () =>
                  context.push(AppConstants.routeAdminChallengesNew),
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
}

/// The tracking half: a summary header plus the challenges the viewer has
/// progress on. Includes drafts for an admin.
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
        // Pull-to-refresh doubles as one of the three sync triggers
        // (launch/resume/manual) — chained so the refresh spinner stays up
        // until fresh activity data has actually landed, not just the
        // challenge list itself.
        Future<void> onRefresh() {
          return ref
              .read(activitySyncControllerProvider.notifier)
              .sync()
              .then((_) {
                ref.invalidate(myChallengeProgressProvider);
                ref.invalidate(myActivityStreakProvider);
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

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              isAdmin ? 96 : AppSpacing.lg,
            ),
            // +1 for the summary header, which scrolls with the list rather
            // than pinning above it — it is context, not chrome.
            itemCount: challenges.length + 1,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _ChallengesSummary(activeCount: challenges.where((c) => c.isActive).length);
              }
              final challenge = challenges[index - 1];
              return ChallengeCard(
                challenge: challenge,
                progress: progressByChallenge[challenge.id],
                onTap: () => context.push(
                  AppConstants.challengeDetailLocation(challenge.id),
                ),
                adminActions: isAdmin
                    ? ChallengeAdminActions(challenge: challenge)
                    : null,
              );
            },
          ),
        );
      },
    );
  }
}

/// Header stats: how many challenges are live, and the viewer's current
/// activity streak.
///
/// The streak comes from [myActivityStreakProvider] — computed client-side
/// from the user's own `daily_activity_summary` rows, matching the
/// engine's own rule. It is **not** `get_my_streak()`, which is the
/// month-granular *trekking* streak shown on Profile; see
/// `activity_streak.dart` for why there is no RPC for this one.
///
/// Hidden entirely for a guest: both numbers would be meaningless (a guest
/// has no streak) and the tab already carries a sign-in prompt per card.
class _ChallengesSummary extends ConsumerWidget {
  const _ChallengesSummary({required this.activeCount});

  final int activeCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isSignedInProvider)) return const SizedBox.shrink();

    final streakAsync = ref.watch(myActivityStreakProvider);
    final palette = AppPalette.of(context);

    return AppCard(
      child: StatRow(
        stats: [
          StatDisplay(
            value: '$activeCount',
            label: activeCount == 1 ? 'challenge live' : 'challenges live',
          ),
          StatDisplay(
            // An unresolved streak shows an em dash, not 0 — "0 days" and
            // "still loading" mean very different things to someone who
            // walked this morning.
            value: streakAsync.maybeWhen(
              data: (days) => '$days',
              orElse: () => '—',
            ),
            label: 'day streak',
            color: (streakAsync.valueOrNull ?? 0) > 0 ? palette.primary : null,
          ),
        ],
      ),
    );
  }
}

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
            isAdmin ? 'No challenges yet' : 'No challenges yet — check back soon',
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

/// Challenge-card-shaped placeholders while the list loads.
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
