import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/product.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/product_category_badge.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/stock_status_badge.dart';
import 'package:flutter/material.dart';

/// Card summary for a product in the public catalog grid — cover photo,
/// name, category badge, price, stock status, and a short description
/// snippet.
///
/// Redesign Phase 6: rebuilt on the design system, mirroring TrekCard.
/// [adminActions] is the only role-dependent part; the draft marker still
/// shows only in an admin view of an inactive product, and every text
/// child stays capped so the masonry grid packs varied-length
/// names/descriptions without clipping or wasted space.
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
    final coverImage = product.coverImageUrl;
    final isAdminView = adminActions != null;

    return GlassCard(
      onTap: onTap,
      blurEnabled: false,
      padding: EdgeInsets.zero,
      borderRadius: AppRadius.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppHero(
                  tag: AppHeroTags.productImage(product.id),
                  fromRadius: AppRadius.card,
                  toRadius: 0,
                  child: (coverImage == null || coverImage.isEmpty)
                      ? const _CoverPlaceholder()
                      : Image.network(
                          coverImage,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => const _CoverPlaceholder(),
                        ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [Color(0x66000000), Color(0x00000000)],
                    ),
                  ),
                ),
                // Draft marker — only meaningful to an admin, since RLS
                // never returns inactive products to anyone else.
                if (isAdminView && !product.isActive)
                  const Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: _DraftBadge(),
                  ),
                if (isAdminView)
                  Positioned(
                    top: AppSpacing.xs,
                    right: AppSpacing.xs,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: adminActions!,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name,
                  style: AppTextStyles.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    ProductCategoryBadge(category: product.category, dense: true),
                    StockStatusBadge(isInStock: product.isInStock, dense: true),
                  ],
                ),
                if (product.description.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    product.description.trim(),
                    style: AppTextStyles.secondary(AppTextStyles.bodySmall),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(
                  _formatPrice(product.price),
                  style: AppTextStyles.tinted(AppTextStyles.titleMedium, AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) => '₹${price % 1 == 0 ? price.toStringAsFixed(0) : price.toStringAsFixed(2)}';
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2A24), AppColors.card],
        ),
      ),
      child: Center(
        child: AppIcon(AppIcons.bag, size: 40, color: AppColors.textDisabled),
      ),
    );
  }
}

class _DraftBadge extends StatelessWidget {
  const _DraftBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppIcon(AppIcons.editNote, size: 12, color: AppColors.white),
          const SizedBox(width: AppSpacing.xs),
          Text('Draft', style: AppTextStyles.tinted(AppTextStyles.labelSmall, AppColors.white)),
        ],
      ),
    );
  }
}
