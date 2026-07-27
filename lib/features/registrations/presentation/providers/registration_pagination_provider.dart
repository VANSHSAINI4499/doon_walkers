import 'package:doon_walkers/features/registrations/data/repositories/registration_repository_impl.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Page size for [MyRegistrationsPaginationController] — backs
/// [MyRegistrationsScreen]'s infinite-scroll list.
const int myRegistrationsPageSize = 30;

class MyRegistrationsPage {
  const MyRegistrationsPage({
    required this.items,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  final List<Registration> items;
  final bool hasMore;
  final bool isLoadingMore;

  MyRegistrationsPage copyWith({
    List<Registration>? items,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return MyRegistrationsPage(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Backs [MyRegistrationsScreen]'s infinite-scroll list — same shape as
/// `TrekGalleryPaginationController` (gallery feature), the established
/// pattern for this exact need in this codebase. `autoDispose` since
/// the screen is visited transiently.
final myRegistrationsPaginationProvider = AsyncNotifierProvider.autoDispose<
  MyRegistrationsPaginationController,
  MyRegistrationsPage
>(
  MyRegistrationsPaginationController.new,
  name: 'myRegistrationsPaginationProvider',
);

class MyRegistrationsPaginationController
    extends AutoDisposeAsyncNotifier<MyRegistrationsPage> {
  int _page = 0;

  @override
  Future<MyRegistrationsPage> build() async {
    _page = 0;
    final items = await ref
        .watch(registrationRepositoryProvider)
        .fetchMyRegistrationsPage(page: 0, pageSize: myRegistrationsPageSize);
    return MyRegistrationsPage(
      items: items,
      hasMore: items.length == myRegistrationsPageSize,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    final nextPage = _page + 1;
    try {
      final next = await ref
          .read(registrationRepositoryProvider)
          .fetchMyRegistrationsPage(
            page: nextPage,
            pageSize: myRegistrationsPageSize,
          );
      _page = nextPage;
      state = AsyncData(
        MyRegistrationsPage(
          items: [...current.items, ...next],
          hasMore: next.length == myRegistrationsPageSize,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}
