import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/utils/link_launcher.dart';
import 'package:doon_walkers/core/widgets/section_title.dart';
import 'package:doon_walkers/features/comments/presentation/widgets/comment_thread.dart';
import 'package:doon_walkers/features/gallery/presentation/widgets/trek_gallery_section.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:doon_walkers/features/registrations/presentation/widgets/registration_form_sheet.dart';
import 'package:doon_walkers/features/registrations/presentation/widgets/trek_register_button.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:doon_walkers/features/trek_library/presentation/providers/trek_providers.dart';
import 'package:doon_walkers/features/trek_library/presentation/widgets/difficulty_badge.dart';
import 'package:doon_walkers/features/trek_library/presentation/widgets/trek_admin_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full trek journal view. `trek == null` covers two cases RLS makes
/// indistinguishable on purpose — the id doesn't exist, or it's a draft a
/// non-admin isn't allowed to see — both render the same "not found" state
/// rather than leaking which case it was.
///
/// Redesign Phase 3: rebuilt on the design system (hero cover with the
/// shared card→detail flight, glass quick-fact tiles, skeleton loading).
/// The auto-open-registration flow, the admin-only register-slot hiding,
/// and every other conditional are unchanged.
class TrekDetailScreen extends ConsumerStatefulWidget {
  const TrekDetailScreen({
    super.key,
    required this.trekId,
    this.openRegistration = false,
    this.openComment = false,
  });

  final String trekId;

  /// Set from the `?register=1` query flag that [TrekRegisterButton]
  /// attaches to its sign-in return path. When a guest taps Register,
  /// [AuthGuard] bounces them to sign-in and the router returns them here —
  /// this reopens the form so they land back *in the flow* rather than on
  /// the trek page having to find the button again.
  final bool openRegistration;

  /// Same idea as [openRegistration] but for [CommentThread]'s input — set
  /// from `?comment=1`. Passed straight through as
  /// [CommentThread.autoFocusInput].
  final bool openComment;

  @override
  ConsumerState<TrekDetailScreen> createState() => _TrekDetailScreenState();
}

class _TrekDetailScreenState extends ConsumerState<TrekDetailScreen> {
  /// Guards against reopening the sheet on every rebuild — the flag is part
  /// of the route and therefore survives as long as the page does.
  bool _handledAutoOpen = false;

