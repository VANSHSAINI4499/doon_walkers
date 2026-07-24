import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/router/auth_guard.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/wishlist_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Heart-icon wishlist toggle on Product Detail.
///
/// A guest tapping this goes through [AuthGuard.requireAuth], which bounces
/// to sign-in and returns with a `wishlist=1` flag — [autoAdd] completes
/// the original add intent once signed in.
///
/// Redesign Phase 6 restyles the heart (filled danger when wishlisted,
/// outline otherwise — the same visual language as Profile's wishlist
/// remove control). The toggle behaviour, the guarded round-trip, and the
/// auto-add are unchanged.
class WishlistButton extends ConsumerStatefulWidget {
  const WishlistButton({super.key, required this.productId, this.autoAdd = false});

  final String productId;

  /// Set from the `?wishlist=1` query flag. Fires once (guarded by the
  /// State lifetime) since it triggers a real mutation.
  final bool autoAdd;

  @override
  ConsumerState<WishlistButton> createState() => _WishlistButtonState();
}

class _WishlistButtonState extends ConsumerState<WishlistButton> {
  bool _isPending = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _add());
    }
  }

  Future<void> _add() async {
    if (!mounted || _isPending) return;
    setState(() => _isPending = true);
    final success = await ref.read(wishlistControllerProvider.notifier).add(widget.productId);
    if (!mounted) return;
    setState(() => _isPending = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to your wishlist.')),
      );
    }
  }

  Future<void> _remove() async {
    setState(() => _isPending = true);
    final success = await ref.read(wishlistControllerProvider.notifier).remove(widget.productId);
    if (!mounted) return;
    setState(() => _isPending = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from your wishlist.')),
      );
    }
  }

  void _guardedToggle(BuildContext context, bool currentlyWishlisted) {
    if (currentlyWishlisted) {
      _remove();
      return;
    }
    AuthGuard.requireAuth(
      context,
      returnPath: '${AppConstants.merchandiseDetailLocation(widget.productId)}?wishlist=1',
      onAuthenticated: _add,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wishlistedAsync = ref.watch(isProductWishlistedProvider(widget.productId));
    final isWishlisted = wishlistedAsync.valueOrNull ?? false;

    if (_isPending || wishlistedAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.danger)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isWishlisted ? AppColors.danger.withValues(alpha: 0.14) : AppColors.card,
        shape: BoxShape.circle,
        border: Border.all(
          color: isWishlisted ? AppColors.danger.withValues(alpha: 0.4) : AppColors.glassBorder,
        ),
      ),
      child: IconButton(
        onPressed: () => _guardedToggle(context, isWishlisted),
        tooltip: isWishlisted ? 'Remove from wishlist' : 'Add to wishlist',
        icon: AppIcon(
          AppIcons.favorite,
          fill: isWishlisted ? 1 : 0,
          color: isWishlisted ? AppColors.danger : AppColors.textSecondary,
        ),
      ),
    );
  }
}
