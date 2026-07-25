import 'dart:async';

import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/merchandise/data/repositories/wishlist_repository_impl.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/wishlist_item.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/wishlist_pagination_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The signed-in user's 3 newest wishlist items — backs the "My
/// Wishlist" dashboard preview on Profile ([MyWishlistSection]).
/// Fetching 3 rather than exactly the 2 displayed is how
/// [PreviewSection] decides whether to show "View All" without a
/// separate COUNT query — see that widget's doc.
///
/// Watches [authStateChangesProvider] so signing out (or switching
/// accounts) refetches rather than leaving the previous user's list
/// cached on screen — mirrors [myRegistrationsProvider] exactly.
final myWishlistPreviewProvider = FutureProvider.autoDispose<List<WishlistItem>>(
  (ref) {
    ref.watch(authStateChangesProvider);
    return ref.watch(wishlistRepositoryProvider).fetchMyWishlist(limit: 3);
  },
  name: 'myWishlistPreviewProvider',
);

/// Whether the signed-in user has [productId] wishlisted — drives the
/// Product Detail toggle button's initial state. Mirrors
/// `myRegistrationForTrekProvider`'s shape: returns `false` for a
/// guest rather than throwing, since the button itself (not this
/// lookup) is what hands a guest off to [AuthGuard].
final isProductWishlistedProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, productId) async {
    ref.watch(authStateChangesProvider);
    final supabase = ref.watch(supabaseClientProvider);
    if (supabase.auth.currentUser == null) return false;
    return ref.watch(wishlistRepositoryProvider).isWishlisted(productId);
  },
  name: 'isProductWishlistedProvider',
);

/// Riverpod AsyncNotifier managing wishlist mutations (add, remove).
/// Mirrors RegistrationController's shape.
final wishlistControllerProvider = AsyncNotifierProvider<WishlistController, void>(
  WishlistController.new,
  name: 'wishlistControllerProvider',
);

class WishlistController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  void _invalidateWishlistViews(String productId) {
    ref.invalidate(myWishlistPreviewProvider);
    ref.invalidate(myWishlistPaginationProvider);
    ref.invalidate(isProductWishlistedProvider(productId));
  }

  Future<bool> add(String productId) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await ref.read(wishlistRepositoryProvider).addToWishlist(productId);
      success = true;
    });
    if (success) _invalidateWishlistViews(productId);
    return success;
  }

  Future<bool> remove(String productId) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await ref.read(wishlistRepositoryProvider).removeFromWishlist(productId);
      success = true;
    });
    if (success) _invalidateWishlistViews(productId);
    return success;
  }
}
