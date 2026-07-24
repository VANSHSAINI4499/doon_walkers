import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/product.dart';
import 'package:flutter/material.dart';

/// Small tinted pill showing a product's category. Uses the brand primary
/// for every category (categories aren't a severity scale like trek
/// difficulty, so there's no meaningful colour-per-value). Restyled onto
/// the design system's pill.
class ProductCategoryBadge extends StatelessWidget {
  const ProductCategoryBadge({super.key, required this.category, this.dense = false});

  final ProductCategory category;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : AppSpacing.md,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Text(
        category.label,
        style: AppTextStyles.tinted(
          dense ? AppTextStyles.labelSmall : AppTextStyles.labelMedium,
          AppColors.primary,
        ),
      ),
    );
  }
}
