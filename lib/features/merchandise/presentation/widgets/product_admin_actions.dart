import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/product.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/product_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Inline admin action menu for a single product — edit / active-toggle
/// / delete — rendered directly on the catalog and detail screens when
/// [isAdminProvider] is true. Mirrors TrekAdminActions exactly; RLS
/// (`products_update_admin`/`products_delete_admin`) independently
/// rejects the underlying writes for anyone else, so a mis-rendered
/// menu is a cosmetic bug rather than a permission hole.
class ProductAdminActions extends ConsumerStatefulWidget {
  const ProductAdminActions({
    super.key,
    required this.product,
    this.onDeleted,
    this.iconColor,
  });

  final Product product;

  /// Called after a successful delete — lets Product Detail pop itself,
  /// while the catalog grid just stays put and refreshes.
  final VoidCallback? onDeleted;

  /// Overrides the menu glyph colour (Product Detail renders it over a
  /// photo, where the default on-surface colour disappears).
  final Color? iconColor;

  @override
  ConsumerState<ProductAdminActions> createState() => _ProductAdminActionsState();
}

class _ProductAdminActionsState extends ConsumerState<ProductAdminActions> {
  bool _isPending = false;

  Future<void> _confirmDelete() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          'This permanently deletes "${widget.product.name}", including its '
          'photos and sizes. This cannot be undone.',
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
        .read(productAdminControllerProvider.notifier)
        .deleteProduct(widget.product.id);
    if (!mounted) return;
    setState(() => _isPending = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not delete product. Please try again.'),
          backgroundColor: Theme.of(context).colorScheme.error,
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
        SnackBar(
          content: const Text('Could not update product. Please try again.'),
          backgroundColor: Theme.of(context).colorScheme.error,
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
              widget.product.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            ),
            title: Text(widget.product.isActive ? 'Deactivate' : 'Activate'),
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
