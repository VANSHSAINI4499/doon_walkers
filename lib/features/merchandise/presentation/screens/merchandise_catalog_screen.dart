import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/theme/app_colors.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/product.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/product_providers.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/product_admin_actions.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/product_card.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/product_search_filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

/// Merchandise Catalog — one shared screen for every role, same shape
/// as Trek Library: guests/members see active products only, an admin
/// sees the same screen plus inline management (drafts included,
/// marked as such, a per-product actions menu, and an "Add Product"
/// button). No separate admin-only management screen, consistent with
/// this project's inline-admin-controls convention.
///
/// A top-level route outside the bottom-nav shell (see
/// AppConstants.routeMerchandise's doc) — reached via the Navigation
/// Drawer, not a tab.
class MerchandiseCatalogScreen extends ConsumerStatefulWidget {
  const MerchandiseCatalogScreen({super.key});

  @override
  ConsumerState<MerchandiseCatalogScreen> createState() => _MerchandiseCatalogScreenState();
}

class _MerchandiseCatalogScreenState extends ConsumerState<MerchandiseCatalogScreen> {
  final _searchController = TextEditingController();
  String _searchText = '';
  ProductCategory? _selectedCategory;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) => setState(() => _searchText = value);

  void _onClearSearch() {
    _searchController.clear();
    setState(() => _searchText = '');
  }

  /// Client-side search + category filter — see
  /// ProductSearchFilterBar's doc for why this isn't a server-side
  /// query at this project's catalog scale.
  List<Product> _filtered(List<Product> products) {
    final query = _searchText.trim().toLowerCase();
    return products.where((product) {
      final matchesCategory = _selectedCategory == null || product.category == _selectedCategory;
      final matchesSearch = query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.description.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin = ref.watch(isAdminProvider);
    final productsProvider = isAdmin ? adminAllProductsProvider : activeProductsProvider;
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Merchandise')),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppConstants.routeMerchandiseNew),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Product'),
            )
          : null,
      body: SafeArea(
        child: productsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) {
            debugPrint('MerchandiseCatalogScreen: failed to load products: $error');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 40, color: theme.colorScheme.error),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load merchandise.',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(productsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (allProducts) {
            Future<void> onRefresh() => ref.refresh(productsProvider.future);
            final products = _filtered(allProducts);

            return RefreshIndicator(
              onRefresh: onRefresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(child: _HeroBanner()),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: ProductSearchFilterBar(
                        searchController: _searchController,
                        onSearchChanged: _onSearchChanged,
                        onClearSearch: _onClearSearch,
                        selectedCategory: _selectedCategory,
                        onCategoryChanged: (category) =>
                            setState(() => _selectedCategory = category),
                      ),
                    ),
                  ),
                  if (allProducts.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyCatalog(isAdmin: isAdmin, noMatch: false),
                    )
                  else if (products.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyCatalog(isAdmin: isAdmin, noMatch: true),
                    )
                  else
                    SliverPadding(
                      // Extra bottom padding for admins so the FAB never
                      // covers the last row's action menu.
                      padding: EdgeInsets.fromLTRB(16, 16, 16, isAdmin ? 96 : 16),
                      // A true sliver masonry grid (not GridView wrapped
                      // in shrinkWrap+NeverScrollableScrollPhysics) so it
                      // shares this one CustomScrollView with the hero
                      // banner and filter bar above, instead of nesting
                      // a second scrollable inside the first. Masonry,
                      // not a fixed-childAspectRatio grid — name/
                      // description length varies product to product,
                      // same reasoning (and same fix) as the Trek
                      // Library grid's card-height lesson: a fixed cell
                      // height either wastes space or clips content.
                      sliver: SliverMasonryGrid.extent(
                        maxCrossAxisExtent: 340,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return ProductCard(
                            product: product,
                            onTap: () =>
                                context.push(AppConstants.merchandiseDetailLocation(product.id)),
                            adminActions: isAdmin ? ProductAdminActions(product: product) : null,
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Doon Walkers Merchandise',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Wear your trail pride.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white.withAlpha(210),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog({required this.isAdmin, required this.noMatch});

  final bool isAdmin;

  /// True when there ARE products but none match the current
  /// search/category filter — distinct copy from a genuinely empty
  /// catalog so an admin/member isn't told "no products yet" when
  /// really it's just their filter that's too narrow.
  final bool noMatch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = noMatch
        ? 'No matching products'
        : (isAdmin ? 'No products yet' : 'No merchandise yet');
    final message = noMatch
        ? 'Try a different search term or category.'
        : (isAdmin
            ? 'Tap "Add Product" to create the first one.'
            : 'Check back soon — merchandise is on the way.');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              noMatch ? Icons.search_off_rounded : Icons.shopping_bag_outlined,
              size: 56,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
