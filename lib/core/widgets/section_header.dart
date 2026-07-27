import 'package:doon_walkers/core/design_system.dart';
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
    final palette = AppPalette.of(context);
    return Row(
      children: [
        if (icon != null) ...[
          AppIcon(icon!, size: 20, color: palette.primary),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(
          title,
          style: AppTextStyles.titleLarge.copyWith(color: palette.textPrimary),
        ),
      ],
    );
  }
}
