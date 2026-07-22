import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/widgets/section_header.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/product.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/product_providers.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/product_admin_actions.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/product_category_badge.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/product_images_section.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/stock_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full product view. `product == null` covers two cases RLS makes
/// indistinguishable on purpose — the id doesn't exist, or it's a
/// draft a non-admin isn't allowed to see — both render the same
/// "not found" state rather than leaking which case it was. Mirrors
/// TrekDetailScreen's identical `trek == null` handling.
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productByIdProvider(productId));

    return Scaffold(
      body: productAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _DetailMessage(
          icon: Icons.error_outline_rounded,
          title: 'Could not load this product.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(productByIdProvider(productId)),
        ),
        data: (product) {
          if (product == null) {
            return const _DetailMessage(
              icon: Icons.search_off_rounded,
              title: 'Product not found.',
            );
          }
          return _ProductDetailBody(product: product, isAdmin: ref.watch(isAdminProvider));
        },
      ),
    );
  }
}

class _DetailMessage extends StatelessWidget {
  const _DetailMessage({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : null,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductDetailBody extends StatelessWidget {
  const _ProductDetailBody({required this.product, required this.isAdmin});

  final Product product;

  /// Drives whether inline management controls render. Same shared
  /// screen for every role — an admin just gets an extra actions menu
  /// and a draft banner; guests and members see neither.
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverImage = product.coverImageUrl;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          actions: [
            if (isAdmin)
              ProductAdminActions(
                product: product,
                iconColor: Colors.white,
                // The product this screen is showing no longer exists —
                // pop rather than sit on a dangling detail view.
                onDeleted: () {
                  if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                },
              ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: (coverImage == null || coverImage.isEmpty)
                ? Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      size: 64,
                      color: theme.colorScheme.outline,
                    ),
                  )
                : Image.network(
                    coverImage,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 48,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Only an admin can reach an inactive product at all
                    // (products_select gates it), so this banner doubles
                    // as a reminder that members can't see this page yet.
                    if (isAdmin && !product.isActive) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              size: 18,
                              color: theme.colorScheme.onTertiaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Draft — not visible to members yet.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onTertiaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      product.name,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ProductCategoryBadge(category: product.category),
                        StockStatusBadge(isInStock: product.isInStock),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _formatPrice(product.price),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (product.hasVariants) ...[
                      const SectionHeader(title: 'Available Sizes', icon: Icons.straighten_rounded),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: product.variants
                            .map((v) => _SizeChip(variant: v))
                            .toList(),
                      ),
                      const SizedBox(height: 28),
                    ],

                    if (product.description.trim().isNotEmpty) ...[
                      const SectionHeader(title: 'Description', icon: Icons.menu_book_outlined),
                      const SizedBox(height: 12),
                      Text(
                        product.description,
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                      ),
                      const SizedBox(height: 28),
                    ],

                    // Buy Now / checkout is M2 scope — this is a
                    // deliberate disabled placeholder rather than an
                    // omitted button, so the purchase path is visibly
                    // "coming soon" rather than silently absent. Admins
                    // manage the catalog, they don't buy from it — same
                    // convention as TrekRegisterButton not rendering a
                    // CTA for them at all.
                    if (!isAdmin) ...[
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: null,
                              icon: const Icon(Icons.shopping_cart_outlined),
                              label: const Text('Buy Now — Coming Soon'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                    ],

                    const Divider(),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Photos', icon: Icons.photo_library_outlined),
                    const SizedBox(height: 12),
                    ProductImagesSection(
                      productId: product.id,
                      productName: product.name,
                      images: product.images,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatPrice(double price) =>
      '₹${price % 1 == 0 ? price.toStringAsFixed(0) : price.toStringAsFixed(2)}';
}

class _SizeChip extends StatelessWidget {
  const _SizeChip({required this.variant});

  final ProductVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = variant.isInStock ? theme.colorScheme.outline : theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(120)),
        color: variant.isInStock ? null : theme.colorScheme.errorContainer.withAlpha(60),
      ),
      child: Text(
        variant.size,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: variant.isInStock ? theme.colorScheme.onSurface : theme.colorScheme.error,
          decoration: variant.isInStock ? null : TextDecoration.lineThrough,
        ),
      ),
    );
  }
}
