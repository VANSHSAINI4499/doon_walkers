import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/wishlist_item.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/wishlist_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// "My Wishlist" on Profile — the signed-in user's own wishlisted
/// products, with a self-service remove action. Mirrors
/// [MyRegistrationsSection]'s shape exactly (list of simple cards, not
/// a product grid — this is Profile's own list style, not the
/// Merchandise catalog's masonry grid).
class MyWishlistSection extends ConsumerWidget {
  const MyWishlistSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final wishlistAsync = ref.watch(myWishlistProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.favorite_outline_rounded, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'My Wishlist',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        wishlistAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) {
            debugPrint('MyWishlistSection: failed to load wishlist: $error');
            return Row(
              children: [
                Expanded(
                  child: Text(
                    'Could not load your wishlist.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(myWishlistProvider),
                  child: const Text('Retry'),
                ),
              ],
            );
          },
          data: (items) {
            if (items.isEmpty) return const _EmptyWishlist();
            return Column(
              children: [
                for (final item in items) ...[
                  _WishlistTile(item: item),
                  const SizedBox(height: 12),
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
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.favorite_border_rounded, size: 32, color: theme.colorScheme.outline),
          const SizedBox(height: 10),
          Text(
            "You haven't wishlisted anything yet.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => context.push(AppConstants.routeMerchandise),
            child: const Text('Browse Merchandise'),
          ),
        ],
      ),
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
        backgroundColor: success ? null : Theme.of(context).colorScheme.error,
      ),
    );
  }

  String _formatPrice(double price) =>
      '₹${price % 1 == 0 ? price.toStringAsFixed(0) : price.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = widget.item.product;
    final coverImage = product.coverImageUrl;

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppConstants.merchandiseDetailLocation(product.id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: (coverImage == null || coverImage.isEmpty)
                      ? Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            size: 24,
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
                              size: 20,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatPrice(product.price),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              _isPending
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      onPressed: _remove,
                      tooltip: 'Remove from wishlist',
                      icon: Icon(Icons.favorite_rounded, color: theme.colorScheme.error),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
