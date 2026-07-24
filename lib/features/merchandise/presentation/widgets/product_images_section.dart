import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/gallery/presentation/screens/photo_viewer_screen.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/product.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/product_image_admin_overlay.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/product_image_thumbnail.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/product_image_upload_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Photo grid for a single product — the Product Detail screen's "Photos"
/// section. Same section for every role; an admin additionally gets an
/// inline "Add" button and per-photo delete controls. [images] is already
/// loaded with the product, so this takes the list directly.
///
/// Redesign Phase 6 restyles the empty state and the add button; the photo
/// grid, per-photo admin overlay, and upload flow are unchanged.
class ProductImagesSection extends ConsumerWidget {
  const ProductImagesSection({
    super.key,
    required this.productId,
    required this.productName,
    required this.images,
  });

  final String productId;

  /// Used in the delete confirmation copy.
  final String productName;
  final List<ProductImage> images;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);

    final addButton = isAdmin
        ? Align(
            alignment: Alignment.centerLeft,
            child: PremiumButton(
              label: 'Add Photo',
              icon: AppIcons.addPhoto,
              variant: PremiumButtonVariant.glass,
              size: PremiumButtonSize.small,
              onPressed: () => showProductImageUploadSheet(context, productId: productId),
            ),
          )
        : null;

    if (images.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            blurEnabled: false,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              children: [
                const AppIcon(AppIcons.photo, size: 22, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'No photos for this product yet.',
                    style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
                  ),
                ),
              ],
            ),
          ),
          if (addButton != null) ...[
            const SizedBox(height: AppSpacing.md),
            addButton,
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) {
            final image = images[index];
            return isAdmin
                ? ProductImageAdminOverlay(image: image, productName: productName)
                : ProductImageThumbnail(
                    imageUrl: image.imageUrl,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => PhotoViewerScreen(imageUrl: image.imageUrl),
                      ),
                    ),
                  );
          },
        ),
        if (addButton != null) ...[
          const SizedBox(height: AppSpacing.md),
          addButton,
        ],
      ],
    );
  }
}
