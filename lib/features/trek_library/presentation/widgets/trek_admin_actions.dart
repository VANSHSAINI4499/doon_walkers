import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:doon_walkers/features/trek_library/presentation/providers/trek_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Inline admin action menu for a single trek — edit / publish-toggle /
/// delete — rendered directly on the *public* Trek Library and Trek
/// Detail screens when [isAdminProvider] is true, rather than on a
/// separate admin-only management screen.
///
/// Callers are responsible for only rendering this for an admin; RLS
/// (`treks_update_admin` / `treks_delete_admin`) independently rejects
/// the underlying writes for anyone else, so a mis-rendered menu is a
/// cosmetic bug rather than a permission hole.
class TrekAdminActions extends ConsumerStatefulWidget {
  const TrekAdminActions({
    super.key,
    required this.trek,
    this.onDeleted,
    this.iconColor,
  });

  final Trek trek;

  /// Called after a successful delete — lets Trek Detail pop itself,
  /// while the library grid just stays put and refreshes.
  final VoidCallback? onDeleted;

  /// Overrides the menu glyph colour (Trek Detail renders it over a
  /// photo, where the default on-surface colour disappears).
  final Color? iconColor;

  @override
  ConsumerState<TrekAdminActions> createState() => _TrekAdminActionsState();
}

class _TrekAdminActionsState extends ConsumerState<TrekAdminActions> {
  bool _isPending = false;

  /// Refetches both trek lists after a mutation. They're one-shot
  /// FutureProviders (not live streams), so nothing updates without this.
  void _invalidateTrekLists() {
    ref.invalidate(publishedTreksProvider);
    ref.invalidate(adminAllTreksProvider);
  }

  /// Turns a failed delete into something an admin can act on.
  ///
  /// `registrations_trek_id_fkey` is ON DELETE RESTRICT, so once the
  /// Phase 6 sign-up flow ships, deleting a trek that people registered
  /// for fails with a 23503 foreign-key violation. Without this the admin
  /// would just see "please try again" and retry forever.
  String _deleteFailureMessage(Object? error) {
    if (error is PostgrestException && error.code == '23503') {
      return 'This trek has registrations and can\'t be deleted. '
          'Unpublish it instead to hide it from members.';
    }
    return 'Could not delete trek. Please try again.';
  }

  Future<void> _confirmDelete() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete trek?'),
        content: Text(
          'This permanently deletes "${widget.trek.title}", including its '
          'cover image. This cannot be undone.',
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

    setState(() => _isPending = true);
    final success = await ref
        .read(trekAdminControllerProvider.notifier)
        .deleteTrek(widget.trek.id);
    if (!mounted) return;
    setState(() => _isPending = false);

    if (!success) {
      final error = ref.read(trekAdminControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_deleteFailureMessage(error)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    _invalidateTrekLists();
    widget.onDeleted?.call();
  }

  Future<void> _togglePublished() async {
    setState(() => _isPending = true);
    final success = await ref
        .read(trekAdminControllerProvider.notifier)
        .setPublished(widget.trek.id, !widget.trek.isPublished);
    if (!mounted) return;
    setState(() => _isPending = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not update trek. Please try again.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    _invalidateTrekLists();
    ref.invalidate(trekByIdProvider(widget.trek.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isPending) {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Admin actions',
      icon: Icon(Icons.more_vert_rounded, color: widget.iconColor),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            context.push(AppConstants.trekEditLocation(widget.trek.id));
          case 'toggle':
            _togglePublished();
          case 'delete':
            _confirmDelete();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'toggle',
          child: ListTile(
            leading: Icon(
              widget.trek.isPublished
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            title: Text(widget.trek.isPublished ? 'Unpublish' : 'Publish'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
            title: Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
