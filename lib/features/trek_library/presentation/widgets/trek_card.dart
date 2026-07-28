import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:doon_walkers/features/trek_library/presentation/providers/trek_providers.dart';
import 'package:doon_walkers/features/trek_library/presentation/widgets/difficulty_badge.dart';
import 'package:doon_walkers/features/trek_library/presentation/widgets/trek_status_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Card summary for a trek in the public library grid — cover image,
/// title, difficulty badge, date/distance/duration at a glance.
///
/// The same card serves every role. [adminActions] is the only
/// role-dependent part: the Trek Library screen passes a
/// [TrekAdminActions] menu when the viewer is an admin and `null`
/// otherwise, so guests and members see an identical card with no admin
/// affordances rather than a separate screen.
///
/// Redesign 2.0 Phase 15 restyles this calm (flat card, no glow) and adds
/// the trek's scheduled date as a fact chip — real data
/// ([Trek.trekDate]) that the card simply never surfaced before, even
/// though Trek Detail already showed it. Badge *logic* is unchanged: the
/// draft marker still shows only in an admin view of an unpublished trek,
/// and the "Upcoming" pill still keys off [Trek.isUpcoming] (automatic
/// from `trek_date`, never a manual flag).
///
/// ## What's still not here, on purpose
///
/// No "Spots Left" — `treks` has no capacity column, so a count would be
/// fabricated. No location name — the schema only has [Trek.googleMapLink]
/// (a raw URL, no place-name text), which is why Trek Detail's location
/// affordance is a maps-link button rather than a text line; this card
/// doesn't invent a name to show either. See TrekLibraryScreen's doc for
/// why there is still no Upcoming/Completed toggle on this grid.
///
/// The card is still driven by its own intrinsic height so the masonry
/// grid can pack varied-length descriptions without clipping or wasted
/// space — every text child below caps itself with `maxLines`/ellipsis
/// and the outer column shrink-wraps.
class TrekCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final coverImage = trek.coverImage;
    final isAdminView = adminActions != null;
    final spotsLeftAsync = ref.watch(trekSpotsLeftProvider(trek.id));

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      borderRadius: AppRadius.card,
      // A tinted hairline marks an upcoming trek — the calm replacement
      // for the glow this card used to cast for the same signal.
      borderColor:
          trek.isUpcoming ? palette.primary.withValues(alpha: 0.4) : null,
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
                  child:
                      (coverImage == null || coverImage.isEmpty)
                          ? const _CoverPlaceholder()
                          : Image.network(
                            coverImage,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stack) =>
                                    const _CoverPlaceholder(),
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
                      foreground: Colors.white,
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
                  Positioned(
                    bottom: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: _CardBadge(
                      icon: AppIcons.eventAvailable,
                      label: 'Upcoming',
                      background: palette.primary,
                      foreground: palette.onPrimary,
                    ),
                  ),
                // Bottom-right spots left / full badge overlay
                if (trek.isUpcoming && trek.isPublished)
                  Positioned(
                    bottom: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: spotsLeftAsync.maybeWhen(
                      data: (spots) {
                        final status = resolveTrekStatus(trek, spots);
                        if (status == TrekBookingStatus.open && spots == null) {
                          return const SizedBox.shrink();
                        }
                        final label = status == TrekBookingStatus.almostFull
                            ? '$spots left'
                            : (status == TrekBookingStatus.waitlist ? 'Waitlist' : status.label);
                        return _CardBadge(
                          icon: AppIcons.info,
                          label: label,
                          background: getTrekStatusColor(status, palette),
                          foreground: Colors.white,
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
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
                        style: AppTextStyles.titleMedium.copyWith(
                          color: palette.textPrimary,
                        ),
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
                    style: AppTextStyles.bodySmall.copyWith(
                      color: palette.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (trek.trekDate != null ||
                    trek.distanceKm != null ||
                    trek.durationDays != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  // Wrap, not Row — on a narrow masonry column, three
                  // chips don't reliably fit on one line; Wrap drops the
                  // overflow to its own line, which the content-driven
                  // masonry cell handles cleanly.
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      // First — matches Trek Detail's own ordering ("when"
                      // is the most decision-relevant fact once a trek
                      // has a real date). Never shown for a trek not yet
                      // backfilled with one, per Trek.trekDate's own doc.
                      if (trek.trekDate != null)
                        _FactChip(
                          icon: AppIcons.calendar,
                          label: _formatDate(trek.trekDate!),
                        ),
                      if (trek.distanceKm != null)
                        _FactChip(
                          icon: AppIcons.distance,
                          label: '${_formatDistance(trek.distanceKm!)} km',
                        ),
                      if (trek.durationDays != null)
                        _FactChip(
                          icon: AppIcons.duration,
                          label:
                              '${trek.durationDays} '
                              '${trek.durationDays == 1 ? 'day' : 'days'}',
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

  String _formatDistance(double km) =>
      km % 1 == 0 ? km.toStringAsFixed(0) : km.toStringAsFixed(1);

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatDate(DateTime dt) => '${dt.day} ${_months[dt.month - 1]}';
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.primary.withValues(alpha: 0.18),
            palette.primarySubtle,
          ],
        ),
      ),
      child: Center(
        child: AppIcon(
          AppIcons.landscape,
          size: 40,
          color: palette.primary.withValues(alpha: 0.5),
        ),
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
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 12, color: foreground),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

/// Small tinted pill for a distance/duration/date fact.
class _FactChip extends StatelessWidget {
  const _FactChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: palette.cardHigh,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 13, color: palette.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
