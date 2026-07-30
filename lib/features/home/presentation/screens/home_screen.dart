import 'package:cached_network_image/cached_network_image.dart';
import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/activity/domain/services/activity_period.dart';
import 'package:doon_walkers/features/activity/presentation/providers/activity_dashboard_providers.dart';
import 'package:doon_walkers/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:doon_walkers/features/community/domain/entities/community_leaderboard_entry.dart';
import 'package:doon_walkers/features/community/domain/entities/member_directory_entry.dart';
import 'package:doon_walkers/features/community/presentation/providers/community_providers.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:doon_walkers/features/trek_library/presentation/providers/trek_providers.dart';
import 'package:doon_walkers/features/trek_library/presentation/widgets/trek_status_colors.dart';
import 'package:doon_walkers/features/weather/domain/models/weather_model.dart';
import 'package:doon_walkers/features/weather/presentation/providers/weather_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _handleRefresh(WidgetRef ref) async {
    final today = ActivityPeriod.day(DateTime.now());
    await Future.wait([
      ref.refresh(weatherProvider.future),
      ref.refresh(activitySummaryProvider(today).future),
      ref.refresh(myEnrollmentsProvider.future),
      ref.refresh(activeChallengesProvider.future),
      ref.refresh(communityLeaderboardProvider((limit: 3, offset: 0)).future),
      ref.refresh(publishedTreksProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _handleRefresh(ref),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xxl,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                _GreetingAndWeatherRow(),
                SizedBox(height: AppSpacing.xl),
                _TodayStepsCard(),
                SizedBox(height: AppSpacing.xxl),
                _ActiveChallengesSection(),
                SizedBox(height: AppSpacing.xxl),
                _CommunityStripSection(),
                SizedBox(height: AppSpacing.xxl),
                _ExploreTreksSection(),
                SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Section A: Time-aware Greeting + Open-Meteo Weather Widget
class _GreetingAndWeatherRow extends ConsumerWidget {
  const _GreetingAndWeatherRow();

  String _getTimeAwareGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final weatherAsync = ref.watch(weatherProvider);

    final name = user?.name.isNotEmpty == true ? user!.name : null;
    final greetingText =
        name != null
            ? '${_getTimeAwareGreeting()},\n$name 👋'
            : 'Welcome to\nDoonWalkers 👋';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            greetingText,
            style: AppTextStyles.headlineSmall.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        weatherAsync.when(
          data: (weather) => _WeatherChip(weather: weather),
          loading: () => const _WeatherSkeleton(),
          error: (_, __) => const _WeatherFallbackChip(),
        ),
      ],
    );
  }
}

class _WeatherChip extends StatelessWidget {
  const _WeatherChip({required this.weather});

