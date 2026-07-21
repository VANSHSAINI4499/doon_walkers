/// Maps 1-to-1 with the `payment_status` enum in Postgres
/// (`pending`, `paid`, `refunded`, `cancelled`) — see 0001_baseline_schema.sql.
///
/// This field is **admin-writable only**, enforced server-side by the
/// `prevent_payment_status_self_edit` trigger (Phase 2 security fix). A
/// user cancelling their own trek deletes their row instead of setting
/// this to `cancelled` — see [RegistrationRepository.deleteRegistration].
enum PaymentStatus {
  pending,
  paid,
  refunded,
  cancelled;

  /// Matches the Dart enum's identifier name exactly to the Postgres
  /// enum value — deliberately kept 1:1 so `.name` round-trips safely,
  /// same pattern as [MediaType] and [TrekDifficulty].
  static PaymentStatus fromString(String? value) {
    return PaymentStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => PaymentStatus.pending, // matches the DB column default
    );
  }

  String toDbString() => name;

  /// Human-readable label for the admin roster and the member's own list.
  String get label => switch (this) {
        PaymentStatus.pending => 'Pending',
        PaymentStatus.paid => 'Paid',
        PaymentStatus.refunded => 'Refunded',
        PaymentStatus.cancelled => 'Cancelled',
      };
}

/// Maps to the `gender_type` enum in Postgres
/// (`male`, `female`, `other`, `prefer_not_to_say`).
///
/// Unlike the other enums in this codebase this one canNOT use `.name`
/// to round-trip: Dart identifiers are lowerCamelCase while the Postgres
/// label is snake_case, so `preferNotToSay` != `prefer_not_to_say`. The
/// mapping is therefore explicit in both directions — keep the two
/// switches in sync if a value is ever added.
enum GenderType {
  male,
  female,
  other,
  preferNotToSay;

  static GenderType? fromString(String? value) => switch (value) {
        'male' => GenderType.male,
        'female' => GenderType.female,
        'other' => GenderType.other,
        'prefer_not_to_say' => GenderType.preferNotToSay,
        _ => null, // column is nullable — absent stays absent
      };

  String toDbString() => switch (this) {
        GenderType.male => 'male',
        GenderType.female => 'female',
        GenderType.other => 'other',
        GenderType.preferNotToSay => 'prefer_not_to_say',
      };

  String get label => switch (this) {
        GenderType.male => 'Male',
        GenderType.female => 'Female',
        GenderType.other => 'Other',
        GenderType.preferNotToSay => 'Prefer not to say',
      };
}

/// Core domain representation of a row in `public.registrations`,
/// optionally joined with the registrant's `public.users` row and the
/// `public.treks` row it belongs to.
///
/// [userName]/[userEmail]/[userPhone]/[trekTitle] come from those joined
/// tables rather than the registrations row itself — RLS on both is
/// admin-permissive (`users_select_own_or_admin`, `treks_select`), so an
/// admin genuinely gets every registrant's details back, not a silently
/// filtered subset.
///
/// [age], [gender], [emergencyContact] and [medicalNotes] are the
/// sensitive fields. `registrations_select` restricts them to the owning
/// user or an admin, so they are safe to carry on this entity — but they
/// are deliberately NOT rendered in any at-a-glance list, only in a
/// tapped-through detail view.
class Registration {
  final String id;
  final String trekId;
  final String userId;
  final PaymentStatus paymentStatus;
  final DateTime createdAt;

  // ── Registrant-supplied detail (sensitive) ──────────────────────
  final int? age;
  final GenderType? gender;
  final String? emergencyContact;
  final String? medicalNotes;

  /// Joined from `public.users`. [userPhone] is nullable in the schema —
  /// callers must handle a missing number rather than assume one exists.
  final String userName;
  final String userEmail;
  final String? userPhone;

  /// Joined from `public.treks`.
  final String trekTitle;

