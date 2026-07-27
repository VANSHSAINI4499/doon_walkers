import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_progress.dart';
import 'package:doon_walkers/features/challenges/domain/services/challenge_search.dart';
import 'package:doon_walkers/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_card.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/explore_filter_sheet.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/how_it_works_sheet.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/new_challenge_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// How many of [popularChallengesProvider]'s already-limited results to
/// actually render — kept as its own constant so the cap is visible here
/// too, not just inside the provider.
const int _popularSectionLimit = 5;

/// How many of the newest active challenges to show in the New
/// Challenges grid.
const int _newSectionLimit = 4;

/// **Explore Challenges** — the browsing half of the Challenges tab.
///
/// New in Redesign 2.0 Phase 12. My Challenges answers "how am I doing";
/// this answers "what is there".
///
/// ## Phase 24: Popular + New sections, a real filter sheet
///
/// When search is empty and no filter is active, this shows a
/// structured layout: **Popular Challenges** (horizontal scroll, real
/// enrollment-count ordering via [popularChallengesProvider], capped at
/// [_popularSectionLimit]) → **New Challenges** (2-column grid of the
/// [_newSectionLimit] newest active challenges, off the same
/// `created_at DESC` ordering [activeChallengesProvider] already uses —
/// no new query) → **All Challenges** (the original flat list,
/// relabeled). The moment a search/filter is active, Popular and New
/// collapse entirely and only the filtered flat list shows — "popular
/// within a filtered subset" is a different, more confusing question
/// than "popular overall", so this avoids answering it.
///
/// The filter row used to be always-visible inline chips. Phase 23's
/// audit found no bottom sheet and no duration filter anywhere despite
/// the phase brief assuming both existed; this phase builds them for
/// real: [showExploreFilterSheet] combines the metric chips with a new
/// duration-in-days range slider, both AND'd into [filterChallenges].
///
/// Points and participant counts are real (Phase 21/23) — see
/// [ChallengeCard.participantCount]/`showPoints`. There is still no Join
/// button here: joining is a Challenge Detail action
/// ([JoinChallengeButton]), not something to trigger from a scannable
/// browsing list.
///
/// Drafts never appear here even for an admin: Explore is explicitly the
/// member-facing browse surface, and an admin managing drafts has the My
/// Challenges list (which does include them) plus the inline actions.
class ExploreChallengesView extends ConsumerStatefulWidget {
  const ExploreChallengesView({super.key});

  @override
  ConsumerState<ExploreChallengesView> createState() =>
      _ExploreChallengesViewState();
}

class _ExploreChallengesViewState extends ConsumerState<ExploreChallengesView> {
  final _searchController = TextEditingController();
  String _query = '';
  Set<ChallengeMetricFilter> _filters = {};
  ChallengeDurationRange? _durationRange;

  bool get _hasActiveFilter =>
      _query.trim().isNotEmpty || _filters.isNotEmpty || _durationRange != null;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFilterSheet() async {
    final result = await showExploreFilterSheet(
      context,
      initialMetrics: _filters,
      initialDuration: _durationRange,
    );
    if (result == null || !mounted) return;
    setState(() {
      _filters = result.metrics;
      _durationRange = result.duration;
    });
  }

