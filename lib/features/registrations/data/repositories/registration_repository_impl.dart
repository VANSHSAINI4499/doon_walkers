import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/registrations/data/models/registration_model.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:doon_walkers/features/registrations/domain/repositories/registration_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Riverpod provider exposing the implementation of [RegistrationRepository].
final registrationRepositoryProvider = Provider<RegistrationRepository>(
  (ref) => RegistrationRepositoryImpl(ref.watch(supabaseClientProvider)),
  name: 'registrationRepositoryProvider',
);

/// Columns selected for every read, including the embedded joins.
///
/// Embedded resources (`users(...)`, `treks(...)`) rather than a manual
/// join — PostgREST infers both from `registrations_user_id_fkey` and
/// `registrations_trek_id_fkey`. Verified neither embed gets silently
/// filtered: `users_select_own_or_admin` and `treks_select` both
/// short-circuit on `is_admin()`, which is SECURITY DEFINER so it reads
/// `users` outside RLS without recursion.
const _selectWithJoins = '*, users(name, email, phone), treks(title)';

/// Postgres unique-violation SQLSTATE — raised by `UNIQUE(trek_id, user_id)`.
const _uniqueViolation = '23505';

/// Supabase implementation of [RegistrationRepository].
class RegistrationRepositoryImpl implements RegistrationRepository {
  final SupabaseClient _supabase;

  const RegistrationRepositoryImpl(this._supabase);

  /// The signed-in user's id, or throws if there's no session.
  ///
  /// Reads from the live session rather than taking a caller-supplied id:
  /// `registrations_insert` requires `auth.uid() = user_id`, so deriving
  /// it here means the client can't even attempt to register on someone
  /// else's behalf.
  String get _currentUserId {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) {
      throw Exception('You need to be signed in to do that.');
    }
    return id;
  }

  @override
  Future<List<Registration>> fetchAllRegistrations() async {
    final rows = await _supabase
        .from(AppConstants.tableRegistrations)
        .select(_selectWithJoins)
        .order('created_at', ascending: false);

    return rows.map(RegistrationModel.fromJson).toList();
  }

  @override
  Future<Registration?> fetchRegistrationById(String id) async {
    final row = await _supabase
        .from(AppConstants.tableRegistrations)
        .select(_selectWithJoins)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return RegistrationModel.fromJson(row);
  }

  @override
  Future<List<Registration>> fetchMyRegistrations() async {
    // Filtered explicitly *as well as* by RLS. The policy is the real
    // boundary, but being explicit keeps this correct if an admin (who
    // can select every row) opens their own profile.
    final rows = await _supabase
        .from(AppConstants.tableRegistrations)
        .select(_selectWithJoins)
        .eq('user_id', _currentUserId)
        .order('created_at', ascending: false);

    return rows.map(RegistrationModel.fromJson).toList();
  }

  @override
  Future<Registration?> fetchMyRegistrationForTrek(String trekId) async {
    final row = await _supabase
        .from(AppConstants.tableRegistrations)
        .select(_selectWithJoins)
        .eq('user_id', _currentUserId)
        .eq('trek_id', trekId)
        .maybeSingle();
    if (row == null) return null;
    return RegistrationModel.fromJson(row);
  }

  @override
  Future<Registration> createRegistration({
    required String trekId,
    required int age,
    required GenderType gender,
    required String emergencyContact,
    String? medicalNotes,
  }) async {
    try {
      final row = await _supabase
          .from(AppConstants.tableRegistrations)
          .insert(RegistrationModel.toInsertJson(
            trekId: trekId,
            userId: _currentUserId,
            age: age,
            gender: gender,
            emergencyContact: emergencyContact,
            medicalNotes: medicalNotes,
          ))
          .select(_selectWithJoins)
          .single();
      return RegistrationModel.fromJson(row);
    } on PostgrestException catch (error) {
      // UNIQUE(trek_id, user_id) — translate to a domain exception here
      // so no layer above ever has to pattern-match on a SQLSTATE, and
      // the raw constraint string can't reach the UI.
      if (error.code == _uniqueViolation) {
        throw const DuplicateRegistrationException();
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteRegistration(String id) async {
    await _supabase.from(AppConstants.tableRegistrations).delete().eq('id', id);
  }

  @override
  Future<void> updatePaymentStatus(String id, PaymentStatus status) async {
    await _supabase
        .from(AppConstants.tableRegistrations)
        .update({'payment_status': status.toDbString()}).eq('id', id);
  }
}
