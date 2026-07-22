import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/gallery/presentation/screens/photo_viewer_screen.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/product.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/product_image_admin_overlay.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/product_image_thumbnail.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/product_image_upload_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Photo grid for a single product — the Product Detail screen's
/// "Photos" section. Mirrors [TrekGallerySection] exactly: same section
/// for every role, admin additionally gets an inline "Add" button and
/// per-photo delete controls. [images] is already loaded as part of the
/// product (see ProductRepository's joined select), so this widget
/// takes the list directly rather than watching its own provider.
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
    final theme = Theme.of(context);
    final isAdmin = ref.watch(isAdminProvider);

    final addButton = isAdmin
        ? Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => showProductImageUploadSheet(context, productId: productId),
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('Add Photo'),
            ),
          )
        : null;

    if (images.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No photos for this product yet.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          if (addButton != null) addButton,
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
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
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
          const SizedBox(height: 12),
          addButton,
        ],
      ],
    );
  }
}
