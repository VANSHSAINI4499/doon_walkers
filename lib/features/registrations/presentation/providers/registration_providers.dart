import 'dart:async';
import 'dart:typed_data';

import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/registrations/data/repositories/registration_repository_impl.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration_stats.dart';
import 'package:doon_walkers/features/registrations/domain/entities/trekking_streak.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Every registration across every trek — admin roster screen only.
///
/// One-shot fetch (see [RegistrationRepository] for why this isn't a
/// live stream). Refresh via pull-to-refresh or the error state's Retry
/// button, both of which `ref.invalidate` this.
final allRegistrationsProvider = FutureProvider<List<Registration>>(
  (ref) => ref.watch(registrationRepositoryProvider).fetchAllRegistrations(),
  name: 'allRegistrationsProvider',
);

/// A single registration by id — backs the admin detail view.
/// `autoDispose` since detail pages are visited transiently.
final registrationByIdProvider =
    FutureProvider.autoDispose.family<Registration?, String>(
  (ref, id) => ref.watch(registrationRepositoryProvider).fetchRegistrationById(id),
  name: 'registrationByIdProvider',
);

/// Registrations for one trek — Admin Dashboard's per-trek roster.
/// `autoDispose` since it's a transiently-visited screen, same reasoning
/// as [registrationByIdProvider].
final registrationsForTrekProvider =
    FutureProvider.autoDispose.family<List<Registration>, String>(
  (ref, trekId) => ref.watch(registrationRepositoryProvider).fetchRegistrationsForTrek(trekId),
  name: 'registrationsForTrekProvider',
);

/// The signed-in user's own registrations — "My Registrations" on Profile.
///
/// Watches [authStateChangesProvider] so signing out (or switching
/// accounts) refetches rather than leaving the previous user's list
/// cached on screen.
final myRegistrationsProvider = FutureProvider<List<Registration>>(
  (ref) {
    ref.watch(authStateChangesProvider);
    return ref.watch(registrationRepositoryProvider).fetchMyRegistrations();
  },
  name: 'myRegistrationsProvider',
);

/// The signed-in user's registration for a given trek, or null.
///
/// Drives the Trek Detail button so an already-registered user is told
/// so up front, instead of finding out by tripping the UNIQUE constraint
/// on submit. Returns null for a guest rather than throwing — the button
/// shows "Register" and [AuthGuard] handles the sign-in bounce.
final myRegistrationForTrekProvider =
    FutureProvider.autoDispose.family<Registration?, String>(
  (ref, trekId) async {
    ref.watch(authStateChangesProvider);
    final supabase = ref.watch(supabaseClientProvider);
    if (supabase.auth.currentUser == null) return null;
    return ref.watch(registrationRepositoryProvider).fetchMyRegistrationForTrek(trekId);
  },
  name: 'myRegistrationForTrekProvider',
);

/// Profile stats (Part D) — derived from [myRegistrationsProvider] rather
/// than a separate fetch, so it always agrees with "My Registrations" and
/// invalidates on the same triggers (register/cancel/status change).
final myRegistrationStatsProvider = FutureProvider<RegistrationStats>(
  (ref) async {
    final registrations = await ref.watch(myRegistrationsProvider.future);
    return RegistrationStats.fromRegistrations(registrations);
  },
  name: 'myRegistrationStatsProvider',
);

/// The signed-in user's attendance streak (Version 2, Phase C3) — see
/// TrekkingStreak's doc. Watches [authStateChangesProvider] the same
/// way [myRegistrationsProvider] does, so a sign-in/out is reflected
/// without a stale cached value lingering.
final myStreakProvider = FutureProvider<TrekkingStreak>(
  (ref) {
    ref.watch(authStateChangesProvider);
    return ref.watch(registrationRepositoryProvider).fetchMyStreak();
  },
  name: 'myStreakProvider',
);

/// A short-lived signed URL for a payment-proof screenshot at [path]
/// (the private `payment-proofs` bucket has no public URL — see
/// RegistrationRepository.getPaymentProofSignedUrl). `autoDispose`
/// since the signed URL expires anyway; re-fetching a fresh one on
/// every visit to the detail screen is the point, not a waste.
final paymentProofSignedUrlProvider =
    FutureProvider.autoDispose.family<String, String>(
  (ref, path) => ref.watch(registrationRepositoryProvider).getPaymentProofSignedUrl(path),
  name: 'paymentProofSignedUrlProvider',
);

