import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/utils/link_launcher.dart';
import 'package:doon_walkers/core/widgets/section_header.dart';
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
/// indistinguishable on purpose — the id doesn't exist, or it's a draft
/// a non-admin isn't allowed to see — both render the same "not found"
/// state rather than leaking which case it was.
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
  /// [AuthGuard] bounces them to sign-in and the router returns them
  /// here — this reopens the form so they land back *in the flow* rather
  /// than on the trek page having to find the button again.
  final bool openRegistration;

  /// Same idea as [openRegistration] but for [CommentThread]'s input —
  /// set from `?comment=1`, which its own "Sign in to comment" tap
  /// attaches to the sign-in return path via [AuthGuard]. Passed
  /// straight through as [CommentThread.autoFocusInput]; unlike the
  /// registration sheet this doesn't need a "handled" guard here — see
  /// that field's doc for why.
  final bool openComment;

  @override
  ConsumerState<TrekDetailScreen> createState() => _TrekDetailScreenState();
}

class _TrekDetailScreenState extends ConsumerState<TrekDetailScreen> {
  /// Guards against reopening the sheet on every rebuild — the flag is
  /// part of the route and therefore survives as long as the page does.
  bool _handledAutoOpen = false;

  /// Waits for the trek to load before opening, so the sheet always has
  /// a real title to show and we never prompt for a trek that turned out
  /// not to exist (or that RLS hid).
  void _maybeAutoOpenRegistration(Trek trek) {
    if (!widget.openRegistration || _handledAutoOpen || !trek.isPublished) return;
    // A completed trek never auto-opens the form — mirrors
    // TrekRegisterButton's own gating, so a stale `?register=1` return
    // link for a trek that has since passed can't pop the sheet anyway.
    if (trek.isCompleted) return;
    // Admins manage treks, they don't register for them — mirrors
    // TrekRegisterButton not rendering a CTA for them at all, so a
    // stale/crafted `?register=1` link can't pop the sheet either.
    if (ref.read(isAdminProvider)) return;
    _handledAutoOpen = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Only if they aren't already registered — otherwise the sheet
      // would just fail on the UNIQUE constraint.
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _DetailMessage(
          icon: Icons.error_outline_rounded,
          title: 'Could not load this trek.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(trekByIdProvider(widget.trekId)),
        ),
        data: (trek) {
          if (trek == null) {
            return const _DetailMessage(
              icon: Icons.search_off_rounded,
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
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : null,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back'),
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
  /// for every role — an admin just gets an extra actions menu and a
  /// draft banner; guests and members see neither.
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverImage = trek.coverImage;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          actions: [
            if (isAdmin)
              TrekAdminActions(
                trek: trek,
                iconColor: Colors.white,
                // The trek this screen is showing no longer exists —
                // pop rather than sit on a dangling detail view.
                onDeleted: () {
                  if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                },
              ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: (coverImage == null || coverImage.isEmpty)
                ? Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Icon(Icons.landscape_rounded, size: 64, color: theme.colorScheme.outline),
                  )
                : Image.network(
                    coverImage,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Icon(Icons.broken_image_outlined, size: 48, color: theme.colorScheme.outline),
                    ),
                  ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Only an admin can reach an unpublished trek at all
                    // (treks_select gates it), so this banner doubles as
                    // a reminder that members can't see this page yet.
                    if (isAdmin && !trek.isPublished) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              size: 18,
                              color: theme.colorScheme.onTertiaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Draft — not visible to members yet.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onTertiaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            trek.title,
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        DifficultyBadge(difficulty: trek.difficulty),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _QuickFactsRow(trek: trek),
                    const SizedBox(height: 28),

                    if (trek.description.trim().isNotEmpty) ...[
                      const SectionHeader(title: 'About This Trek', icon: Icons.menu_book_outlined),
                      const SizedBox(height: 12),
                      Text(
                        trek.description,
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                      ),
                      const SizedBox(height: 28),
                    ],

                    if ((trek.thingsToCarry ?? '').trim().isNotEmpty) ...[
                      const SectionHeader(title: 'Things to Carry', icon: Icons.backpack_outlined),
                      const SizedBox(height: 12),
                      Text(
                        trek.thingsToCarry!,
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                      ),
                      const SizedBox(height: 28),
                    ],

                    if ((trek.googleMapLink ?? '').trim().isNotEmpty) ...[
                      OutlinedButton.icon(
                        onPressed: () => openExternalLink(context, trek.googleMapLink!),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Open Route in Google Maps'),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Admins manage treks, they don't register for them —
                    // nothing renders in this slot at all for them (the
                    // app bar's TrekAdminActions menu is their management
                    // surface), rather than a disabled/placeholder CTA.
                    if (!isAdmin) ...[
                      TrekRegisterButton(trek: trek),
                      const SizedBox(height: 28),
                    ],

                    const Divider(),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Gallery & Videos', icon: Icons.photo_library_outlined),
                    const SizedBox(height: 12),
                    TrekGallerySection(trekId: trek.id, trekTitle: trek.title),
                    const SizedBox(height: 28),

                    const SectionHeader(title: 'Comments', icon: Icons.forum_outlined),
                    const SizedBox(height: 12),
                    CommentThread(trekId: trek.id, autoFocusInput: openComment),
                    const SizedBox(height: 24),
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

class _QuickFactsRow extends StatelessWidget {
  const _QuickFactsRow({required this.trek});

  final Trek trek;

  @override
  Widget build(BuildContext context) {
    final facts = <_QuickFact>[
      // First — "when" is the most decision-relevant fact once a trek
      // has a real date. Omitted entirely for an older trek not yet
      // backfilled with one, rather than showing a blank placeholder.
      if (trek.trekDate != null)
        _QuickFact(Icons.calendar_month_rounded, 'Trek Date', _formatTrekDate(trek.trekDate!)),
      if (trek.distanceKm != null)
        _QuickFact(Icons.straighten_rounded, 'Distance', '${_formatNum(trek.distanceKm!)} km'),
      if (trek.durationDays != null)
        _QuickFact(Icons.calendar_today_outlined, 'Duration', '${trek.durationDays} ${trek.durationDays == 1 ? 'day' : 'days'}'),
      if (trek.altitudeM != null)
        _QuickFact(Icons.terrain_rounded, 'Max Altitude', '${trek.altitudeM} m'),
      if ((trek.bestSeason ?? '').isNotEmpty)
        _QuickFact(Icons.wb_sunny_outlined, 'Best Season', trek.bestSeason!),
    ];

    if (facts.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 20,
      runSpacing: 16,
      children: facts.map((f) => _QuickFactTile(fact: f)).toList(),
    );
  }

  String _formatNum(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

/// Local rather than shared with the registrations feature's
/// `formatRegistrationDate` — trek_library and registrations already
/// depend on each other in one direction (registrations -> trek_library
/// for [Trek]); reaching back the other way for a one-line date format
/// would just make that a cycle for no real reuse benefit.
String _formatTrekDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

class _QuickFact {
  const _QuickFact(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;
}

class _QuickFactTile extends StatelessWidget {
  const _QuickFactTile({required this.fact});
  final _QuickFact fact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 130,
      child: Row(
        children: [
          Icon(fact.icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fact.value,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  fact.label,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

