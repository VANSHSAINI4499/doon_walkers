import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:doon_walkers/features/trek_library/presentation/widgets/difficulty_badge.dart';
import 'package:flutter/material.dart';

/// Card summary for a trek in the public library grid — cover image,
/// title, difficulty badge, distance/duration at a glance.
///
/// The same card serves every role. [adminActions] is the only
/// role-dependent part: the Trek Library screen passes a
/// [TrekAdminActions] menu when the viewer is an admin and `null`
/// otherwise, so guests and members see an identical card with no admin
/// affordances rather than a separate screen.
///
/// Redesign Phase 3: rebuilt on the design system. Badge *logic* is
/// unchanged — the draft marker still shows only in an admin view of an
/// unpublished trek, and the "Upcoming" pill still keys off
/// [Trek.isUpcoming] (automatic from `trek_date`, never a manual flag).
/// Only the visual treatment changed. The card is still driven by its own
/// intrinsic height so the masonry grid can pack varied-length
/// descriptions without clipping or wasted space — every text child below
/// caps itself with `maxLines`/ellipsis and the outer column shrink-wraps.
class TrekCard extends StatelessWidget {
  const TrekCard({
    super.key,
    required this.trek,
    required this.onTap,
    this.adminActions,
  });

  final Trek trek;
  final VoidCallback onTap;

  /// Admin-only overlay menu; `null` for non-admin viewers.
  final Widget? adminActions;

  @override
  Widget build(BuildContext context) {
    final coverImage = trek.coverImage;
    final isAdminView = adminActions != null;

    return GlassCard(
      onTap: onTap,
      blurEnabled: false,
      padding: EdgeInsets.zero,
      borderRadius: AppRadius.card,
      glowColor: trek.isUpcoming ? AppColors.primary : null,
      glowOpacity: 0.14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppHero(
                  tag: AppHeroTags.trekCover(trek.id),
                  fromRadius: AppRadius.card,
                  toRadius: 0,
                  child: (coverImage == null || coverImage.isEmpty)
                      ? const _CoverPlaceholder()
                      : Image.network(
                          coverImage,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => const _CoverPlaceholder(),
                        ),
                ),
                // A soft top-down scrim so light overlays (draft marker,
                // admin menu) stay legible over a bright photo.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [Color(0x66000000), Color(0x00000000)],
                    ),
                  ),
                ),
                // Draft marker — only meaningful to an admin, since RLS
                // never returns unpublished treks to anyone else.
                if (isAdminView && !trek.isPublished)
                  const Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: _CardBadge(
                      icon: AppIcons.editNote,
                      label: 'Draft',
                      background: Color(0xCC000000),
                      foreground: AppColors.white,
                    ),
                  ),
                if (isAdminView)
                  Positioned(
                    top: AppSpacing.xs,
                    right: AppSpacing.xs,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: adminActions!,
                    ),
                  ),
                // Bottom-left so it never collides with the draft marker
                // (top-left) or the admin actions menu (top-right).
                // Automatic from trek_date — see Trek.isUpcoming.
                if (trek.isUpcoming)
                  const Positioned(
                    bottom: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: _CardBadge(
                      icon: AppIcons.eventAvailable,
                      label: 'Upcoming',
                      background: AppColors.primary,
                      foreground: AppColors.onPrimary,
                      glow: true,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        trek.title,
                        style: AppTextStyles.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    DifficultyBadge(difficulty: trek.difficulty, dense: true),
                  ],
                ),
                if (trek.description.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    trek.description.trim(),
                    style: AppTextStyles.secondary(AppTextStyles.bodySmall),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (trek.distanceKm != null || trek.durationDays != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  // Wrap, not Row — on a narrow masonry column two chips
                  // don't reliably fit side by side; Wrap drops the second
                  // to its own line, which the content-driven masonry cell
                  // handles cleanly.
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if (trek.distanceKm != null)
                        _FactChip(
                          icon: AppIcons.distance,
                          label: '${_formatDistance(trek.distanceKm!)} km',
                        ),
                      if (trek.durationDays != null)
                        _FactChip(
                          icon: AppIcons.duration,
                          label: '${trek.durationDays} ${trek.durationDays == 1 ? 'day' : 'days'}',
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDistance(double km) => km % 1 == 0 ? km.toStringAsFixed(0) : km.toStringAsFixed(1);
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16302A), AppColors.card],
        ),
      ),
      child: Center(
        child: AppIcon(AppIcons.landscape, size: 40, color: AppColors.textDisabled),
      ),
    );
  }
}

/// A pill badge overlaid on the cover image (draft / upcoming markers).
class _CardBadge extends StatelessWidget {
  const _CardBadge({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    this.glow = false,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: glow ? AppShadows.glow(background, opacity: 0.5, radius: 12) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 12, color: foreground),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: AppTextStyles.tinted(AppTextStyles.labelSmall, foreground)),
        ],
      ),
    );
  }
}

/// Small tinted pill for a distance/duration fact.
class _FactChip extends StatelessWidget {
  const _FactChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.cardHigh,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 13, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: AppTextStyles.labelSmall),
        ],
      ),
    );
  }
}
