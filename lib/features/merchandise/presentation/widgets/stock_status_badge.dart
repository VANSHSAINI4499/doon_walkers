import 'package:doon_walkers/core/design_system.dart';
import 'package:flutter/material.dart';

/// "In Stock" / "Out of Stock" pill — deliberately never shows the
/// underlying number (privacy rule preserved): a shopper browsing the
/// catalog has no legitimate need for exact inventory counts, so this only
/// ever renders the boolean. Restyled onto the design system's pill.
class StockStatusBadge extends StatelessWidget {
  const StockStatusBadge({super.key, required this.isInStock, this.dense = false});

  final bool isInStock;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = isInStock ? AppColors.primary : AppColors.danger;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : AppSpacing.md,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            isInStock ? AppIcons.checkCircle : AppIcons.removeCircle,
            size: dense ? 12 : 14,
            color: color,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            isInStock ? 'In Stock' : 'Out of Stock',
            style: AppTextStyles.tinted(
              dense ? AppTextStyles.labelSmall : AppTextStyles.labelMedium,
              color,
            ),
          ),
        ],
      ),
    );
  }
}
