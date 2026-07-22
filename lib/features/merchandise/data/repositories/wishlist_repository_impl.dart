import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/merchandise/data/models/wishlist_item_model.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/wishlist_item.dart';
import 'package:doon_walkers/features/merchandise/domain/repositories/wishlist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Riverpod provider exposing the implementation of [WishlistRepository].
final wishlistRepositoryProvider = Provider<WishlistRepository>(
  (ref) => WishlistRepositoryImpl(ref.watch(supabaseClientProvider)),
  name: 'wishlistRepositoryProvider',
);

/// Embedded join so "My Wishlist" gets full product display fields
/// (including photos) in one round trip — mirrors
/// ProductRepositoryImpl's `_fullProductSelect` nesting one level
/// deeper under the wishlist row.
const _selectWithProduct = '*, products(*, product_images(*))';

/// Supabase implementation of [WishlistRepository].
class WishlistRepositoryImpl implements WishlistRepository {
  final SupabaseClient _supabase;

  const WishlistRepositoryImpl(this._supabase);

  /// The signed-in user's id, or throws if there's no session. Reads
  /// from the live session rather than a caller-supplied id —
  /// `user_wishlist_insert_own` requires `auth.uid() = user_id`, so
  /// deriving it here means the client can't wishlist a product on
  /// someone else's behalf.
  String get _currentUserId {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) {
      throw Exception('You need to be signed in to do that.');
    }
    return id;
  }

  @override
  Future<List<WishlistItem>> fetchMyWishlist() async {
    final rows = await _supabase
        .from(AppConstants.tableUserWishlist)
        .select(_selectWithProduct)
        .eq('user_id', _currentUserId)
        .order('created_at', ascending: false);
    return rows.map(WishlistItemModel.fromJson).toList();
  }

  @override
  Future<bool> isWishlisted(String productId) async {
    final row = await _supabase
        .from(AppConstants.tableUserWishlist)
        .select('id')
        .eq('user_id', _currentUserId)
        .eq('product_id', productId)
        .maybeSingle();
    return row != null;
  }

  @override
  Future<WishlistItem> addToWishlist(String productId) async {
    final row = await _supabase
        .from(AppConstants.tableUserWishlist)
        .insert({
          'user_id': _currentUserId,
          'product_id': productId,
        })
        .select(_selectWithProduct)
        .single();
    return WishlistItemModel.fromJson(row);
  }

  @override
  Future<void> removeFromWishlist(String productId) async {
    await _supabase
        .from(AppConstants.tableUserWishlist)
        .delete()
        .eq('user_id', _currentUserId)
        .eq('product_id', productId);
  }
}
