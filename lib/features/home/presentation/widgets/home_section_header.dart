import 'package:doon_walkers/core/design_system.dart';
import 'package:flutter/material.dart';

/// Section heading for the redesigned Home screen.
///
/// A Home-local header rather than the shared core [SectionHeader]: that
/// one is still used by out-of-scope screens (Trek Detail, Product
/// Detail) whose own redesign phases haven't run yet, so it's left
/// untouched. This version is built entirely from the Phase 1 design
/// system — a gradient accent bar, a filled Material Symbol, and the bold
/// title type — and takes an [accent] so consecutive sections can carry
/// different hues (Upcoming green, Featured gold, Memories blue) for
/// rhythm down the page.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.accent = AppColors.primary,
    this.overline,
  });

  final String title;
  final IconData icon;
  final Color accent;

  /// Optional wide-tracked eyebrow above the title ("YOUR TRAILS").
  final String? overline;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 4,
          height: overline == null ? 22 : 34,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [accent, accent.withValues(alpha: 0.35)],
            ),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        AppIcon(icon, size: 22, color: accent),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (overline != null)
                Text(
                  overline!.toUpperCase(),
                  style: AppTextStyles.tinted(AppTextStyles.overline, accent),
                ),
              Text(
                title,
                style: AppTextStyles.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
