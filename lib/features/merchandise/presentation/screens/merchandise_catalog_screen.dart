import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/product.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/product_providers.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/product_admin_actions.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/product_card.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/product_search_filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

/// Merchandise Catalog — one shared screen for every role, same shape as
/// Trek Library: guests/members see active products only, an admin sees the
/// same screen plus inline management (drafts included and marked, a
/// per-product actions menu, an "Add Product" button).
///
/// A top-level route outside the bottom-nav shell — reached via the
/// Navigation Drawer, not a tab. **Redesign Phase 6 keeps that placement
/// unchanged** (nothing in the Profile/Home redesign changed the reasoning
/// for it); it only restyles the screen onto the design system (skeleton
/// loading, glass product cards, a gradient add-product button). The role
/// split, the client-side search/category filter, and the masonry layout
/// are all unchanged.
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

  /// Client-side search + category filter — unchanged.
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
    final isAdmin = ref.watch(isAdminProvider);
    final productsProvider = isAdmin ? adminAllProductsProvider : activeProductsProvider;
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Merchandise')),
      floatingActionButton: isAdmin
          ? _AddProductFab(onTap: () => context.push(AppConstants.routeMerchandiseNew))
          : null,
      body: SafeArea(
        child: productsAsync.when(
          loading: () => const _CatalogSkeleton(),
          error: (error, stack) {
            debugPrint('MerchandiseCatalogScreen: failed to load products: $error');
            return _CatalogError(onRetry: () => ref.invalidate(productsProvider));
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
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
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
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        isAdmin ? 96 : AppSpacing.lg,
                      ),
                      // A true sliver masonry grid — name/description length
                      // varies product to product, same card-height lesson
                      // as the Trek Library grid: content-driven cell height,
                      // not a fixed aspect ratio.
                      sliver: SliverMasonryGrid.extent(
                        maxCrossAxisExtent: 340,
                        mainAxisSpacing: AppSpacing.lg,
                        crossAxisSpacing: AppSpacing.lg,
                        childCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return AppReveal(
                            index: index.clamp(0, 8),
                            child: ProductCard(
                              product: product,
                              onTap: () =>
                                  context.push(AppConstants.merchandiseDetailLocation(product.id)),
                              adminActions: isAdmin ? ProductAdminActions(product: product) : null,
                            ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, AppSpacing.xxl),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF15241B), AppColors.background],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.glow(AppColors.primary, opacity: 0.35, radius: 16),
            ),
            child: const AppIcon(AppIcons.store, size: 28, color: AppColors.onPrimary),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WEAR YOUR TRAIL PRIDE', style: AppTextStyles.tinted(AppTextStyles.overline, AppColors.primaryLight)),
                const SizedBox(height: AppSpacing.xs),
                Text('Doon Walkers Merchandise', style: AppTextStyles.headlineSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient "Add Product" button — the design system's extended FAB.
class _AddProductFab extends StatelessWidget {
  const _AddProductFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
          borderRadius: BorderRadius.circular(AppRadius.button),
          boxShadow: AppShadows.button(AppColors.primary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(AppIcons.add, size: 22, color: AppColors.onPrimary),
            const SizedBox(width: AppSpacing.sm),
            Text('Add Product', style: AppTextStyles.tinted(AppTextStyles.labelLarge, AppColors.onPrimary)),
          ],
        ),
      ),
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(AppIcons.error, size: 44, color: AppColors.danger),
            const SizedBox(height: AppSpacing.md),
            Text('Could not load merchandise.', style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xl),
            PremiumButton(
              label: 'Retry',
              icon: AppIcons.refresh,
              variant: PremiumButtonVariant.glass,
              size: PremiumButtonSize.small,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog({required this.isAdmin, required this.noMatch});

  final bool isAdmin;

  /// True when there ARE products but none match the current filter —
  /// distinct copy from a genuinely empty catalog.
  final bool noMatch;

  @override
  Widget build(BuildContext context) {
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
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: AppIcon(noMatch ? AppIcons.searchOff : AppIcons.bag, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: AppTextStyles.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Product-card-shaped placeholders while the catalog loads.
class _CatalogSkeleton extends StatelessWidget {
  const _CatalogSkeleton();

  static const _imageHeights = [170.0, 150.0, 150.0, 180.0, 160.0, 150.0];

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: MasonryGridView.count(
        crossAxisCount: 2,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        mainAxisSpacing: AppSpacing.lg,
        crossAxisSpacing: AppSpacing.lg,
        itemCount: _imageHeights.length,
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.glassBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SkeletonBox(height: _imageHeights[index], borderRadius: 0),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SkeletonBox(width: 120, height: 16),
                    const SizedBox(height: AppSpacing.sm),
                    const SkeletonBox(width: 70, height: 22, borderRadius: AppRadius.pill),
                    if (index.isEven) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const SkeletonText(lines: 2, lineHeight: 10),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    const SkeletonBox(width: 60, height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
