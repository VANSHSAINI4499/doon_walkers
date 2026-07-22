import 'package:doon_walkers/features/merchandise/domain/entities/wishlist_item.dart';

/// Abstract interface for the signed-in user's own wishlist.
///
/// Every method is implicitly scoped to the caller — there is no
/// admin-visible variant of any of these, matching
/// `user_wishlist`'s RLS (own-row only, no `is_admin()` override at
/// all — see 0019_user_wishlist.sql's doc for why).
abstract class WishlistRepository {
  /// The signed-in user's full wishlist, newest first — "My Wishlist"
  /// on Profile.
  Future<List<WishlistItem>> fetchMyWishlist();

  /// Whether [productId] is on the signed-in user's wishlist — backs
  /// the toggle button's initial state on Product Detail. A dedicated
  /// per-product check (mirrors
  /// `RegistrationRepository.fetchMyRegistrationForTrek`) rather than
  /// deriving from [fetchMyWishlist], so opening a product detail page
  /// doesn't require the user's entire wishlist to already be loaded.
  Future<bool> isWishlisted(String productId);

  Future<WishlistItem> addToWishlist(String productId);

  /// Removes by (caller, [productId]) rather than requiring the
  /// wishlist row's own id — the toggle button only ever knows the
  /// product it's showing, not the row id backing it.
  Future<void> removeFromWishlist(String productId);
}
