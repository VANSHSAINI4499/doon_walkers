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
  });
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
