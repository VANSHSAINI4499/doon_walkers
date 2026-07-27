import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/gallery/presentation/screens/photo_viewer_screen.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/product.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/product_providers.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/product_image_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A [ProductImageThumbnail] with an inline admin delete affordance
/// layered on top — mirrors [MediaAdminOverlay] exactly, same
/// one-to-many-media-on-a-detail-page pattern as the trek gallery.
class ProductImageAdminOverlay extends ConsumerStatefulWidget {
  const ProductImageAdminOverlay({
    super.key,
    required this.image,
    required this.productName,
  });

  final ProductImage image;

  /// Shown in the confirmation dialog so an admin can tell which
  /// product's photo they're removing.
  final String productName;

  @override
  ConsumerState<ProductImageAdminOverlay> createState() =>
      _ProductImageAdminOverlayState();
}

class _ProductImageAdminOverlayState
    extends ConsumerState<ProductImageAdminOverlay> {
  bool _isPending = false;

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Delete photo?'),
            content: Text(
              'This permanently removes this photo from '
              '"${widget.productName}", including the file in Storage. '
              'This cannot be undone.',
            ),
            actions: [
              PremiumButton(
                label: 'Cancel',
                variant: PremiumButtonVariant.glass,
                size: PremiumButtonSize.small,
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
              PremiumButton(
                label: 'Delete',
                icon: AppIcons.delete,
                variant: PremiumButtonVariant.danger,
                size: PremiumButtonSize.small,
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isPending = true);
    final success = await ref
        .read(productImageAdminControllerProvider.notifier)
        .deleteImage(widget.image.id);
    if (!mounted) return;
    setState(() => _isPending = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not delete photo. Please try again.'),
          backgroundColor: AppPalette.of(context).danger,
        ),
      );
      return;
    }

    // One-shot fetch — refetch the product's own detail (images live
    // nested inside it, see ProductRepository's joined select).
    ref.invalidate(productByIdProvider(widget.image.productId));
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: ProductImageThumbnail(
            imageUrl: widget.image.imageUrl,
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            PhotoViewerScreen(imageUrl: widget.image.imageUrl),
                  ),
                ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child:
              _isPending
                  ? Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: palette.scrim,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.textPrimary,
                      ),
                    ),
                  )
                  : Material(
                    color: palette.scrim,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _confirmDelete,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: AppIcon(
                          AppIcons.delete,
                          size: 18,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                  ),
        ),
      ],
    );
  }
}
