import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/trek_library/presentation/providers/trek_providers.dart';
import 'package:doon_walkers/features/trek_library/presentation/widgets/trek_admin_actions.dart';
import 'package:doon_walkers/features/trek_library/presentation/widgets/trek_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

/// Trek Library — one shared screen for every role.
///
/// Guests and members see published treks only. An admin sees the same
/// screen plus inline management: drafts included (marked as such), a
/// per-trek actions menu, and an "Add Trek" button. There is deliberately
/// no separate admin trek-management screen — the admin controls live
/// here so there's a single source of truth for how a trek is presented.
///
/// The role split is purely which provider feeds the grid:
/// [adminAllTreksProvider] (published + draft) vs
/// [publishedTreksProvider]. RLS enforces the same split server-side —
/// `treks_select` only returns unpublished rows to an admin caller — so
/// a non-admin can't obtain drafts even if this widget asked for them.
class TrekLibraryScreen extends ConsumerWidget {
  const TrekLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isAdmin = ref.watch(isAdminProvider);
    final treksProvider = isAdmin ? adminAllTreksProvider : publishedTreksProvider;
    final treksAsync = ref.watch(treksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trek Library')),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppConstants.routeTrekNew),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Trek'),
            )
          : null,
      body: SafeArea(
        child: treksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) {
            debugPrint('TrekLibraryScreen: failed to load treks: $error');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 40, color: theme.colorScheme.error),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load treks.',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(treksProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (treks) {
            Future<void> onRefresh() => ref.refresh(treksProvider.future);

            if (treks.isEmpty) {
              return RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [_EmptyTrekLibrary(isAdmin: isAdmin)],
                ),
              );
            }

            // A masonry grid, not a fixed-childAspectRatio GridView — a
            // trek's description length varies row to row (some treks
            // have none, some have several sentences), so a fixed cell
            // height either wastes space below short content or clips
            // long content. Same underlying failure mode as the earlier
            // Admin Panel card overflow bug: a fixed aspect ratio assumes
            // every cell needs the same height, when in fact it should be
            // driven by each card's own content. MasonryGridView sizes
            // each card to its own intrinsic height and packs them into
            // columns, so a short-description card and a long-description
            // card both look correct without either wasting space or
            // needing another guessed ratio number.
            return RefreshIndicator(
              onRefresh: onRefresh,
              child: MasonryGridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                // Extra bottom padding for admins so the FAB never covers
                // the last row's action menu.
                padding: EdgeInsets.fromLTRB(16, 16, 16, isAdmin ? 96 : 16),
                gridDelegate: const SliverSimpleGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 340,
                ),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                itemCount: treks.length,
                itemBuilder: (context, index) {
                  final trek = treks[index];
                  return TrekCard(
                    trek: trek,
                    onTap: () => context.push(AppConstants.trekDetailLocation(trek.id)),
                    adminActions: isAdmin ? TrekAdminActions(trek: trek) : null,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyTrekLibrary extends StatelessWidget {
  const _EmptyTrekLibrary({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hiking_rounded, size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            isAdmin ? 'No treks yet' : 'No treks published yet',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isAdmin
                ? 'Tap "Add Trek" to create the first one.'
                : 'Check back soon — new treks are on the way.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
