import 'package:doon_walkers/core/design_system.dart';
import 'package:flutter/material.dart';

/// Shared empty-state card for Home's Upcoming Trek / Featured Trek /
/// Recent Memories sections.
///
/// Still a pure placeholder: Home does not query `treks` or `gallery`
/// (that's a later, separate data-wiring decision), so this always
/// renders — it is not the "no rows found" branch of a real query, and it
/// keeps Home honest about what exists today rather than showing
/// fabricated trek data.
///
/// The redesign swaps the old flat card for a glass card that *previews
/// the shape of what will live here*: a dimmed, shimmering ghost of the
/// future content (a cover strip + text lines, or a photo grid) sits
/// behind a centered icon-and-message. That reads as "content is coming
/// to this exact spot", which a plain grey box never did.
class TrekSectionPlaceholder extends StatelessWidget {
  const TrekSectionPlaceholder({
    super.key,
    required this.icon,
    required this.message,
    this.accent = AppColors.primary,
    this.preview = PlaceholderPreview.trekCard,
  });

  final IconData icon;
  final String message;
  final Color accent;

  /// Which ghost shape to shimmer behind the message.
  final PlaceholderPreview preview;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blurEnabled: false,
      glowColor: accent,
      glowOpacity: 0.10,
      padding: EdgeInsets.zero,
      borderRadius: AppRadius.lg,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The faint, shimmering "ghost" of future content. It lays out
          // at its natural height (via OverflowBox) anchored to the top and
          // is clipped by the card — the Stack's own height is driven by
          // the message below, so the ghost mustn't be forced to fit it.
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: OverflowBox(
                minHeight: 0,
                maxHeight: double.infinity,
                alignment: Alignment.topCenter,
                child: Opacity(
                  opacity: 0.35,
                  child: switch (preview) {
                    PlaceholderPreview.trekCard => const _GhostTrekCard(),
                    PlaceholderPreview.photoGrid => const _GhostPhotoGrid(),
                  },
                ),
              ),
            ),
          ),
          // The message, on a soft scrim so it stays readable over the ghost.
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xxxl,
              horizontal: AppSpacing.xl,
            ),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.9,
                colors: [
                  AppColors.card.withValues(alpha: 0.85),
                  AppColors.card.withValues(alpha: 0.35),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withValues(alpha: 0.35)),
                  ),
                  child: AppIcon(icon, size: 26, color: accent),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The shape of the future content a placeholder is standing in for.
enum PlaceholderPreview { trekCard, photoGrid }

class _GhostTrekCard extends StatelessWidget {
  const _GhostTrekCard();

  @override
  Widget build(BuildContext context) {
    return const Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkeletonBox(height: 96, borderRadius: 0),
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 160, height: 16),
                SizedBox(height: AppSpacing.sm),
                SkeletonText(lines: 2, lineHeight: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GhostPhotoGrid extends StatelessWidget {
  const _GhostPhotoGrid();

  @override
  Widget build(BuildContext context) {
    return const Shimmer(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: SkeletonBox(height: 120, borderRadius: AppRadius.sm)),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: SkeletonBox(height: 120, borderRadius: AppRadius.sm)),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: SkeletonBox(height: 120, borderRadius: AppRadius.sm)),
          ],
        ),
      ),
    );
  }
}
