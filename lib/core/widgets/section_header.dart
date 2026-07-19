import 'package:doon_walkers/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Small heading used above a content section (Home's stat/trek blocks,
/// About's story/vision/mission blocks, etc.) — kept in core/widgets
/// since more than one feature uses the same shape.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.icon});

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: AppTextStyles.titleLarge.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
