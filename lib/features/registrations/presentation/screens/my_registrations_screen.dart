import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/widgets/list_screen_states.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:doon_walkers/features/registrations/domain/services/registration_status_group.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_pagination_provider.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:doon_walkers/features/registrations/presentation/widgets/my_registrations_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full "My Registrations" list — reached from
/// [MyRegistrationsSection]'s "View All" link on Profile once there
/// are more than 2 items. Paginated, pull-to-refresh, search-
/// filterable, keeps the same self-service cancel action, and reuses
/// [MyRegistrationTile] (the exact same row the Profile preview
/// renders).
///
/// ## Redesign 2.0 Phase 15: Upcoming / Completed / Cancelled tabs
///
/// Adds an [AppSegmentedControl] splitting the list into the three real
/// groups [registrationStatusGroupFor] computes — no new data, no new
/// query. The split runs client-side over whatever page is currently
/// loaded, layered on top of the *existing* client-side search filter
/// (the same pattern this screen already used for search, just one more
/// dimension) rather than changing how pagination itself works.
///
/// The Completed tab carries a milestone banner showing the member's
/// **verified** attended count from [myRegistrationStatsProvider] — the
/// same real, `checked_in_at`-derived figure Profile's stats card already
/// shows, not a re-derived one. It can differ from the tab's own item
/// count: the tab groups by trek *date* (any past, non-cancelled
/// registration), matching how Trek Library groups treks, while the
/// stats figure additionally requires a verified check-in for a
/// post-QR-cutoff trek — see [registrationStatusGroupFor]'s doc for why
/// that distinction is a per-tile "Checked in" mark, not a fourth tab.
class MyRegistrationsScreen extends ConsumerStatefulWidget {
  const MyRegistrationsScreen({super.key});

  @override
  ConsumerState<MyRegistrationsScreen> createState() =>
      _MyRegistrationsScreenState();
}

class _MyRegistrationsScreenState extends ConsumerState<MyRegistrationsScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String _query = '';
  RegistrationStatusGroup _group = RegistrationStatusGroup.upcoming;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() => _query = _searchController.text.trim().toLowerCase());
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 600) {
      ref.read(myRegistrationsPaginationProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_maybeLoadMore);
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  List<Registration> _filter(List<Registration> items) {
    return items.where((item) {
      if (registrationStatusGroupFor(item) != _group) return false;
      if (_query.isEmpty) return true;
      return item.trekTitle.toLowerCase().contains(_query);
    }).toList();
  }

  String _emptyMessage() {
    if (_query.isNotEmpty) return 'No registrations match "$_query".';
    return switch (_group) {
      RegistrationStatusGroup.upcoming =>
        "You don't have any upcoming registrations.",
      RegistrationStatusGroup.completed => "You haven't completed a trek yet.",
      RegistrationStatusGroup.cancelled => 'No cancelled registrations.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final pageAsync = ref.watch(myRegistrationsPaginationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Registrations')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              0,
            ),
            child: ListSearchField(
              controller: _searchController,
              hint: 'Search your registrations',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: AppSegmentedControl<RegistrationStatusGroup>(
              value: _group,
              onChanged: (g) => setState(() => _group = g),
              segments: [
                for (final g in RegistrationStatusGroup.values) (g, g.label),
              ],
            ),
          ),
          Expanded(
            child: pageAsync.when(
              loading: () => const ListScreenSkeleton(),
              error:
                  (error, stack) => ListScreenError(
                    message: 'Could not load your registrations.',
                    onRetry:
                        () => ref.invalidate(myRegistrationsPaginationProvider),
                  ),
              data: (page) {
                Future<void> onRefresh() =>
                    ref.refresh(myRegistrationsPaginationProvider.future);

                final filtered = _filter(page.items);

                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: onRefresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (_group == RegistrationStatusGroup.completed)
                          const _CompletedMilestoneBanner(),
                        ListScreenEmpty(
                          icon: AppIcons.hiking,
                          message: _emptyMessage(),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: onRefresh,
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.xxl,
                    ),
                    // +1 for the milestone banner on the Completed tab —
                    // it scrolls with the list rather than pinning above
                    // it, since it's context for this tab, not chrome.
                    itemCount:
                        (_group == RegistrationStatusGroup.completed ? 1 : 0) +
                        filtered.length +
                        (page.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      var i = index;
                      if (_group == RegistrationStatusGroup.completed) {
                        if (i == 0) return const _CompletedMilestoneBanner();
                        i--;
                      }
                      if (i >= filtered.length) {
                        return const Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: AppReveal(
                          index: i.clamp(0, 8),
                          child: MyRegistrationTile(registration: filtered[i]),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// "You've completed N treks" — the real, verified-attendance count from
/// [myRegistrationStatsProvider], the same figure Profile's stats card
/// shows. Shown once at the top of the Completed tab, not per item.
class _CompletedMilestoneBanner extends ConsumerWidget {
  const _CompletedMilestoneBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final statsAsync = ref.watch(myRegistrationStatsProvider);
    final attended = statsAsync.valueOrNull?.totalAttended;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: AppCard(
        borderColor: palette.primary.withValues(alpha: 0.4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: palette.primarySubtle,
                shape: BoxShape.circle,
              ),
              child: AppIcon(
                AppIcons.verified,
                size: 22,
                color: palette.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    attended == null
                        ? 'Loading your trek history…'
                        : attended == 1
                        ? "You've completed 1 trek"
                        : "You've completed $attended treks",
                    style: AppTextStyles.titleSmall.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Verified by check-in where available.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