  void _clearAll() {
    _searchController.clear();
    setState(() {
      _query = '';
      _filters = {};
      _durationRange = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final challengesAsync = ref.watch(activeChallengesProvider);
    final progressAsync = ref.watch(myChallengeProgressProvider);

    return Column(
      children: [
        _SearchField(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
          onFilterTap: _openFilterSheet,
          filterActive: _filters.isNotEmpty || _durationRange != null,
        ),
        Expanded(
          child: challengesAsync.when(
            loading: () => const _ExploreSkeleton(),
            error: (error, stack) {
              debugPrint('ExploreChallengesView: failed to load: $error');
              return _ExploreError(
                onRetry: () => ref.invalidate(activeChallengesProvider),
              );
            },
            data: (challenges) {
              final visible = filterChallenges(
                challenges,
                query: _query,
                metricFilters: _filters,
                durationRange: _durationRange,
              );

              if (challenges.isEmpty) {
                return const _ExploreEmpty(
                  icon: AppIcons.challenges,
                  title: 'No challenges yet',
                  message: 'New challenges will show up here as they open.',
                );
              }

              if (visible.isEmpty) {
                // Distinct from the above on purpose: "nothing exists" and
                // "your filters matched nothing" need different wording and
                // different next actions.
                return _ExploreEmpty(
                  icon: AppIcons.searchOff,
                  title: 'No matches',
                  message:
                      !_hasActiveFilter
                          ? 'Nothing matches "${_query.trim()}".'
                          : 'Nothing matches that search and filter combination.',
                  onClear: _clearAll,
                );
              }

              final progressByChallenge = <String, ChallengeProgress>{
                for (final p
                    in progressAsync.valueOrNull ?? const <ChallengeProgress>[])
                  p.challengeId: p,
              };

              if (_hasActiveFilter) {
                return _FilteredChallengeList(
                  challenges: visible,
                  progressByChallenge: progressByChallenge,
                );
              }

              return _StructuredExploreLayout(
                challenges: challenges,
                progressByChallenge: progressByChallenge,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The default (no search/filter) layout: Popular → New → All.
class _StructuredExploreLayout extends ConsumerWidget {
  const _StructuredExploreLayout({
    required this.challenges,
    required this.progressByChallenge,
  });

  final List<Challenge> challenges;
  final Map<String, ChallengeProgress> progressByChallenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popularAsync = ref.watch(popularChallengesProvider);
    final newest = challenges.take(_newSectionLimit).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        popularAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (error, stack) => const SizedBox.shrink(),
          data: (popular) {
            if (popular.isEmpty) return const SizedBox.shrink();
            return _PopularChallengesSection(
              challenges: popular.take(_popularSectionLimit).toList(),
              progressByChallenge: progressByChallenge,
            );
          },
        ),
        if (newest.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          const _SectionHeading(label: 'New Challenges'),
          const SizedBox(height: AppSpacing.md),
          _NewChallengesGrid(challenges: newest),
        ],
        const SizedBox(height: AppSpacing.xl),
        const _SectionHeading(label: 'All Challenges'),
        const SizedBox(height: AppSpacing.md),
        for (final challenge in challenges)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: ChallengeCard(
              challenge: challenge,
              progress: progressByChallenge[challenge.id],
              showMeta: true,
              showPoints: true,
              participantCount:
                  ref
                      .watch(challengeParticipantCountProvider(challenge.id))
                      .valueOrNull,
              onTap:
                  () => context.push(
                    AppConstants.challengeDetailLocation(challenge.id),
                  ),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        const _HowItWorksLink(),
      ],
    );
  }
}

/// The search/filter-active layout: just the filtered flat list.
class _FilteredChallengeList extends ConsumerWidget {
  const _FilteredChallengeList({
    required this.challenges,
    required this.progressByChallenge,
  });

  final List<Challenge> challenges;
  final Map<String, ChallengeProgress> progressByChallenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        for (final challenge in challenges)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: ChallengeCard(
              challenge: challenge,
              progress: progressByChallenge[challenge.id],
              showMeta: true,
              showPoints: true,
              participantCount:
                  ref
                      .watch(challengeParticipantCountProvider(challenge.id))
                      .valueOrNull,
              onTap:
                  () => context.push(
                    AppConstants.challengeDetailLocation(challenge.id),
                  ),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        const _HowItWorksLink(),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Text(
      label,
      style: AppTextStyles.titleMedium.copyWith(color: palette.textPrimary),
    );
  }
}

class _PopularChallengesSection extends ConsumerWidget {
  const _PopularChallengesSection({
    required this.challenges,
    required this.progressByChallenge,
  });

  final List<Challenge> challenges;
  final Map<String, ChallengeProgress> progressByChallenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(label: 'Popular Challenges'),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 240,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: challenges.length,
            separatorBuilder:
                (context, index) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final challenge = challenges[index];
              return SizedBox(
                width: 300,
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NewChallengesGrid extends StatelessWidget {
  const _NewChallengesGrid({required this.challenges});

  final List<Challenge> challenges;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: challenges.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (context, index) {
        final challenge = challenges[index];
        return NewChallengeCard(
          challenge: challenge,
          onTap:
              () => context.push(
                AppConstants.challengeDetailLocation(challenge.id),
              ),
        );
      },
    );
  }
}

class _HowItWorksLink extends StatelessWidget {
  const _HowItWorksLink();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Center(
      child: Pressable(
        onTap: () => showHowItWorksSheet(context),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(AppIcons.info, size: 16, color: palette.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'How does this work?',
                style: AppTextStyles.labelMedium.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onFilterTap,
    required this.filterActive,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterTap;
  final bool filterActive;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search challenges',
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.md),
                  child: AppIcon(
                    AppIcons.search,
                    size: 20,
                    color: palette.textSecondary,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 44),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder:
                      (context, value, _) =>
                          value.text.isEmpty
                              ? const SizedBox.shrink()
                              : IconButton(
                                icon: AppIcon(
                                  AppIcons.close,
                                  size: 18,
                                  color: palette.textSecondary,
                                ),
                                tooltip: 'Clear',
                                onPressed: () {
                                  controller.clear();
                                  onChanged('');
                                },
                              ),
                ),
                // Tighter than the app-wide input padding: a search field
                // in a header should not be as tall as a form field.
                contentPadding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                  horizontal: AppSpacing.md,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: AppIcon(AppIcons.filter, color: palette.textSecondary),
                tooltip: 'Filter challenges',
                onPressed: onFilterTap,
              ),
              if (filterActive)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: palette.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExploreEmpty extends StatelessWidget {
  const _ExploreEmpty({
    required this.icon,
    required this.title,
    required this.message,
    this.onClear,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: palette.cardHigh,
                shape: BoxShape.circle,
              ),
              child: AppIcon(icon, size: 28, color: palette.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: AppTextStyles.titleMedium.copyWith(
                color: palette.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: palette.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onClear != null) ...[
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Clear filters',
                icon: AppIcons.close,
                variant: AppButtonVariant.glass,
                size: AppButtonSize.small,
                onPressed: onClear,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExploreError extends StatelessWidget {
  const _ExploreError({required this.onRetry});

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

class _ExploreSkeleton extends StatelessWidget {
  const _ExploreSkeleton();

  @override
  Widget build(BuildContext context) => const SkeletonList(
    count: 4,
    showImages: false,
    padding: EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.sm,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
  );
}
