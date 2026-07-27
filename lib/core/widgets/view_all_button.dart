import 'package:doon_walkers/core/design_system.dart';
import 'package:flutter/material.dart';

/// A small, right-aligned "View All" tap target — the affordance
/// [PreviewSection] shows at the bottom-right of a dashboard preview
/// once its section has more items than are displayed, opening the
/// section's full list screen.
class ViewAllButton extends StatelessWidget {
  const ViewAllButton({
    super.key,
    this.label = 'View All',
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTextStyles.tinted(
                    AppTextStyles.labelMedium,
                    AppColors.primary,
                  ),
                ),
                const SizedBox(width: 2),
                const AppIcon(
                  AppIcons.chevronRight,
                  size: 16,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
