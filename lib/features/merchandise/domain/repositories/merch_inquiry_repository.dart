import 'package:doon_walkers/features/merchandise/domain/entities/merch_inquiry.dart';

/// Abstract interface for submitting and managing "Buy Now" inquiries.
///
/// This is an inquiry-to-admin flow, not real checkout — submitting
/// creates a row an admin follows up on manually; there is no payment
/// step in this phase.
abstract class MerchInquiryRepository {
  /// Creates an inquiry for the signed-in user. [variantId] is null for
  /// a one-size product. [phoneNumber] is the contact number for THIS
  /// inquiry specifically (see MerchInquiry.phoneNumber's doc) — the
  /// form pre-fills it from the user's account phone but it's editable
  /// and always sent explicitly, never inferred server-side. RLS
  /// (`merch_inquiries_insert`) independently requires the row's
  /// `user_id` to be the caller and the caller to be an actual
  /// registered user, not just any authenticated session.
  Future<MerchInquiry> createInquiry({
    required String productId,
    String? variantId,
    required int quantity,
    String? note,
    required String phoneNumber,
  });

  /// Every inquiry across every product, newest first — admin roster
  /// only. RLS only actually returns every row to an admin caller; a
  /// non-admin gets just their own.
  Future<List<MerchInquiry>> fetchAllInquiries();

  /// The signed-in user's own inquiries, newest first — "My Inquiries"
  /// on Profile (Version 2, Phase M2 fix). Filtered explicitly *as
  /// well as* by RLS — the policy is the real boundary, but being
  /// explicit keeps this correct if an admin (who can select every
  /// row) opens their own profile, mirroring
  /// `RegistrationRepository.fetchMyRegistrations`' identical reasoning.
  Future<List<MerchInquiry>> fetchMyInquiries();

  /// Admin-only status change — updates this table only.
  /// `merch_inquiries_update_admin` RLS rejects this for any non-admin
  /// caller, so a mis-gated UI fails safely — see the migration's doc
  /// for why this table's UPDATE policy is admin-only outright rather
  /// than needing a field-level guard trigger the way
  /// payment_status/is_visible do.
  ///
  /// Sending the requester a targeted push notification on a status
  /// change (Version 2, Phase M2 fix) is deliberately NOT done here —
  /// that's a second table (`public.notifications`) this repository
  /// has no reason to know about. See
  /// `MerchInquiryController.updateStatus`, which orchestrates both
  /// this call and `NotificationRepository.createNotification`
  /// together, the same way `RegistrationController.register`
  /// orchestrates a registration insert plus a screenshot upload
  /// across two repositories rather than either repository reaching
  /// into the other's table.
  Future<void> updateStatus(String id, MerchInquiryStatus status);
}
