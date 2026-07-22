import 'package:flutter/material.dart';

/// "In Stock" / "Out of Stock" pill — deliberately never shows the
/// underlying number (see [Product.isInStock]'s doc): a shopper
/// browsing the catalog has no legitimate need to know exact inventory
/// counts, so this only ever renders the boolean.
class StockStatusBadge extends StatelessWidget {
  const StockStatusBadge({super.key, required this.isInStock, this.dense = false});

  final bool isInStock;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isInStock ? theme.colorScheme.primary : theme.colorScheme.error;
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isInStock ? Icons.check_circle_outline_rounded : Icons.remove_circle_outline_rounded,
            size: dense ? 12 : 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isInStock ? 'In Stock' : 'Out of Stock',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
