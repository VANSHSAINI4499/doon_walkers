import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';

/// Serialisation layer for [Registration].
///
/// [fromJson] expects the PostgREST embedded-resource shape produced by
/// `.select('*, users(name, email, phone), treks(title, trek_date)')` —
/// i.e. the
/// joined rows arrive as nested maps under `users` / `treks`, inferred
/// from `registrations_user_id_fkey` and `registrations_trek_id_fkey`.
///
/// Both nested maps are treated as *possibly* absent and every field
/// defaulted, so a malformed or partially-selected row degrades to
/// readable placeholder text instead of throwing mid-list — the same
/// defensive posture as [GalleryMediaModel] and [TrekModel].
class RegistrationModel {
  const RegistrationModel._();

  static Registration fromJson(Map<String, dynamic> json) {
    final user = json['users'] as Map<String, dynamic>?;
    final trek = json['treks'] as Map<String, dynamic>?;

    return Registration(
      id: json['id'] as String,
      trekId: json['trek_id'] as String,
      userId: json['user_id'] as String,
      paymentStatus: PaymentStatus.fromString(json['payment_status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      age: (json['age'] as num?)?.toInt(),
      gender: GenderType.fromString(json['gender'] as String?),
      emergencyContact: _emptyToNull(json['emergency_contact'] as String?),
      medicalNotes: _emptyToNull(json['medical_notes'] as String?),
      userName: (user?['name'] as String?) ?? 'Unknown member',
      userEmail: (user?['email'] as String?) ?? '—',
      userPhone: _emptyToNull(user?['phone'] as String?),
      trekTitle: (trek?['title'] as String?) ?? 'Unknown trek',
      paymentScreenshotUrl: json['payment_screenshot_url'] as String?,
      trekDate: trek?['trek_date'] != null
          ? DateTime.parse(trek!['trek_date'] as String)
          : null,
    );
  }

  /// Payload for creating a registration.
  ///
  /// Deliberately omits `payment_status`: the column defaults to
  /// `'pending'` at the DB level, and the `prevent_payment_status_self_edit`
  /// trigger makes it admin-writable only — the client must never set it.
  /// `user_id` is passed explicitly because `registrations_insert`
  /// requires `auth.uid() = user_id`.
  static Map<String, dynamic> toInsertJson({
    required String trekId,
    required String userId,
    required int age,
    required GenderType gender,
    required String emergencyContact,
    String? medicalNotes,
  }) {
    return {
      'trek_id': trekId,
      'user_id': userId,
      'age': age,
      'gender': gender.toDbString(),
      'emergency_contact': emergencyContact,
      'medical_notes': medicalNotes,
    };
  }

  /// Normalises whitespace-only text to null so the UI has exactly one
  /// "not provided" case to render.
  static String? _emptyToNull(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }
}
