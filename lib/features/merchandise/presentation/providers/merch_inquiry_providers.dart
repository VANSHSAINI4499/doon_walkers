import 'dart:async';

import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/merchandise/data/repositories/merch_inquiry_repository_impl.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/merch_inquiry.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/merch_inquiry_pagination_provider.dart';
import 'package:doon_walkers/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:flutter/foundation.dart';
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

/// The signed-in user's 3 newest inquiries — backs the "My Inquiries"
/// dashboard preview on Profile ([MyInquiriesSection]) (Version 2,
/// Phase M2 fix). Fetching 3 rather than exactly the 2 displayed is
/// how [PreviewSection] decides whether to show "View All" without a
/// separate COUNT query — see that widget's doc.
///
/// Watches [authStateChangesProvider] so signing out (or switching
/// accounts) refetches rather than leaving the previous user's list
/// cached on screen — mirrors [myRegistrationsProvider] exactly.
final myMerchInquiriesPreviewProvider =
    FutureProvider.autoDispose<List<MerchInquiry>>((ref) {
      ref.watch(authStateChangesProvider);
      return ref
          .watch(merchInquiryRepositoryProvider)
          .fetchMyInquiries(limit: 3);
    }, name: 'myMerchInquiriesPreviewProvider');

/// Riverpod AsyncNotifier managing inquiry mutations (submit, admin
/// status change). Mirrors RegistrationController's shape: [state]
/// carries shared loading/error status, each method also returns its
/// own result.
final merchInquiryControllerProvider =
    AsyncNotifierProvider<MerchInquiryController, void>(
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
    required String phoneNumber,
  }) async {
    state = const AsyncLoading();
    MerchInquiry? created;
    state = await AsyncValue.guard(() async {
      created = await ref
          .read(merchInquiryRepositoryProvider)
          .createInquiry(
            productId: productId,
            variantId: variantId,
            quantity: quantity,
            note: note,
            phoneNumber: phoneNumber,
          );
    });
    // These are one-shot FutureProviders (see their own docs), so
    // without this, "My Inquiries" on Profile keeps showing its stale
    // pre-submit snapshot until something else tears the provider tree
    // down (e.g. sign-out/sign-in) — mirrors updateStatus below.
    if (created != null) {
      ref.invalidate(myMerchInquiriesPreviewProvider);
      ref.invalidate(myInquiriesPaginationProvider);
      ref.invalidate(allMerchInquiriesProvider);
    }
    return created;
  }

  /// Admin-only: updates [inquiry]'s status, then sends the requester a
  /// targeted push notification about it (Version 2, Phase M2 fix) —
  /// orchestrating both `MerchInquiryRepository` and
  /// `NotificationRepository` here rather than either repository
  /// reaching into the other's table, same shape as
  /// `RegistrationController.register` coordinating a registration
  /// insert with a Storage upload across two repositories.
  ///
  /// The notification send is best-effort: if it fails, the status
  /// change (the primary outcome) still stands — this only logs, it
  /// doesn't roll back the status update or fail the returned result.
  /// Server-side `merch_inquiries_update_admin` rejects the status
  /// write itself for any non-admin caller, so a mis-gated UI fails
  /// safely there regardless of the notification step.
  Future<bool> updateStatus(
    MerchInquiry inquiry,
    MerchInquiryStatus status,
  ) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await ref
          .read(merchInquiryRepositoryProvider)
          .updateStatus(inquiry.id, status);
      success = true;
    });

    if (success) {
      ref.invalidate(allMerchInquiriesProvider);
      ref.invalidate(myMerchInquiriesPreviewProvider);
      ref.invalidate(myInquiriesPaginationProvider);
      try {
        await ref
            .read(notificationRepositoryProvider)
            .createNotification(
              title: 'Inquiry Update',
              body:
                  'Your inquiry for "${inquiry.productName}" is now ${status.label}.',
              targetUserId: inquiry.userId,
            );
      } catch (e, st) {
        debugPrint(
          'MerchInquiryController.updateStatus: '
          'targeted notification failed (status change itself still succeeded): $e',
        );
        debugPrint('$st');
      }
    }
    return success;
  }
}