  /// Waits for the trek to load before opening, so the sheet always has a
  /// real title to show and we never prompt for a trek that turned out not
  /// to exist (or that RLS hid).
  void _maybeAutoOpenRegistration(Trek trek) {
    if (!widget.openRegistration || _handledAutoOpen || !trek.isPublished) return;
    // A completed trek never auto-opens the form — mirrors
    // TrekRegisterButton's own gating, so a stale `?register=1` return link
    // for a trek that has since passed can't pop the sheet anyway.
    if (trek.isCompleted) return;
    // Admins manage treks, they don't register for them — mirrors
    // TrekRegisterButton not rendering a CTA for them at all, so a
    // stale/crafted `?register=1` link can't pop the sheet either.
    if (ref.read(isAdminProvider)) return;
    _handledAutoOpen = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Only if they aren't already registered — otherwise the sheet would
      // just fail on the UNIQUE constraint.
      final existing = await ref.read(
        myRegistrationForTrekProvider(widget.trekId).future,
      );
      if (!mounted || existing != null) return;

      final registered = await showRegistrationFormSheet(context, trek: trek);
      if (registered == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You're registered — see you on the trail!")),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final trekAsync = ref.watch(trekByIdProvider(widget.trekId));

    return Scaffold(
      body: trekAsync.when(
        loading: () => const _TrekDetailSkeleton(),
        error: (error, stack) => _DetailMessage(
          icon: AppIcons.error,
          title: 'Could not load this trek.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(trekByIdProvider(widget.trekId)),
        ),
        data: (trek) {
          if (trek == null) {
            return const _DetailMessage(
              icon: AppIcons.searchOff,
              title: 'Trek not found.',
            );
          }
          _maybeAutoOpenRegistration(trek);
          return _TrekDetailBody(
            trek: trek,
            isAdmin: ref.watch(isAdminProvider),
            openComment: widget.openComment,
          );
        },
      ),
    );
  }
}

class _DetailMessage extends StatelessWidget {
  const _DetailMessage({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: 48, color: AppColors.textDisabled),
              const SizedBox(height: AppSpacing.lg),
              Text(title, style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.lg),
                PremiumButton(
                  label: actionLabel!,
                  icon: AppIcons.refresh,
                  size: PremiumButtonSize.small,
                  onPressed: onAction,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              PremiumButton(
                label: 'Back',
                icon: AppIcons.back,
                variant: PremiumButtonVariant.ghost,
                size: PremiumButtonSize.small,
                onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrekDetailBody extends StatelessWidget {
  const _TrekDetailBody({required this.trek, required this.isAdmin, this.openComment = false});

  final Trek trek;

  /// See [TrekDetailScreen.openComment].
  final bool openComment;

  /// Drives whether inline management controls render. Same shared screen
  /// for every role — an admin just gets an extra actions menu and a draft
  /// banner; guests and members see neither.
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final coverImage = trek.coverImage;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: AppColors.white),
          actions: [
            if (isAdmin)
              TrekAdminActions(
                trek: trek,
                iconColor: AppColors.white,
                // The trek this screen is showing no longer exists — pop
                // rather than sit on a dangling detail view.
                onDeleted: () {
                  if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                },
              ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                AppHero(
                  tag: AppHeroTags.trekCover(trek.id),
                  fromRadius: 0,
                  toRadius: 0,
                  child: (coverImage == null || coverImage.isEmpty)
                      ? const _CoverFallback(icon: AppIcons.landscape)
                      : Image.network(
                          coverImage,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              const _CoverFallback(icon: AppIcons.imageBroken),
                        ),
                ),
                // Top scrim keeps the back button + admin menu legible over
                // a bright photo; bottom scrim melts the image into the page.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x99000000), Color(0x00000000), Color(0xFF090909)],
                      stops: [0, 0.35, 1],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Only an admin can reach an unpublished trek at all
                    // (treks_select gates it), so this banner doubles as a
                    // reminder that members can't see this page yet.
                    if (isAdmin && !trek.isPublished) ...[
                      _DraftBanner(),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(trek.title, style: AppTextStyles.headlineSmall),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        DifficultyBadge(difficulty: trek.difficulty),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _QuickFactsRow(trek: trek),
                    const SizedBox(height: AppSpacing.xxl),

                    if (trek.description.trim().isNotEmpty) ...[
                      const SectionTitle(title: 'About This Trek', icon: AppIcons.book),
                      const SizedBox(height: AppSpacing.md),
                      Text(trek.description, style: AppTextStyles.secondary(AppTextStyles.bodyLarge)),
                      const SizedBox(height: AppSpacing.xxl),
                    ],

                    if ((trek.thingsToCarry ?? '').trim().isNotEmpty) ...[
                      const SectionTitle(
                        title: 'Things to Carry',
                        icon: AppIcons.packing,
                        accent: AppColors.accent,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(trek.thingsToCarry!, style: AppTextStyles.secondary(AppTextStyles.bodyLarge)),
                      const SizedBox(height: AppSpacing.xxl),
                    ],

                    if ((trek.googleMapLink ?? '').trim().isNotEmpty) ...[
                      PremiumButton(
                        label: 'Open Route in Google Maps',
                        icon: AppIcons.map,
                        variant: PremiumButtonVariant.secondary,
                        fullWidth: true,
                        onPressed: () => openExternalLink(context, trek.googleMapLink!),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // Admins manage treks, they don't register for them —
                    // nothing renders in this slot at all for them (the app
                    // bar's TrekAdminActions menu is their management
                    // surface), rather than a disabled/placeholder CTA.
                    if (!isAdmin) ...[
                      TrekRegisterButton(trek: trek),
                      const SizedBox(height: AppSpacing.xxl),
                    ],

                    const Divider(),
                    const SizedBox(height: AppSpacing.xl),
                    const SectionTitle(
                      title: 'Gallery & Videos',
                      icon: AppIcons.photo,
                      accent: AppColors.secondary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TrekGallerySection(trekId: trek.id, trekTitle: trek.title),
                    const SizedBox(height: AppSpacing.xxl),

                    const SectionTitle(title: 'Comments', icon: AppIcons.forum),
                    const SizedBox(height: AppSpacing.md),
                    CommentThread(trekId: trek.id, autoFocusInput: openComment),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16302A), AppColors.background],
        ),
      ),
      child: Center(
        child: AppIcon(AppIcons.landscape, size: 64, color: AppColors.textDisabled),
      ),
    );
  }
}

class _DraftBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blurEnabled: false,
      glowColor: AppColors.gold,
      glowOpacity: 0.12,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          const AppIcon(AppIcons.editNote, size: 18, color: AppColors.gold),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Draft — not visible to members yet.',
              style: AppTextStyles.tinted(AppTextStyles.labelMedium, AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickFactsRow extends StatelessWidget {
  const _QuickFactsRow({required this.trek});

  final Trek trek;

  @override
  Widget build(BuildContext context) {
    final facts = <_QuickFact>[
      // First — "when" is the most decision-relevant fact once a trek has
      // a real date. Omitted entirely for an older trek not yet backfilled
      // with one, rather than showing a blank placeholder.
      if (trek.trekDate != null)
        _QuickFact(AppIcons.calendar, 'Trek Date', _formatTrekDate(trek.trekDate!), AppColors.primary),
      if (trek.distanceKm != null)
        _QuickFact(AppIcons.distance, 'Distance', '${_formatNum(trek.distanceKm!)} km', AppColors.secondary),
      if (trek.durationDays != null)
        _QuickFact(AppIcons.duration, 'Duration', '${trek.durationDays} ${trek.durationDays == 1 ? 'day' : 'days'}', AppColors.accent),
      if (trek.altitudeM != null)
        _QuickFact(AppIcons.altitude, 'Max Altitude', '${trek.altitudeM} m', AppColors.gold),
      if ((trek.bestSeason ?? '').isNotEmpty)
        _QuickFact(AppIcons.season, 'Best Season', trek.bestSeason!, AppColors.primary),
    ];

    if (facts.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: facts.map((f) => _QuickFactTile(fact: f)).toList(),
    );
  }

  String _formatNum(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

/// Local rather than shared with the registrations feature's
/// `formatRegistrationDate` — reaching back the other way for a one-line
/// date format would just make a dependency cycle for no real reuse.
String _formatTrekDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

class _QuickFact {
  const _QuickFact(this.icon, this.label, this.value, this.accent);
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
}

class _QuickFactTile extends StatelessWidget {
  const _QuickFactTile({required this.fact});
  final _QuickFact fact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: fact.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: AppIcon(fact.icon, size: 18, color: fact.accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fact.value,
                  style: AppTextStyles.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  fact.label,
                  style: AppTextStyles.secondary(AppTextStyles.bodySmall),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for the detail screen while the trek loads — a hero block, a
/// title, a fact row and a couple of prose blocks.
class _TrekDetailSkeleton extends StatelessWidget {
  const _TrekDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          const SkeletonBox(height: 280, borderRadius: 0),
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 220, height: 28),
                SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    SkeletonBox(width: 150, height: 56, borderRadius: AppRadius.sm),
                    SizedBox(width: AppSpacing.md),
                    SkeletonBox(width: 150, height: 56, borderRadius: AppRadius.sm),
                  ],
                ),
                SizedBox(height: AppSpacing.xxl),
                SkeletonBox(width: 160, height: 20),
                SizedBox(height: AppSpacing.md),
                SkeletonText(lines: 4),
                SizedBox(height: AppSpacing.xxl),
                SkeletonBox(height: 56, borderRadius: AppRadius.md),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
