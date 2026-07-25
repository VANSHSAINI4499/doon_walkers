import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/widgets/list_screen_states.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_pagination_provider.dart';
import 'package:doon_walkers/features/registrations/presentation/widgets/my_registrations_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full "My Registrations" list — reached from
/// [MyRegistrationsSection]'s "View All" link on Profile once there
/// are more than 2 items. Paginated, pull-to-refresh, search-
/// filterable, keeps the same self-service cancel action, and reuses
/// [MyRegistrationTile] (the exact same row the Profile preview
/// renders).
class MyRegistrationsScreen extends ConsumerStatefulWidget {
  const MyRegistrationsScreen({super.key});

  @override
  ConsumerState<MyRegistrationsScreen> createState() => _MyRegistrationsScreenState();
}

class _MyRegistrationsScreenState extends ConsumerState<MyRegistrationsScreen> {
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
    if (_query.isEmpty) return items;
    return items.where((item) => item.trekTitle.toLowerCase().contains(_query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pageAsync = ref.watch(myRegistrationsPaginationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Registrations')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
            child: ListSearchField(controller: _searchController, hint: 'Search your registrations'),
          ),
          Expanded(
            child: pageAsync.when(
              loading: () => const ListScreenSkeleton(),
              error: (error, stack) => ListScreenError(
                message: 'Could not load your registrations.',
                onRetry: () => ref.invalidate(myRegistrationsPaginationProvider),
              ),
              data: (page) {
                Future<void> onRefresh() => ref.refresh(myRegistrationsPaginationProvider.future);

                final filtered = _filter(page.items);
                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: onRefresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        ListScreenEmpty(
                          icon: AppIcons.hiking,
                          message: _query.isNotEmpty
                              ? 'No registrations match "$_query".'
                              : "You haven't registered for any treks yet.",
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
                          child: MyRegistrationTile(registration: filtered[index]),
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
