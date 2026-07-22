import 'package:doon_walkers/features/merchandise/domain/entities/product.dart';
import 'package:flutter/material.dart';

/// Small tinted pill showing a product's category — mirrors
/// [DifficultyBadge]'s tinted-fill-plus-outline treatment, but uses the
/// theme's primary colour for every category rather than a per-value
/// palette (categories aren't a severity scale the way trek difficulty
/// is, so there's no meaningful colour-per-value to assign).
class ProductCategoryBadge extends StatelessWidget {
  const ProductCategoryBadge({super.key, required this.category, this.dense = false});

  final ProductCategory category;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Text(
        category.label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
