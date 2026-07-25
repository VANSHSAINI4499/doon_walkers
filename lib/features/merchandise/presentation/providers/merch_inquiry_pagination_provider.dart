import 'package:doon_walkers/features/merchandise/data/repositories/merch_inquiry_repository_impl.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/merch_inquiry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Page size for [MyInquiriesPaginationController] — backs
/// [MyEnquiriesScreen]'s infinite-scroll list.
const int myInquiriesPageSize = 30;

class MyInquiriesPage {
  const MyInquiriesPage({required this.items, required this.hasMore, this.isLoadingMore = false});

  final List<MerchInquiry> items;
  final bool hasMore;
  final bool isLoadingMore;

  MyInquiriesPage copyWith({List<MerchInquiry>? items, bool? hasMore, bool? isLoadingMore}) {
    return MyInquiriesPage(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Backs [MyEnquiriesScreen]'s infinite-scroll list — same shape as
/// `TrekGalleryPaginationController` (gallery feature), the established
/// pattern for this exact need in this codebase. `autoDispose` since
/// the screen is visited transiently.
final myInquiriesPaginationProvider =
    AsyncNotifierProvider.autoDispose<MyInquiriesPaginationController, MyInquiriesPage>(
  MyInquiriesPaginationController.new,
  name: 'myInquiriesPaginationProvider',
);

class MyInquiriesPaginationController extends AutoDisposeAsyncNotifier<MyInquiriesPage> {
  int _page = 0;

  @override
  Future<MyInquiriesPage> build() async {
    _page = 0;
    final items = await ref
        .watch(merchInquiryRepositoryProvider)
        .fetchMyInquiriesPage(page: 0, pageSize: myInquiriesPageSize);
    return MyInquiriesPage(items: items, hasMore: items.length == myInquiriesPageSize);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    final nextPage = _page + 1;
    try {
      final next = await ref
          .read(merchInquiryRepositoryProvider)
          .fetchMyInquiriesPage(page: nextPage, pageSize: myInquiriesPageSize);
      _page = nextPage;
      state = AsyncData(
        MyInquiriesPage(
          items: [...current.items, ...next],
          hasMore: next.length == myInquiriesPageSize,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}
