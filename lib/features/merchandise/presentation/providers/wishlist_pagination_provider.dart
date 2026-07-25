import 'package:doon_walkers/features/merchandise/data/repositories/wishlist_repository_impl.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/wishlist_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Page size for [MyWishlistPaginationController] — backs
/// [WishlistScreen]'s infinite-scroll list.
const int wishlistPageSize = 30;

class WishlistPage {
  const WishlistPage({required this.items, required this.hasMore, this.isLoadingMore = false});

  final List<WishlistItem> items;
  final bool hasMore;
  final bool isLoadingMore;

  WishlistPage copyWith({List<WishlistItem>? items, bool? hasMore, bool? isLoadingMore}) {
    return WishlistPage(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Backs [WishlistScreen]'s infinite-scroll grid — same shape as
/// `TrekGalleryPaginationController` (gallery feature), the established
/// pattern for this exact need in this codebase. `autoDispose` since
/// the screen is visited transiently.
final myWishlistPaginationProvider =
    AsyncNotifierProvider.autoDispose<MyWishlistPaginationController, WishlistPage>(
  MyWishlistPaginationController.new,
  name: 'myWishlistPaginationProvider',
);

class MyWishlistPaginationController extends AutoDisposeAsyncNotifier<WishlistPage> {
  int _page = 0;

  @override
  Future<WishlistPage> build() async {
    _page = 0;
    final items = await ref
        .watch(wishlistRepositoryProvider)
        .fetchMyWishlistPage(page: 0, pageSize: wishlistPageSize);
    return WishlistPage(items: items, hasMore: items.length == wishlistPageSize);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    final nextPage = _page + 1;
    try {
      final next = await ref
          .read(wishlistRepositoryProvider)
          .fetchMyWishlistPage(page: nextPage, pageSize: wishlistPageSize);
      _page = nextPage;
      state = AsyncData(
        WishlistPage(
          items: [...current.items, ...next],
          hasMore: next.length == wishlistPageSize,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}
