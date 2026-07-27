import 'package:doon_walkers/core/design_system.dart';
import 'package:flutter/material.dart';

/// Square grid tile for a single product photo. Mirrors
/// [MediaThumbnail]'s photo branch exactly — no video case here, every
/// `product_images` row is always a photo (see the migration's bucket
/// mime-type restriction).
class ProductImageThumbnail extends StatelessWidget {
  const ProductImageThumbnail({super.key, required this.imageUrl, this.onTap});

  final String imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          color: palette.cardHigh,
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder:
                (context, error, stack) =>
                    AppIcon(AppIcons.imageBroken, color: palette.textSecondary),
          ),
        ),
      ),
    );
  }
}