/// Riverpod AsyncNotifier managing registration mutations (create,
/// cancel, admin status change). Mirrors [TrekAdminController]'s shape:
/// [state] carries shared loading/error status, while each method also
/// returns its own result so callers don't have to read `state.value`.
final registrationControllerProvider =
    AsyncNotifierProvider<RegistrationController, void>(
  RegistrationController.new,
  name: 'registrationControllerProvider',
);

class RegistrationController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Refetches every surface a registration change can appear on.
  /// These are one-shot FutureProviders, so nothing updates without it.
  void _invalidateRegistrationViews(String trekId) {
    ref.invalidate(myRegistrationsProvider);
    ref.invalidate(myRegistrationForTrekProvider(trekId));
    ref.invalidate(allRegistrationsProvider);
    ref.invalidate(registrationsForTrekProvider(trekId));
  }

  /// Registers the signed-in user for [trek].
  ///
  /// Takes the whole [Trek], not just its id, so this can guard on
  /// [Trek.isCompleted] itself rather than trusting the caller to have
  /// checked — [TrekRegisterButton] already hides the Register button
  /// for a completed trek, but that's UI-only; this is the "actual
  /// guard" so a direct call here can't create one anyway. See
  /// [TrekRegistrationClosedException] for why this is enforced here
  /// and not in `registrations_insert`'s RLS.
  ///
  /// When [paymentScreenshotBytes] is provided (paid trek), the sequence
  /// is create row → upload screenshot → link path onto the row — the
  /// bucket's INSERT policy requires the registration to already exist
  /// (see uploadPaymentScreenshot's doc), so this order is required, not
  /// arbitrary. If the upload or link step fails, the just-created row
  /// is deleted (best-effort) rather than left behind screenshot-less:
  /// there's no "add it later" flow, so a stuck half-registered paid
  /// row would otherwise be unrecoverable except by the user manually
  /// cancelling it themselves.
  ///
  /// Returns the created [Registration], or null on failure — in which
  /// case [state] carries the error. A [DuplicateRegistrationException]
  /// or [TrekRegistrationClosedException] surfaces there too, so the
  /// caller can show the friendly, specific message.
  Future<Registration?> register({
    required Trek trek,
    required int age,
    required GenderType gender,
    required String emergencyContact,
    String? medicalNotes,
    Uint8List? paymentScreenshotBytes,
    String? paymentScreenshotExtension,
  }) async {
    if (trek.isCompleted) {
      state = AsyncError(const TrekRegistrationClosedException(), StackTrace.current);
      return null;
    }

    state = const AsyncLoading();
    Registration? created;
    state = await AsyncValue.guard(() async {
      final repo = ref.read(registrationRepositoryProvider);
      final registration = await repo.createRegistration(
        trekId: trek.id,
        age: age,
        gender: gender,
        emergencyContact: emergencyContact,
        medicalNotes: medicalNotes,
      );

      if (paymentScreenshotBytes == null || paymentScreenshotExtension == null) {
        created = registration;
        return;
      }

      try {
        final path = await repo.uploadPaymentScreenshot(
          registrationId: registration.id,
          bytes: paymentScreenshotBytes,
          fileExtension: paymentScreenshotExtension,
        );
        await repo.setPaymentScreenshotPath(registration.id, path);
      } catch (_) {
        try {
          await repo.deleteRegistration(registration.id);
        } catch (_) {
          // Best-effort rollback — if even this fails there's nothing
          // more to safely do here; the exception below still surfaces.
        }
        throw const PaymentScreenshotUploadException();
      }

      // Re-fetch rather than trust the pre-upload snapshot, so the
      // returned Registration actually carries paymentScreenshotUrl.
      created = await repo.fetchRegistrationById(registration.id) ?? registration;
    });
    if (created != null) _invalidateRegistrationViews(trek.id);
    return created;
  }

  /// Cancels (deletes) a registration. [trekId] is passed so the trek's
  /// own button state can be refreshed alongside the lists.
  Future<bool> cancel({required String id, required String trekId}) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await ref.read(registrationRepositoryProvider).deleteRegistration(id);
      success = true;
    });
    if (success) _invalidateRegistrationViews(trekId);
    return success;
  }

  /// Admin-only: updates `payment_status`.
  ///
  /// Server-side the `prevent_payment_status_self_edit` trigger rejects
  /// this for any non-admin caller, so a mis-gated UI fails safely.
  Future<bool> setPaymentStatus({
    required String id,
    required String trekId,
    required PaymentStatus status,
  }) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await ref.read(registrationRepositoryProvider).updatePaymentStatus(id, status);
      success = true;
    });
    if (success) {
      _invalidateRegistrationViews(trekId);
      ref.invalidate(registrationByIdProvider(id));
    }
    return success;
  }
}
