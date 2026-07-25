import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/widgets/list_screen_states.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/wishlist_item.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/wishlist_pagination_provider.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/my_wishlist_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full "My Wishlist" list — reached from [MyWishlistSection]'s "View
/// All" link on Profile once there are more than 2 items. Paginated,
/// pull-to-refresh, search-filterable, and reuses [WishlistTile] (the
/// exact same row the Profile preview renders).
class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key});

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String _query = '';

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
      ref.read(myWishlistPaginationProvider.notifier).loadMore();
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

  List<WishlistItem> _filter(List<WishlistItem> items) {
    if (_query.isEmpty) return items;
    return items.where((item) => item.product.name.toLowerCase().contains(_query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pageAsync = ref.watch(myWishlistPaginationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Wishlist')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
            child: ListSearchField(controller: _searchController, hint: 'Search your wishlist'),
          ),
          Expanded(
            child: pageAsync.when(
              loading: () => const ListScreenSkeleton(),
              error: (error, stack) => ListScreenError(
                message: 'Could not load your wishlist.',
                onRetry: () => ref.invalidate(myWishlistPaginationProvider),
              ),
              data: (page) {
                Future<void> onRefresh() => ref.refresh(myWishlistPaginationProvider.future);

                final filtered = _filter(page.items);
                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: onRefresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        ListScreenEmpty(
                          icon: AppIcons.favorite,
                          message: _query.isNotEmpty
                              ? 'No wishlist items match "$_query".'
                              : "You haven't wishlisted anything yet.",
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
                    itemCount: filtered.length + (page.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= filtered.length) {
                        return const Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: AppReveal(
                          index: index.clamp(0, 8),
                          child: WishlistTile(item: filtered[index]),
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
