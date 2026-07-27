import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/widgets/preview_section.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/wishlist_item.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/wishlist_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// "My Wishlist" on Profile — a dashboard preview of the signed-in
/// user's 2 most recently wishlisted products, with self-service
/// remove and a "View All" link to [WishlistScreen] once there are
/// more than 2.
///
/// The full-list behaviour (add/remove, navigate-to-detail tap,
/// scoping) is unchanged from the previous full-list version — only
/// how much of it Profile shows inline has changed.
class MyWishlistSection extends ConsumerWidget {
  const MyWishlistSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlistAsync = ref.watch(myWishlistPreviewProvider);
    final palette = AppPalette.of(context);

    return PreviewSection<WishlistItem>(
      title: 'My Wishlist',
      icon: AppIcons.favorite,
      accent: palette.danger,
      asyncItems: wishlistAsync,
      itemBuilder: (item) => WishlistTile(item: item),
      onViewAll: () => context.push(AppConstants.routeMyWishlist),
      onRetry: () => ref.invalidate(myWishlistPreviewProvider),
      errorMessage: 'Could not load your wishlist.',
      emptyIcon: AppIcons.favorite,
      emptyMessage: "You haven't wishlisted anything yet.",
      emptyActionLabel: 'Browse Merchandise',
      onEmptyAction: () => context.push(AppConstants.routeMerchandise),
    );
  }
}

/// One wishlist row — shared by [MyWishlistSection]'s preview and
/// [WishlistScreen]'s full list.
class WishlistTile extends ConsumerStatefulWidget {
  const WishlistTile({super.key, required this.item});

  final WishlistItem item;

  @override
  ConsumerState<WishlistTile> createState() => _WishlistTileState();
}

class _WishlistTileState extends ConsumerState<WishlistTile> {
  bool _isPending = false;

  Future<void> _remove() async {
    final palette = AppPalette.of(context);
    setState(() => _isPending = true);
    final success = await ref
        .read(wishlistControllerProvider.notifier)
        .remove(widget.item.productId);
    if (!mounted) return;
    setState(() => _isPending = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Removed from your wishlist.'
              : 'Could not remove this item. Please try again.',
        ),
        backgroundColor: success ? null : palette.danger,
      ),
    );
  }

  String _formatPrice(double price) =>
      '₹${price % 1 == 0 ? price.toStringAsFixed(0) : price.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final product = widget.item.product;
    final coverImage = product.coverImageUrl;
    final palette = AppPalette.of(context);

    return AppCard(
      onTap:
          () =>
              context.push(AppConstants.merchandiseDetailLocation(product.id)),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SizedBox(
              width: 56,
              height: 56,
              child:
                  (coverImage == null || coverImage.isEmpty)
                      ? const _ThumbFallback(icon: AppIcons.bag)
                      : Image.network(
                        coverImage,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, error, stack) => const _ThumbFallback(
                              icon: AppIcons.imageBroken,
                            ),
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
                  style: AppTextStyles.tinted(
                    AppTextStyles.titleSmall,
                    palette.primary,
                  ),
                ),
              ],
            ),
          ),
          _isPending
              ? Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: palette.danger,
                  ),
                ),
              )
              : IconButton(
                onPressed: _remove,
                tooltip: 'Remove from wishlist',
                icon: AppIcon(AppIcons.favorite, color: palette.danger),
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
    final palette = AppPalette.of(context);
    return Container(
      color: palette.cardHigh,
      alignment: Alignment.center,
      child: AppIcon(icon, size: 22, color: palette.textDisabled),
    );
  }
}
