import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';

/// Abstract interface for reading and managing trek registrations.
///
/// Every method here is backed by RLS on `public.registrations`
/// (0002_role_policies.sql) — the UI gating is convenience, the policies
/// are the boundary:
///   - `registrations_select`: `auth.uid() = user_id OR is_admin()`
///   - `registrations_insert`: `auth.uid() = user_id AND is_registered_user_or_admin()`
///   - `registrations_update`: own row or admin, **and** `payment_status`
///     is additionally restricted to admins by the
///     `prevent_payment_status_self_edit` trigger
///   - `registrations_delete`: own row or admin
abstract class RegistrationRepository {
  /// Every registration across every trek — admin roster only. Joined
  /// with registrant name/email/phone and trek title.
  ///
  /// One-shot fetch rather than `.stream()` — `registrations` isn't on
  /// the Realtime publication, and a roster an admin reviews
  /// occasionally doesn't justify an open websocket channel.
  Future<List<Registration>> fetchAllRegistrations();

  /// A single registration by id, with the same joins — backs the admin
  /// detail view. Returns null if it doesn't exist *or* the caller isn't
  /// allowed to see it; RLS makes those indistinguishable on purpose.
  Future<Registration?> fetchRegistrationById(String id);

  /// The signed-in user's own registrations, newest first.
  ///
  /// Relies on `registrations_select` to scope the result rather than
  /// filtering client-side, so a policy change can't silently widen what
  /// this returns.
  Future<List<Registration>> fetchMyRegistrations();

  /// The signed-in user's registration for [trekId], or null if they
  /// haven't registered. Drives the Trek Detail button state so an
  /// already-registered user sees that up front rather than discovering
  /// it by hitting the UNIQUE constraint on submit.
  Future<Registration?> fetchMyRegistrationForTrek(String trekId);

  /// Creates a registration for the signed-in user.
  ///
  /// `payment_status` is intentionally not a parameter — it defaults to
  /// `'pending'` server-side and is admin-writable only.
  ///
  /// Throws [DuplicateRegistrationException] when the user already has a
  /// registration for this trek (`UNIQUE(trek_id, user_id)`), so callers
  /// can show a friendly message instead of a raw 23505 error.
  Future<Registration> createRegistration({
    required String trekId,
    required int age,
    required GenderType gender,
    required String emergencyContact,
    String? medicalNotes,
  });

  /// Deletes a registration row.
  ///
  /// This is how *self-service cancellation* works — a user may never
  /// set their own `payment_status` (not even to `cancelled`), so
  /// withdrawing means removing the row. `registrations_delete` allows
  /// own-row or admin.
  Future<void> deleteRegistration(String id);

  /// Admin-only: sets `payment_status`.
  ///
  /// The `prevent_payment_status_self_edit` trigger raises for any
  /// non-admin caller, so this fails server-side even if the UI were
  /// mis-gated. This is the intended use of that guard, not a bypass.
  Future<void> updatePaymentStatus(String id, PaymentStatus status);
}
