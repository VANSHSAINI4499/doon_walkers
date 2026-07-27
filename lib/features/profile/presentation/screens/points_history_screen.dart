import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/widgets/list_screen_states.dart';
import 'package:doon_walkers/features/profile/domain/services/points_history_grouping.dart';
import 'package:doon_walkers/features/profile/presentation/providers/points_pagination_provider.dart';
import 'package:doon_walkers/features/profile/presentation/widgets/points_ledger_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full, paginated points ledger — Phase 22. A top-level route (see
/// `AppConstants.routePointsHistory`), reached from the "View History"
/// link on Profile's points summary card. Router-gated to signed-in
/// members, same treatment as `/challenges/history`.
class PointsHistoryScreen extends ConsumerStatefulWidget {
  const PointsHistoryScreen({super.key});

  @override
  ConsumerState<PointsHistoryScreen> createState() =>
      _PointsHistoryScreenState();
}

class _PointsHistoryScreenState extends ConsumerState<PointsHistoryScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 600) {
      ref.read(myPointsHistoryPaginationProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_maybeLoadMore);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageAsync = ref.watch(myPointsHistoryPaginationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Points History')),
      body: pageAsync.when(
        loading: () => const ListScreenSkeleton(),
        error:
            (error, stack) => ListScreenError(
              message: 'Could not load your points history.',
              onRetry: () => ref.invalidate(myPointsHistoryPaginationProvider),
            ),
        data: (page) {
          Future<void> onRefresh() =>
              ref.refresh(myPointsHistoryPaginationProvider.future);

          if (page.entries.isEmpty) {
            return RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  ListScreenEmpty(
                    icon: AppIcons.star,
                    message:
                        "You haven't earned any points yet — join a challenge "
                        'or hit a daily step goal to get started.',
                  ),
                ],
              ),
            );
          }

          final groups = groupPointsHistoryByDay(page.entries);

          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: [
                for (final group in groups) ...[
                  _DayHeading(label: group.group.label),
                  for (final entry in group.items) ...[
                    PointsLedgerTile(entry: entry),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
                if (page.isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DayHeading extends StatelessWidget {
  const _DayHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md, top: AppSpacing.sm),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.overline.copyWith(color: palette.textSecondary),
      ),
    );
  }
}
