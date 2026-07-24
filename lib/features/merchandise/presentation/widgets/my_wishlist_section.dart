import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/widgets/glass_states.dart';
import 'package:doon_walkers/core/widgets/section_title.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/wishlist_item.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/wishlist_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// "My Wishlist" on Profile — the signed-in user's own wishlisted
/// products, with a self-service remove action.
///
/// Redesign Phase 5 restyles this onto the design system. The add/remove
/// behaviour, the navigate-to-detail tap, and the scoping are unchanged.
class MyWishlistSection extends ConsumerWidget {
  const MyWishlistSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlistAsync = ref.watch(myWishlistProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(title: 'My Wishlist', icon: AppIcons.favorite, accent: AppColors.danger),
        const SizedBox(height: AppSpacing.md),
        wishlistAsync.when(
          loading: () => const SkeletonList(count: 2, showImages: false, padding: EdgeInsets.zero),
          error: (error, stack) {
            debugPrint('MyWishlistSection: failed to load wishlist: $error');
            return GlassSectionError(
              message: 'Could not load your wishlist.',
              onRetry: () => ref.invalidate(myWishlistProvider),
            );
          },
          data: (items) {
            if (items.isEmpty) return const _EmptyWishlist();
            return Column(
              children: [
                for (final item in items) ...[
                  _WishlistTile(item: item),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _EmptyWishlist extends StatelessWidget {
  const _EmptyWishlist();

  @override
  Widget build(BuildContext context) {
    return GlassEmptyState(
      icon: AppIcons.favorite,
      message: "You haven't wishlisted anything yet.",
      actionLabel: 'Browse Merchandise',
      onAction: () => context.push(AppConstants.routeMerchandise),
    );
  }
}

class _WishlistTile extends ConsumerStatefulWidget {
  const _WishlistTile({required this.item});

  final WishlistItem item;

  @override
  ConsumerState<_WishlistTile> createState() => _WishlistTileState();
}

class _WishlistTileState extends ConsumerState<_WishlistTile> {
  bool _isPending = false;

  Future<void> _remove() async {
    setState(() => _isPending = true);
    final success =
        await ref.read(wishlistControllerProvider.notifier).remove(widget.item.productId);
    if (!mounted) return;
    setState(() => _isPending = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Removed from your wishlist.' : 'Could not remove this item. Please try again.',
        ),
        backgroundColor: success ? null : AppColors.danger,
      ),
    );
  }

  String _formatPrice(double price) =>
      '₹${price % 1 == 0 ? price.toStringAsFixed(0) : price.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final product = widget.item.product;
    final coverImage = product.coverImageUrl;

    return GlassCard(
      blurEnabled: false,
      onTap: () => context.push(AppConstants.merchandiseDetailLocation(product.id)),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SizedBox(
              width: 56,
              height: 56,
              child: (coverImage == null || coverImage.isEmpty)
                  ? const _ThumbFallback(icon: AppIcons.bag)
                  : Image.network(
                      coverImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) =>
                          const _ThumbFallback(icon: AppIcons.imageBroken),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: AppTextStyles.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatPrice(product.price),
                  style: AppTextStyles.tinted(AppTextStyles.titleSmall, AppColors.primary),
                ),
              ],
            ),
          ),
          _isPending
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  child: SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.danger),
                  ),
                )
              : IconButton(
                  onPressed: _remove,
                  tooltip: 'Remove from wishlist',
                  icon: const AppIcon(AppIcons.favorite, color: AppColors.danger),
                ),
        ],
      ),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cardHigh,
      alignment: Alignment.center,
      child: AppIcon(icon, size: 22, color: AppColors.textDisabled),
    );
  }
}
