import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/router/auth_guard.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/wishlist_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Heart-icon wishlist toggle on Product Detail.
///
/// A guest tapping this goes through [AuthGuard.requireAuth], which
/// bounces to sign-in and returns here with a `wishlist=1` flag —
/// [autoAdd] (set from that flag by Product Detail) completes the
/// original add-to-wishlist intent automatically once signed in,
/// mirroring TrekRegisterButton's auto-reopened form / CommentThread's
/// auto-focused input round trip.
class WishlistButton extends ConsumerStatefulWidget {
  const WishlistButton({super.key, required this.productId, this.autoAdd = false});

  final String productId;

  /// Set from the `?wishlist=1` query flag. Guarded against re-firing
  /// on rebuild by [_ProductDetailBody]'s own "handled" flag — same
  /// pattern as TrekDetailScreen's `_maybeAutoOpenRegistration`, since
  /// this triggers a real mutation (unlike CommentThread's harmless
  /// re-focus), so it must only ever fire once.
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
    final theme = Theme.of(context);
    final wishlistedAsync = ref.watch(isProductWishlistedProvider(widget.productId));
    final isWishlisted = wishlistedAsync.valueOrNull ?? false;

    if (_isPending || wishlistedAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return IconButton(
      onPressed: () => _guardedToggle(context, isWishlisted),
      tooltip: isWishlisted ? 'Remove from wishlist' : 'Add to wishlist',
      icon: Icon(
        isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: isWishlisted ? theme.colorScheme.error : null,
      ),
    );
  }
}
