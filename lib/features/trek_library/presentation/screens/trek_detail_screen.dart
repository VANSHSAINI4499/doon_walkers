import 'package:doon_walkers/core/utils/link_launcher.dart';
import 'package:doon_walkers/core/widgets/section_header.dart';
import 'package:doon_walkers/features/gallery/presentation/widgets/trek_gallery_section.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:doon_walkers/features/trek_library/presentation/providers/trek_providers.dart';
import 'package:doon_walkers/features/trek_library/presentation/widgets/difficulty_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full trek journal view. `trek == null` covers two cases RLS makes
/// indistinguishable on purpose — the id doesn't exist, or it's a draft
/// a non-admin isn't allowed to see — both render the same "not found"
/// state rather than leaking which case it was.
class TrekDetailScreen extends ConsumerWidget {
  const TrekDetailScreen({super.key, required this.trekId});

  final String trekId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trekAsync = ref.watch(trekByIdProvider(trekId));

    return Scaffold(
      body: trekAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _DetailMessage(
          icon: Icons.error_outline_rounded,
          title: 'Could not load this trek.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(trekByIdProvider(trekId)),
        ),
        data: (trek) => trek == null
            ? const _DetailMessage(
                icon: Icons.search_off_rounded,
                title: 'Trek not found.',
              )
            : _TrekDetailBody(trek: trek),
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
  const _TrekDetailBody({required this.trek});

  final Trek trek;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverImage = trek.coverImage;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
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

                    // Registration flow is Phase 6 — a real disabled button
                    // rather than a fake-clickable one, so it's honest about
                    // not doing anything yet.
                    FilledButton(
                      onPressed: null,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('Registration Opens Soon'),
                    ),
                    const SizedBox(height: 28),

                    const Divider(),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Gallery & Videos', icon: Icons.photo_library_outlined),
                    const SizedBox(height: 12),
                    TrekGallerySection(trekId: trek.id),
                    const SizedBox(height: 28),

                    // Phase 7 (comments) slots in here — this placeholder
                    // marks where, deliberately not built out yet.
                    const _ComingSoonSection(
                      icon: Icons.forum_outlined,
                      title: 'Comments',
                      message: 'Community comments for this trek are coming soon.',
                    ),
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

class _ComingSoonSection extends StatelessWidget {
  const _ComingSoonSection({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 32, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
