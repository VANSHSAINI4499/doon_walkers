import 'package:doon_walkers/core/design_system.dart';
import 'package:flutter/material.dart';

/// Section heading built on the Phase 1 design system — a gradient accent
/// bar, a filled Material Symbol, and the bold title type, with an
/// optional [accent] so consecutive sections can carry different hues.
///
/// This is the redesign's shared section header. It intentionally does
/// not replace the older `core/widgets/section_header.dart`, which is
/// still used by not-yet-redesigned screens (Merchandise Detail); that
/// one is left alone until its own phase. (Home carries a near-identical
/// local `HomeSectionHeader` from Phase 2 — a small, deliberate
/// duplication so this shared version can exist without editing Home.)
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    required this.icon,
    this.accent = AppColors.primary,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Color accent;

  /// Optional widget pinned to the header's right edge (a "see all" link,
  /// a count, etc.).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
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
          child: Text(
            title,
            style: AppTextStyles.titleLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
