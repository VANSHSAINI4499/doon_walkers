import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:doon_walkers/features/trek_library/presentation/providers/trek_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Inline admin action menu for a single trek — edit / publish-toggle /
/// delete — rendered directly on the *public* Trek Library and Trek Detail
/// screens when [isAdminProvider] is true, rather than on a separate
/// admin-only management screen.
///
/// Callers are responsible for only rendering this for an admin; RLS
/// (`treks_update_admin` / `treks_delete_admin`) independently rejects the
/// underlying writes for anyone else, so a mis-rendered menu is a cosmetic
/// bug rather than a permission hole.
///
/// Redesign Phase 3 restyles the trigger icon, the menu items, and the
/// delete dialog onto the design system. The gating, the mutations, the
/// list invalidation, the FK-violation delete message, and the pending
/// state are all unchanged.
class TrekAdminActions extends ConsumerStatefulWidget {
  const TrekAdminActions({
    super.key,
    required this.trek,
    this.onDeleted,
    this.iconColor,
  });

  final Trek trek;

  /// Called after a successful delete — lets Trek Detail pop itself, while
  /// the library grid just stays put and refreshes.
  final VoidCallback? onDeleted;

  /// Overrides the menu glyph colour (Trek Detail renders it over a photo,
  /// where the default on-surface colour disappears).
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
  /// `registrations_trek_id_fkey` is ON DELETE RESTRICT, so deleting a trek
  /// that people registered for fails with a 23503 foreign-key violation.
  /// Without this the admin would just see "please try again" and retry
  /// forever.
  String _deleteFailureMessage(Object? error) {
    if (error is PostgrestException && error.code == '23503') {
      return 'This trek has registrations and can\'t be deleted. '
          'Unpublish it instead to hide it from members.';
    }
    return 'Could not delete trek. Please try again.';
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete trek?'),
        content: Text(
          'This permanently deletes "${widget.trek.title}", including its '
          'cover image. This cannot be undone.',
        ),
        actions: [
          PremiumButton(
            label: 'Cancel',
            variant: PremiumButtonVariant.glass,
            size: PremiumButtonSize.small,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          PremiumButton(
            label: 'Delete',
            icon: AppIcons.delete,
            variant: PremiumButtonVariant.danger,
            size: PremiumButtonSize.small,
            onPressed: () => Navigator.of(dialogContext).pop(true),
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
          backgroundColor: AppColors.danger,
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
        const SnackBar(
          content: Text('Could not update trek. Please try again.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    _invalidateTrekLists();
    ref.invalidate(trekByIdProvider(widget.trek.id));
  }

  @override
  Widget build(BuildContext context) {
    if (_isPending) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Admin actions',
      icon: AppIcon(AppIcons.more, color: widget.iconColor ?? AppColors.white),
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
          child: _MenuRow(icon: AppIcons.edit, label: 'Edit'),
        ),
        PopupMenuItem(
          value: 'toggle',
          child: _MenuRow(
            icon: widget.trek.isPublished ? AppIcons.hidden : AppIcons.visible,
            label: widget.trek.isPublished ? 'Unpublish' : 'Publish',
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: _MenuRow(icon: AppIcons.delete, label: 'Delete', color: AppColors.danger),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.textPrimary;
    return Row(
      children: [
        AppIcon(icon, size: 20, color: tint),
        const SizedBox(width: AppSpacing.md),
        Text(label, style: AppTextStyles.tinted(AppTextStyles.bodyMedium, tint)),
      ],
    );
  }
}
