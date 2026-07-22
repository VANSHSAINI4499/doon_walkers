import 'dart:async';

import 'package:doon_walkers/features/merchandise/data/repositories/merch_inquiry_repository_impl.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/merch_inquiry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Every inquiry across every product — admin roster only.
///
/// One-shot fetch, not a live stream — same reasoning as every other
/// admin-managed list in this project (treks, registrations): a small
/// list the admin refreshes via pull-to-refresh, not worth an open
/// channel per session.
final allMerchInquiriesProvider = FutureProvider<List<MerchInquiry>>(
  (ref) => ref.watch(merchInquiryRepositoryProvider).fetchAllInquiries(),
  name: 'allMerchInquiriesProvider',
);

/// Riverpod AsyncNotifier managing inquiry mutations (submit, admin
/// status change). Mirrors RegistrationController's shape: [state]
/// carries shared loading/error status, each method also returns its
/// own result.
final merchInquiryControllerProvider = AsyncNotifierProvider<MerchInquiryController, void>(
  MerchInquiryController.new,
  name: 'merchInquiryControllerProvider',
);

class MerchInquiryController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<MerchInquiry?> submitInquiry({
    required String productId,
    String? variantId,
    required int quantity,
    String? note,
  }) async {
    state = const AsyncLoading();
    MerchInquiry? created;
    state = await AsyncValue.guard(() async {
      created = await ref.read(merchInquiryRepositoryProvider).createInquiry(
            productId: productId,
            variantId: variantId,
            quantity: quantity,
            note: note,
          );
    });
    return created;
  }

  /// Admin-only: updates [status]. Server-side
  /// `merch_inquiries_update_admin` rejects this for any non-admin
  /// caller, so a mis-gated UI fails safely.
  Future<bool> updateStatus(String id, MerchInquiryStatus status) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await ref.read(merchInquiryRepositoryProvider).updateStatus(id, status);
      success = true;
    });
    if (success) ref.invalidate(allMerchInquiriesProvider);
    return success;
  }
}
