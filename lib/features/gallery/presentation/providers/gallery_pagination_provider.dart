import 'package:doon_walkers/features/gallery/data/repositories/gallery_repository_impl.dart';
import 'package:doon_walkers/features/gallery/domain/entities/gallery_media.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Page size for [TrekGalleryPaginationController] — large enough that
/// the trek-detail preview's first 5-6 items and the fullscreen
/// viewer's initial swipe range both live comfortably inside page 0,
/// small enough to keep each fetch cheap.
const int trekGalleryPageSize = 30;

class TrekGalleryPage {
  const TrekGalleryPage({
    required this.items,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  final List<GalleryMedia> items;
  final bool hasMore;
  final bool isLoadingMore;

  TrekGalleryPage copyWith({List<GalleryMedia>? items, bool? hasMore, bool? isLoadingMore}) {
    return TrekGalleryPage(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Backs both [TrekGalleryScreen]'s infinite-scroll masonry grid AND
/// [FullScreenMediaViewer]'s infinite swipe — the same growing,
/// newest-first list of a trek's media serves both, so swiping past
/// the last currently-loaded item in the viewer transparently calls
/// [loadMore] instead of dead-ending, and the grid behind it already
/// reflects whatever the viewer just paged in when the viewer is
/// popped.
///
/// `autoDispose` — a trek's gallery page/viewer is visited transiently,
/// same reasoning as [trekGalleryProvider].
final trekGalleryPaginationProvider = AsyncNotifierProvider.autoDispose
    .family<TrekGalleryPaginationController, TrekGalleryPage, String>(
  TrekGalleryPaginationController.new,
  name: 'trekGalleryPaginationProvider',
);

class TrekGalleryPaginationController
    extends AutoDisposeFamilyAsyncNotifier<TrekGalleryPage, String> {
  int _page = 0;

  @override
  Future<TrekGalleryPage> build(String trekId) async {
    _page = 0;
    final items = await ref.watch(galleryRepositoryProvider).fetchMediaForTrekPage(
          trekId: trekId,
          page: 0,
          pageSize: trekGalleryPageSize,
        );
    return TrekGalleryPage(items: items, hasMore: items.length == trekGalleryPageSize);
  }

  /// Fetches the next page and appends it. A no-op while already
  /// loading or once the trek's media has been exhausted — safe to
  /// call speculatively from a scroll listener or a PageView nearing
  /// its last built page.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    final nextPage = _page + 1;
    try {
      final next = await ref.read(galleryRepositoryProvider).fetchMediaForTrekPage(
            trekId: arg,
            page: nextPage,
            pageSize: trekGalleryPageSize,
          );
      _page = nextPage;
      state = AsyncData(
        TrekGalleryPage(
          items: [...current.items, ...next],
          hasMore: next.length == trekGalleryPageSize,
        ),
      );
    } catch (_) {
      // Leave `_page` unadvanced so a later retry re-fetches the same
      // page rather than skipping it.
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}
