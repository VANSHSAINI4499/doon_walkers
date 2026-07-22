import 'package:doon_walkers/features/merchandise/domain/entities/merch_inquiry.dart';

/// Abstract interface for submitting and managing "Buy Now" inquiries.
///
/// This is an inquiry-to-admin flow, not real checkout — submitting
/// creates a row an admin follows up on manually; there is no payment
/// step in this phase. Only [createInquiry] is member-facing; the rest
/// back the admin roster. There is deliberately no member-facing "my
/// past inquiries" list this phase — out of the explicit scope given
/// for this phase; a returning member's own inquiry history isn't
/// surfaced anywhere yet.
abstract class MerchInquiryRepository {
  /// Creates an inquiry for the signed-in user. [variantId] is null for
  /// a one-size product. RLS (`merch_inquiries_insert`) independently
  /// requires the row's `user_id` to be the caller and the caller to
  /// be an actual registered user, not just any authenticated session.
  Future<MerchInquiry> createInquiry({
    required String productId,
    String? variantId,
    required int quantity,
    String? note,
  });

  /// Every inquiry across every product, newest first — admin roster
  /// only. RLS only actually returns every row to an admin caller; a
  /// non-admin gets just their own (which this repository never calls
  /// this method to display, since there is no member-facing list).
  Future<List<MerchInquiry>> fetchAllInquiries();

  /// Admin-only status change. `merch_inquiries_update_admin` RLS
  /// rejects this for any non-admin caller, so a mis-gated UI fails
  /// safely — see the migration's doc for why this table's UPDATE
  /// policy is admin-only outright rather than needing a field-level
  /// guard trigger the way payment_status/is_visible do.
  Future<void> updateStatus(String id, MerchInquiryStatus status);
}