  final WeatherModel weather;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: palette.primarySubtle,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(weather.conditionIcon, color: palette.primary, size: 20),
              const SizedBox(width: 6),
              Text(
                '${weather.temperature.round()}°C',
                style: AppTextStyles.titleMedium.copyWith(
                  color: palette.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            weather.recommendationLabel,
            style: AppTextStyles.labelSmall.copyWith(
              color: palette.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherFallbackChip extends StatelessWidget {
  const _WeatherFallbackChip();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppIcons.cloudOff, color: palette.textSecondary, size: 18),
          const SizedBox(width: 6),
          Text(
            'Weather unavailable',
            style: AppTextStyles.labelSmall.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherSkeleton extends StatelessWidget {
  const _WeatherSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Shimmer(
      child: SkeletonBox(width: 100, height: 48, borderRadius: AppRadius.card),
    );
  }
}

/// Section B: Today's Steps Card
class _TodayStepsCard extends ConsumerWidget {
  const _TodayStepsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final isSignedIn = ref.watch(isSignedInProvider);
    final goal = ref.watch(dailyStepGoalProvider);

    final todayPeriod = ActivityPeriod.day(DateTime.now());
    final summaryAsync = ref.watch(activitySummaryProvider(todayPeriod));

    return AppCard(
      onTap: () => context.go(AppConstants.routeActivity),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: palette.primarySubtle,
                  shape: BoxShape.circle,
                ),
                child: AppIcon(AppIcons.walk, color: palette.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Steps",
                      style: AppTextStyles.labelMedium.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                    if (isSignedIn)
                      summaryAsync.when(
                        data: (summary) {
                          final steps = summary.totalSteps;
                          return Text(
                            '$steps',
                            style: AppTextStyles.headlineMedium.copyWith(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                        loading:
                            () => const Shimmer(
                              child: SkeletonBox(
                                width: 80,
                                height: 28,
                                borderRadius: AppRadius.xs,
                              ),
                            ),
                        error:
                            (_, __) => Text(
                              '0',
                              style: AppTextStyles.headlineMedium.copyWith(
                                color: palette.textPrimary,
                              ),
                            ),
                      )
                    else
                      Text(
                        'Sign in to sync steps',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: palette.primary,
                        ),
                      ),
                  ],
                ),
              ),
              AppIcon(AppIcons.chevronRight, color: palette.textSecondary),
            ],
          ),
          if (isSignedIn) ...[
            const SizedBox(height: AppSpacing.md),
            summaryAsync.when(
              data: (summary) {
                final steps = summary.totalSteps;
                final progress = (steps / goal).clamp(0.0, 1.0);
                final remaining = goal - steps;

                final motivational =
                    remaining <= 0
                        ? 'Goal reached! 🎉'
                        : '$remaining steps to your daily goal ($goal)';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      builder:
                          (context, val, child) => LinearProgressIndicator(
                            value: val,
                            backgroundColor: palette.primarySubtle,
                            color: palette.primary,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      motivational,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Section C: Active Challenges Strip
class _ActiveChallengesSection extends ConsumerWidget {
  const _ActiveChallengesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final isSignedIn = ref.watch(isSignedInProvider);
    final enrollmentsAsync = ref.watch(myEnrollmentsProvider);
    final challengesAsync = ref.watch(activeChallengesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active Challenges',
              style: AppTextStyles.titleLarge.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => context.push(AppConstants.routeChallenges),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (!isSignedIn)
          AppCard(
            onTap: () => context.push(AppConstants.routeSignIn),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  AppIcon(AppIcons.challenges, color: palette.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Sign in to join community challenges and earn points.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          enrollmentsAsync.when(
            loading:
                () => const Shimmer(
                  child: SkeletonBox(height: 100, borderRadius: AppRadius.card),
                ),
            error:
                (_, __) => Text(
                  'Could not load challenges.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: palette.danger,
                  ),
                ),
            data: (enrollments) {
              final enrolledIds = enrollments.map((e) => e.challengeId).toSet();

              return challengesAsync.when(
                loading:
                    () => const Shimmer(
                      child: SkeletonBox(
                        height: 100,
                        borderRadius: AppRadius.card,
                      ),
                    ),
                error:
                    (_, __) => Text(
                      'Could not load challenges.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: palette.danger,
                      ),
                    ),
                data: (allChallenges) {
                  final activeEnrolled =
                      allChallenges
                          .where(
                            (c) => c.isActive && enrolledIds.contains(c.id),
                          )
                          .take(3)
                          .toList();

                  if (activeEnrolled.isEmpty) {
                    return AppCard(
                      onTap: () => context.push(AppConstants.routeChallenges),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Row(
                          children: [
                            AppIcon(
                              AppIcons.challenges,
                              color: palette.primary,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                'Join a challenge to earn points and badges!',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: palette.textPrimary,
                                ),
                              ),
                            ),
                            AppIcon(
                              AppIcons.chevronRight,
                              color: palette.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SizedBox(
                    height: 110,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: activeEnrolled.length,
                      separatorBuilder:
                          (context, index) =>
                              const SizedBox(width: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final challenge = activeEnrolled[index];
                        return Container(
                          width: 220,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: palette.card,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(color: palette.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                challenge.title,
                                style: AppTextStyles.titleSmall.copyWith(
                                  color: palette.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: palette.primarySubtle,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.xs,
                                      ),
                                    ),
                                    child: Text(
                                      '+${challenge.pointValue} pts',
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: palette.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }
}

/// Section D: Community Leaderboard Strip
class _CommunityStripSection extends ConsumerWidget {
  const _CommunityStripSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final leaderboardAsync = ref.watch(
      communityLeaderboardProvider((limit: 3, offset: 0)),
    );
    final myRankAsync = ref.watch(myCommunityRankProvider);
    final isSignedIn = ref.watch(isSignedInProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Community Top 3',
              style: AppTextStyles.titleLarge.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/community/leaderboard'),
              child: const Text('View Leaderboard'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        leaderboardAsync.when(
          loading:
              () => const Shimmer(
                child: SkeletonBox(height: 120, borderRadius: AppRadius.card),
              ),
          error:
              (_, __) => Text(
                'Could not load community strip.',
                style: AppTextStyles.bodyMedium.copyWith(color: palette.danger),
              ),
          data: (top3) {
            if (top3.isEmpty || top3.every((e) => e.totalPoints == 0)) {
              return AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(
                        AppIcons.leaderboard,
                        size: 40,
                        color: palette.textDisabled,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'No rankings yet.',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Complete treks and challenges to earn points.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: palette.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            // Build mini-podium: [#2] [#1] [#3]
            final first = top3.isNotEmpty ? top3[0] : null;
            final second = top3.length > 1 ? top3[1] : null;
            final third = top3.length > 2 ? top3[2] : null;

            return AppCard(
              onTap: () => context.push('/community/leaderboard'),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (second != null)
                        Expanded(
                          child: _MiniPodiumEntry(
                            entry: second,
                            position: 2,
                            avatarSize: 44,
                          ),
                        )
                      else
                        const Spacer(),
                      if (first != null)
                        Expanded(
                          child: _MiniPodiumEntry(
                            entry: first,
                            position: 1,
                            avatarSize: 56,
                          ),
                        )
                      else
                        const Spacer(),
                      if (third != null)
                        Expanded(
                          child: _MiniPodiumEntry(
                            entry: third,
                            position: 3,
                            avatarSize: 44,
                          ),
                        )
                      else
                        const Spacer(),
                    ],
                  ),
                  if (isSignedIn) ...[
                    const SizedBox(height: AppSpacing.md),
                    const Divider(),
                    const SizedBox(height: AppSpacing.xs),
                    myRankAsync.when(
                      data:
                          (myEntry) =>
                              myEntry != null
                                  ? Text(
                                    'Your Rank: #${myEntry.rank} · ${myEntry.totalPoints} pts',
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: palette.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                  : const SizedBox.shrink(),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// A single column in the home screen's mini-podium — avatar with rank ring,
/// name, and point count. No pedestal bar (too tall for a home strip).
class _MiniPodiumEntry extends StatelessWidget {
  const _MiniPodiumEntry({
    required this.entry,
    required this.position,
    required this.avatarSize,
  });

  final CommunityLeaderboardEntry entry;
  final int position;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final rankColor = switch (position) {
      1 => const Color(0xFFFFD700), // Gold
      2 => const Color(0xFFC0C0C0), // Silver
      3 => const Color(0xFFCD7F32), // Bronze
      _ => palette.primary,
    };

    final isFirst = position == 1;

    return InkWell(
      onTap: () {
        final member = MemberDirectoryEntry(
          userId: entry.userId,
          displayName: entry.displayName,
          avatarUrl: entry.avatarUrl,
          totalPoints: entry.totalPoints,
          level: entry.level,
        );
        context.push('/community/members/profile', extra: member);
      },
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Crown sparkle above #1
            if (isFirst) ...[
              AppIcon(AppIcons.celebrate, color: rankColor, size: 16),
              const SizedBox(height: 2),
            ],

            // Avatar with rank ring
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: rankColor, width: isFirst ? 2.5 : 2),
                color: palette.primarySubtle,
              ),
              child: ClipOval(
                child:
                    entry.avatarUrl != null && entry.avatarUrl!.isNotEmpty
                        ? CachedNetworkImage(
                          imageUrl: entry.avatarUrl!,
                          fit: BoxFit.cover,
                          errorWidget:
                              (_, __, ___) => _Initials(entry.displayName),
                        )
                        : _Initials(entry.displayName),
              ),
            ),

            // Rank badge overlay (medal pill)
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: rankColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: rankColor.withValues(alpha: 0.6)),
              ),
              child: Text(
                '#$position',
                style: AppTextStyles.labelSmall.copyWith(
                  color: rankColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(height: 4),

            // Name
            Text(
              entry.displayName,
              style: AppTextStyles.labelSmall.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),

            // Points
            Text(
              '${entry.totalPoints} pts',
              style: AppTextStyles.labelSmall.copyWith(
                color: palette.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section E: Explore Treks Grid
class _ExploreTreksSection extends ConsumerWidget {
  const _ExploreTreksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final treksAsync = ref.watch(publishedTreksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Explore Treks',
              style: AppTextStyles.titleLarge.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => context.go(AppConstants.routeTrekLibrary),
              child: const Text('Explore All Treks'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        treksAsync.when(
          loading:
              () => const Shimmer(
                child: SkeletonBox(height: 200, borderRadius: AppRadius.card),
              ),
          error:
              (_, __) => Text(
                'Could not load treks.',
                style: AppTextStyles.bodyMedium.copyWith(color: palette.danger),
              ),
          data: (treks) {
            if (treks.isEmpty) {
              return AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                    child: Text(
                      'No upcoming treks available right now.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }

            final displayTreks = treks.take(4).toList();

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                childAspectRatio: 0.85,
              ),
              itemCount: displayTreks.length,
              itemBuilder: (context, index) {
                final trek = displayTreks[index];
                return _HomeTrekCard(trek: trek);
              },
            );
          },
        ),
      ],
    );
  }
}

class _HomeTrekCard extends ConsumerWidget {
  const _HomeTrekCard({required this.trek});

  final Trek trek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final spotsLeftAsync = ref.watch(trekSpotsLeftProvider(trek.id));

    return AppCard(
      onTap: () => context.push('/trek-library/${trek.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.card),
              ),
              child:
                  trek.coverImage != null && trek.coverImage!.isNotEmpty
                      ? CachedNetworkImage(
                        imageUrl: trek.coverImage!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget:
                            (_, __, ___) => Container(
                              color: palette.primarySubtle,
                              child: AppIcon(
                                AppIcons.landscape,
                                color: palette.primary,
                              ),
                            ),
                      )
                      : Container(
                        color: palette.primarySubtle,
                        child: AppIcon(
                          AppIcons.landscape,
                          color: palette.primary,
                        ),
                      ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trek.title,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                spotsLeftAsync.when(
                  data: (spots) {
                    final status = resolveTrekStatus(trek, spots);
                    if (status == TrekBookingStatus.open && spots == null) {
                      return const SizedBox.shrink();
                    }
                    final color = getTrekStatusColor(status, palette);
                    final String text = status == TrekBookingStatus.almostFull
                        ? '$spots spots left'
                        : (status == TrekBookingStatus.waitlist ? 'Waitlist Only' : status.label);
                    return Text(
                      text,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: AppTextStyles.titleMedium.copyWith(
          color: palette.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
