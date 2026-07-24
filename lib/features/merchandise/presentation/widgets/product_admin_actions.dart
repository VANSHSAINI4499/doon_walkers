import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/product.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/product_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Inline admin action menu for a single product — edit / active-toggle /
/// delete — rendered directly on the catalog and detail screens when
/// [isAdminProvider] is true. Mirrors TrekAdminActions; RLS
/// (`products_update_admin`/`products_delete_admin`) independently rejects
/// the underlying writes for anyone else.
///
/// Redesign Phase 6 restyles the trigger, menu items, and delete dialog.
/// The gating, mutations, and list invalidation are unchanged.
class ProductAdminActions extends ConsumerStatefulWidget {
  const ProductAdminActions({
    super.key,
    required this.product,
    this.onDeleted,
    this.iconColor,
  });

  final Product product;

  /// Called after a successful delete — lets Product Detail pop itself.
  final VoidCallback? onDeleted;

  /// Overrides the menu glyph colour (Product Detail renders it over a
  /// photo).
  final Color? iconColor;

  @override
  ConsumerState<ProductAdminActions> createState() => _ProductAdminActionsState();
}

class _ProductAdminActionsState extends ConsumerState<ProductAdminActions> {
  bool _isPending = false;

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          'This permanently deletes "${widget.product.name}", including its '
          'photos and sizes. This cannot be undone.',
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
        .read(productAdminControllerProvider.notifier)
        .deleteProduct(widget.product.id);
    if (!mounted) return;
    setState(() => _isPending = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete product. Please try again.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    _invalidateProductLists();
    widget.onDeleted?.call();
  }

  Future<void> _toggleActive() async {
    setState(() => _isPending = true);
    final success = await ref
        .read(productAdminControllerProvider.notifier)
        .setActive(widget.product.id, !widget.product.isActive);
    if (!mounted) return;
    setState(() => _isPending = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update product. Please try again.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    _invalidateProductLists();
    ref.invalidate(productByIdProvider(widget.product.id));
  }

  void _invalidateProductLists() {
    ref.invalidate(activeProductsProvider);
    ref.invalidate(adminAllProductsProvider);
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
            context.push(AppConstants.merchandiseEditLocation(widget.product.id));
          case 'toggle':
            _toggleActive();
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
            icon: widget.product.isActive ? AppIcons.hidden : AppIcons.visible,
            label: widget.product.isActive ? 'Deactivate' : 'Activate',
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
