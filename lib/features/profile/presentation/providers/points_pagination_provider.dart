import 'package:doon_walkers/features/profile/data/repositories/points_repository_impl.dart';
import 'package:doon_walkers/features/profile/domain/entities/points_ledger_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Page size for [MyPointsHistoryPaginationController] — backs
/// [PointsHistoryScreen]'s infinite-scroll list.
const int pointsHistoryPageSize = 30;

class PointsHistoryPage {
  const PointsHistoryPage({
    required this.entries,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  final List<PointsLedgerEntry> entries;
  final bool hasMore;
  final bool isLoadingMore;

  PointsHistoryPage copyWith({
    List<PointsLedgerEntry>? entries,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return PointsHistoryPage(
      entries: entries ?? this.entries,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Backs [PointsHistoryScreen]'s infinite-scroll list — same shape as
/// `MyWishlistPaginationController`, the established pattern for this
/// exact need in this codebase. `autoDispose` since the screen is
/// visited transiently.
final myPointsHistoryPaginationProvider = AsyncNotifierProvider.autoDispose<
  MyPointsHistoryPaginationController,
  PointsHistoryPage
>(
  MyPointsHistoryPaginationController.new,
  name: 'myPointsHistoryPaginationProvider',
);

class MyPointsHistoryPaginationController
    extends AutoDisposeAsyncNotifier<PointsHistoryPage> {
  int _page = 0;

  @override
  Future<PointsHistoryPage> build() async {
    _page = 0;
    final entries = await ref
        .watch(pointsRepositoryProvider)
        .fetchMyHistoryPage(page: 0, pageSize: pointsHistoryPageSize);
    return PointsHistoryPage(
      entries: entries,
      hasMore: entries.length == pointsHistoryPageSize,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    final nextPage = _page + 1;
    try {
      final next = await ref
          .read(pointsRepositoryProvider)
          .fetchMyHistoryPage(page: nextPage, pageSize: pointsHistoryPageSize);
      _page = nextPage;
      state = AsyncData(
        PointsHistoryPage(
          entries: [...current.entries, ...next],
          hasMore: next.length == pointsHistoryPageSize,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}
