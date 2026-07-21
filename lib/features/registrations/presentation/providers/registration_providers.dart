import 'dart:async';

import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/registrations/data/repositories/registration_repository_impl.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
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
  }

  /// Registers the signed-in user for [trekId].
  ///
  /// Returns the created [Registration], or null on failure — in which
  /// case [state] carries the error. A [DuplicateRegistrationException]
  /// surfaces there too, so the caller can show the friendly
  /// already-registered message.
  Future<Registration?> register({
    required String trekId,
    required int age,
    required GenderType gender,
    required String emergencyContact,
    String? medicalNotes,
  }) async {
    state = const AsyncLoading();
    Registration? created;
    state = await AsyncValue.guard(() async {
      created = await ref.read(registrationRepositoryProvider).createRegistration(
            trekId: trekId,
            age: age,
            gender: gender,
            emergencyContact: emergencyContact,
            medicalNotes: medicalNotes,
          );
    });
    if (created != null) _invalidateRegistrationViews(trekId);
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
