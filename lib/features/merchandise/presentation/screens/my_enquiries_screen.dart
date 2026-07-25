import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/widgets/list_screen_states.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/merch_inquiry.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/merch_inquiry_pagination_provider.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/my_inquiries_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full "My Inquiries" list — reached from [MyInquiriesSection]'s
/// "View All" link on Profile once there are more than 2 items.
/// Paginated, pull-to-refresh, search-filterable, read-only (mirrors
/// the preview's read-only behaviour — only an admin changes an
/// inquiry's status). Reuses [MyInquiryTile], the exact same row the
/// Profile preview renders.
class MyEnquiriesScreen extends ConsumerStatefulWidget {
  const MyEnquiriesScreen({super.key});

  @override
  ConsumerState<MyEnquiriesScreen> createState() => _MyEnquiriesScreenState();
}

class _MyEnquiriesScreenState extends ConsumerState<MyEnquiriesScreen> {
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
      ref.read(myInquiriesPaginationProvider.notifier).loadMore();
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

  List<MerchInquiry> _filter(List<MerchInquiry> items) {
    if (_query.isEmpty) return items;
    return items.where((item) => item.productName.toLowerCase().contains(_query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pageAsync = ref.watch(myInquiriesPaginationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Inquiries')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
            child: ListSearchField(controller: _searchController, hint: 'Search your inquiries'),
          ),
          Expanded(
            child: pageAsync.when(
              loading: () => const ListScreenSkeleton(),
              error: (error, stack) => ListScreenError(
                message: 'Could not load your inquiries.',
                onRetry: () => ref.invalidate(myInquiriesPaginationProvider),
              ),
              data: (page) {
                Future<void> onRefresh() => ref.refresh(myInquiriesPaginationProvider.future);

                final filtered = _filter(page.items);
                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: onRefresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        ListScreenEmpty(
                          icon: AppIcons.bag,
                          message: _query.isNotEmpty
                              ? 'No inquiries match "$_query".'
                              : 'You haven\'t sent any "Buy Now" inquiries yet.',
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
                          child: MyInquiryTile(inquiry: filtered[index]),
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
