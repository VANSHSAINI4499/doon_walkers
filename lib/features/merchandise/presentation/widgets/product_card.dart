import 'package:doon_walkers/features/merchandise/domain/entities/product.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/product_category_badge.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/stock_status_badge.dart';
import 'package:flutter/material.dart';

/// Card summary for a product in the public catalog grid — cover
/// photo, name, category badge, price, stock status, and a short
/// description snippet.
///
/// The same card serves every role. [adminActions] is the only
/// role-dependent part: the catalog screen passes a
/// [ProductAdminActions] menu when the viewer is an admin and `null`
/// otherwise, so guests and members see an identical card with no
/// admin affordances.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.adminActions,
  });

  final Product product;
  final VoidCallback onTap;

  /// Admin-only overlay menu; `null` for non-admin viewers.
  final Widget? adminActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverImage = product.coverImageUrl;
    final isAdminView = adminActions != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  (coverImage == null || coverImage.isEmpty)
                      ? const _CoverPlaceholder()
                      : Image.network(
                          coverImage,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => const _CoverPlaceholder(),
                        ),
                  // Draft marker — only meaningful to an admin, since
                  // RLS never returns inactive products to anyone else.
                  if (isAdminView && !product.isActive)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(160),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_note_rounded, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Draft',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (isAdminView)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(90),
                          shape: BoxShape.circle,
                        ),
                        child: adminActions!,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                // Every text child below caps itself with maxLines and
                // TextOverflow.ellipsis, so intrinsic height stays
                // bounded regardless of name/description length — the
                // masonry grid (see the catalog screen) sizes each
                // card to its own content instead of a fixed ratio, the
                // same fix already proven on the Trek Library grid.
                children: [
                  Text(
                    product.name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ProductCategoryBadge(category: product.category, dense: true),
                      StockStatusBadge(isInStock: product.isInStock, dense: true),
                    ],
                  ),
                  if (product.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      product.description.trim(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    _formatPrice(product.price),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price) => '₹${price % 1 == 0 ? price.toStringAsFixed(0) : price.toStringAsFixed(2)}';
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.shopping_bag_outlined,
        size: 40,
        color: theme.colorScheme.outline,
      ),
    );
  }
}
