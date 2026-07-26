import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_progress.dart';
import 'package:doon_walkers/features/challenges/domain/services/challenge_search.dart';
import 'package:doon_walkers/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// **Explore Challenges** — the browsing half of the Challenges tab.
///
/// New in Redesign 2.0 Phase 12. My Challenges answers "how am I doing";
/// this answers "what is there", which the tab had no surface for: the
/// only view was a flat list with no search and no way to narrow by what a
/// challenge measures.
///
/// Reads the same [activeChallengesProvider] and [myChallengeProgressProvider]
/// as My Challenges — **no new schema, no new query, no new RPC.** The
/// difference is presentation: search, metric filters, and the
/// metric/window/days-left metadata row that a browsing card needs and a
/// tracking card doesn't.
///
/// ## Participant counts and points are real now (Phase 21/23)
///
/// This doc used to say a participant count would be a fabricated number
/// — true through Phase 12, when the engine had no opt-in concept. Phase
/// 21 added real enrollment (`challenge_enrollments`), so each card here
/// now also shows the real enrolled-participant count and point value via
/// [ChallengeCard.participantCount]/`showPoints`. There is still no Join
/// button here on purpose: joining is a Challenge Detail action (see
/// [JoinChallengeButton]), not something to trigger from a scannable
/// browsing list.
///
/// There is also still no separate "Popular"/"New" split — only a single
/// searchable/filterable list. `popularChallengesProvider` (Phase 21)
/// exists but is unconsumed; building a distinct Popular section is new
/// UI scope this phase (23) deliberately leaves alone (its own brief is
/// "close debt only, no new features").
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
  final _filters = <ChallengeMetricFilter>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleFilter(ChallengeMetricFilter filter) {
    setState(() {
      if (!_filters.remove(filter)) _filters.add(filter);
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
        ),
        _FilterChipRow(active: _filters, onToggle: _toggleFilter),
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
                  message: _filters.isEmpty
                      ? 'Nothing matches "${_query.trim()}".'
                      : 'Nothing matches that search and filter combination.',
                  onClear: () {
                    _searchController.clear();
                    setState(() {
                      _query = '';
                      _filters.clear();
                    });
                  },
                );
              }

              final progressByChallenge = <String, ChallengeProgress>{
                for (final p
                    in progressAsync.valueOrNull ??
                        const <ChallengeProgress>[])
                  p.challengeId: p,
              };

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                itemCount: visible.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final challenge = visible[index];
                  return ChallengeCard(
                    challenge: challenge,
                    progress: progressByChallenge[challenge.id],
                    showMeta: true,
                    showPoints: true,
                    participantCount: ref
                        .watch(challengeParticipantCountProvider(challenge.id))
                        .valueOrNull,
                    onTap: () => context.push(
                      AppConstants.challengeDetailLocation(challenge.id),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

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
            builder: (context, value, _) => value.text.isEmpty
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
          // Tighter than the app-wide input padding: a search field in a
          // header should not be as tall as a form field.
          contentPadding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.md,
          ),
        ),
      ),
    );
  }
}

class _FilterChipRow extends StatelessWidget {
  const _FilterChipRow({required this.active, required this.onToggle});

  final Set<ChallengeMetricFilter> active;
  final ValueChanged<ChallengeMetricFilter> onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          for (final filter in ChallengeMetricFilter.values) ...[
            _MetricChip(
              label: filter.label,
              selected: active.contains(filter),
              onTap: () => onToggle(filter),
              palette: palette,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.palette,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Pressable(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: selected ? palette.primarySubtle : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: selected ? palette.primary : palette.border,
              ),
            ),
            child: Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: selected ? palette.primary : palette.textSecondary,
              ),
            ),
          ),
        ),
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
