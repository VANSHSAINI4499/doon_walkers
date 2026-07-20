import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:doon_walkers/features/trek_library/presentation/providers/trek_providers.dart';
import 'package:doon_walkers/features/trek_library/presentation/widgets/admin_trek_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Admin trek management — every trek, published and draft, clearly
/// distinguished. Reachable only via the admin-gated `/admin/treks`
/// route (see app_router.dart); RLS backs this up independently by
/// only returning draft rows to an admin caller in the first place.
class AdminTrekListScreen extends ConsumerStatefulWidget {
  const AdminTrekListScreen({super.key});

  @override
  ConsumerState<AdminTrekListScreen> createState() => _AdminTrekListScreenState();
}

class _AdminTrekListScreenState extends ConsumerState<AdminTrekListScreen> {
  // Which row's delete/publish-toggle action is in flight — scopes the
  // loading state to that one row instead of blocking the whole list.
  String? _pendingId;

  Future<void> _confirmDelete(Trek trek) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete trek?'),
        content: Text(
          'This permanently deletes "${trek.title}", including its cover image. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _pendingId = trek.id);
    final success = await ref.read(trekAdminControllerProvider.notifier).deleteTrek(trek.id);
    if (!mounted) return;
    setState(() => _pendingId = null);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not delete trek. Please try again.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _togglePublished(Trek trek) async {
    setState(() => _pendingId = trek.id);
    final success = await ref
        .read(trekAdminControllerProvider.notifier)
        .setPublished(trek.id, !trek.isPublished);
    if (!mounted) return;
    setState(() => _pendingId = null);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not update trek. Please try again.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final treksAsync = ref.watch(adminAllTreksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Treks')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppConstants.routeAdminTrekNew),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Trek'),
      ),
      body: treksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load treks: $error', textAlign: TextAlign.center),
          ),
        ),
        data: (treks) {
          if (treks.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_location_alt_outlined, size: 48, color: theme.colorScheme.outline),
                    const SizedBox(height: 16),
                    Text('No treks yet', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Tap "Add Trek" to create the first one.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: treks.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final trek = treks[index];
              return AdminTrekListTile(
                trek: trek,
                isPending: _pendingId == trek.id,
                onEdit: () => context.push(AppConstants.adminTrekEditLocation(trek.id)),
                onDelete: () => _confirmDelete(trek),
                onTogglePublished: () => _togglePublished(trek),
              );
            },
          );
        },
      ),
    );
  }
}