  /// The joined trek's scheduled start date (0010_trek_scheduling.sql),
  /// or null for an unscheduled trek — see [Trek.isUpcoming] for what
  /// "unscheduled" means. Drives [RegistrationStats]' automatic
  /// "attended" approximation (Part D): a registration counts as
  /// attended once this date has passed, per the user's explicit choice
  /// of date-based approximation over admin-marked attendance.
  final DateTime? trekDate;

  /// Path of the uploaded payment-proof screenshot in the private
  /// `payment-proofs` bucket (0011_payment_verification.sql) — a
  /// *path*, not a ready-to-use URL, since the bucket is private and
  /// every read needs a freshly-signed URL (see
  /// [RegistrationRepository.getPaymentProofSignedUrl]).
  ///
  /// Null for a free-trek registration, and briefly null for a
  /// paid-trek registration mid-flow (row created before the upload
  /// completes) — see [involvedPayment] for the derived "was this ever
  /// a paid registration" signal used to decide whether to show
  /// payment-status UI at all.
  final String? paymentScreenshotUrl;

  const Registration({
    required this.id,
    required this.trekId,
    required this.userId,
    required this.paymentStatus,
    required this.createdAt,
    this.age,
    this.gender,
    this.emergencyContact,
    this.medicalNotes,
    required this.userName,
    required this.userEmail,
    this.userPhone,
    required this.trekTitle,
    this.paymentScreenshotUrl,
    this.trekDate,
  });

  /// True when this registration required payment — derived from
  /// whether a screenshot was ever attached, not from the trek's
  /// *current* `registration_fee` (which could have changed since this
  /// registration was created). Drives whether member-facing UI shows
  /// any payment_status badge at all: a free-trek registration shows
  /// none ("nothing to verify"), per the Part C brief.
  bool get involvedPayment => paymentScreenshotUrl != null;

  /// Member-facing status label — only meaningful when [involvedPayment]
  /// is true; callers should check that first and render no badge at
  /// all otherwise. Relabels `pending` as "Pending Verification" for a
  /// paid registration, since "Pending" alone reads as "nothing has
  /// happened yet" rather than "we're waiting on you/admin to confirm
  /// the payment you already made". Every other status uses the same
  /// label admin sees — cosmetic label change only, not a new status.
  String get memberFacingStatusLabel =>
      paymentStatus == PaymentStatus.pending ? 'Pending Verification' : paymentStatus.label;
}

/// Thrown when an insert violates `UNIQUE(trek_id, user_id)` — i.e. the
/// user already has a registration for this trek.
///
/// Exists so the UI can say "You're already registered for this trek"
/// instead of leaking a raw Postgres 23505 constraint-violation string,
/// per the error-handling audit.
class DuplicateRegistrationException implements Exception {
  const DuplicateRegistrationException();

  @override
  String toString() => "You're already registered for this trek.";
}

/// Thrown when a paid-trek registration's row was created but its
/// payment screenshot failed to upload or link. By the time this is
/// thrown the row has already been rolled back (deleted) by
/// [RegistrationController.register] — there's no "add it later" flow
/// for a screenshot, so a half-registered row would otherwise be a
/// stuck, unpayable state. Distinct type so the UI can show this
/// specific message rather than the generic registration-failed one.
class PaymentScreenshotUploadException implements Exception {
  const PaymentScreenshotUploadException();

  @override
  String toString() =>
      'Could not upload your payment screenshot. Please try registering again.';
}

/// Thrown by [RegistrationController.register] when called for a trek
/// whose `trek_date` has already passed.
///
/// A deliberate app-level (not RLS) guard — this is a business
/// availability rule like `is_published`, not a security boundary the
/// way `payment_status` is: nothing sensitive leaks if it were somehow
/// bypassed, it would just create a semantically odd row. [TrekRegisterButton]
/// already hides the Register button for a completed trek; this exists
/// so a direct call to `register()` can't create one anyway, satisfying
/// "an actual guard, not just a hidden button" without adding a
/// trek-date subquery to every `registrations_insert`.
class TrekRegistrationClosedException implements Exception {
  const TrekRegistrationClosedException();

  @override
  String toString() => 'Registration is closed — this trek has already taken place.';
}
