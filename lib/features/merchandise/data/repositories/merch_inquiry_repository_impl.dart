import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/merchandise/data/models/merch_inquiry_model.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/merch_inquiry.dart';
import 'package:doon_walkers/features/merchandise/domain/repositories/merch_inquiry_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Riverpod provider exposing the implementation of
/// [MerchInquiryRepository].
final merchInquiryRepositoryProvider = Provider<MerchInquiryRepository>(
  (ref) => MerchInquiryRepositoryImpl(ref.watch(supabaseClientProvider)),
  name: 'merchInquiryRepositoryProvider',
);

/// Embedded joins the admin roster needs — same PostgREST
/// foreign-key-inference pattern `RegistrationRepositoryImpl` uses for
/// `users(...)`/`treks(...)`.
const _selectWithJoins =
    '*, products(name), product_variants(size), users(name, email, phone)';

/// Supabase implementation of [MerchInquiryRepository].
class MerchInquiryRepositoryImpl implements MerchInquiryRepository {
  final SupabaseClient _supabase;

  const MerchInquiryRepositoryImpl(this._supabase);

  /// The signed-in user's id, or throws if there's no session. Reads
  /// from the live session rather than a caller-supplied id —
  /// `merch_inquiries_insert` requires `auth.uid() = user_id`, so
  /// deriving it here means the client can't attempt to submit an
  /// inquiry on someone else's behalf.
  String get _currentUserId {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) {
      throw Exception('You need to be signed in to do that.');
    }
    return id;
  }

  @override
  Future<MerchInquiry> createInquiry({
    required String productId,
    String? variantId,
    required int quantity,
    String? note,
  }) async {
    final row = await _supabase
        .from(AppConstants.tableMerchInquiries)
        .insert({
          'user_id': _currentUserId,
          'product_id': productId,
          'variant_id': variantId,
          'quantity': quantity,
          'note': note,
        })
        .select(_selectWithJoins)
        .single();
    return MerchInquiryModel.fromJson(row);
  }

  @override
  Future<List<MerchInquiry>> fetchAllInquiries() async {
    final rows = await _supabase
        .from(AppConstants.tableMerchInquiries)
        .select(_selectWithJoins)
        .order('created_at', ascending: false);
    return rows.map(MerchInquiryModel.fromJson).toList();
  }

  @override
  Future<void> updateStatus(String id, MerchInquiryStatus status) async {
    await _supabase
        .from(AppConstants.tableMerchInquiries)
        .update({'status': status.toDbString()}).eq('id', id);
  }
}
