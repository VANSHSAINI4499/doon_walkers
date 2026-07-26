import 'dart:typed_data';

import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/registrations/data/models/registration_model.dart';
import 'package:doon_walkers/features/registrations/data/models/trekking_streak_model.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:doon_walkers/features/registrations/domain/entities/trekking_streak.dart';
import 'package:doon_walkers/features/registrations/domain/repositories/registration_repository.dart';
import 'package:flutter/foundation.dart';
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
const _selectWithJoins = '*, users(name, email, phone), treks(title, trek_date)';

/// Postgres unique-violation SQLSTATE — raised by `UNIQUE(trek_id, user_id)`.
const _uniqueViolation = '23505';

/// Custom SQLSTATEs `verify_trek_checkin` (0030_trek_checkin_verify.sql)
/// raises with explicitly, in the exact order the RPC checks them —
/// same pattern as `_blocklistViolation`/`CommentBlocklistException` in
/// comment_repository_impl.dart, matched here instead of on a bare-RAISE
/// default `P0001` so each rejection reason stays distinguishable.
const _checkinErrorReasons = {
  'DWC01': TrekCheckinFailureReason.notRegistered,
  'DWC02': TrekCheckinFailureReason.invalidToken,
  'DWC03': TrekCheckinFailureReason.notScheduled,
  'DWC04': TrekCheckinFailureReason.windowNotOpen,
  'DWC05': TrekCheckinFailureReason.windowClosed,
  'DWC06': TrekCheckinFailureReason.alreadyCheckedIn,
};

String _checkinFailureMessage(TrekCheckinFailureReason reason) => switch (reason) {
      TrekCheckinFailureReason.notRegistered => "You're not registered for this trek.",
      TrekCheckinFailureReason.invalidToken => "This QR code isn't valid for this trek.",
      TrekCheckinFailureReason.notScheduled => 'Check-in is not available for this trek.',
      TrekCheckinFailureReason.windowNotOpen => "Check-in hasn't opened yet.",
      TrekCheckinFailureReason.windowClosed => 'Check-in window has closed.',
      TrekCheckinFailureReason.alreadyCheckedIn => "You're already checked in.",
    };

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
  Future<List<Registration>> fetchRegistrationsForTrek(String trekId) async {
    final rows = await _supabase
        .from(AppConstants.tableRegistrations)
        .select(_selectWithJoins)
        .eq('trek_id', trekId)
        .order('created_at', ascending: false);

    return rows.map(RegistrationModel.fromJson).toList();
  }

  @override
  Future<List<Registration>> fetchMyRegistrations({int? limit}) async {
    // Filtered explicitly *as well as* by RLS. The policy is the real
    // boundary, but being explicit keeps this correct if an admin (who
    // can select every row) opens their own profile.
    final query = _supabase
        .from(AppConstants.tableRegistrations)
        .select(_selectWithJoins)
        .eq('user_id', _currentUserId)
        .order('created_at', ascending: false);
    final rows = limit != null ? await query.limit(limit) : await query;

    return rows.map(RegistrationModel.fromJson).toList();
  }

  @override
  Future<List<Registration>> fetchMyRegistrationsPage({
    required int page,
    required int pageSize,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;
    final rows = await _supabase
        .from(AppConstants.tableRegistrations)
        .select(_selectWithJoins)
        .eq('user_id', _currentUserId)
        .order('created_at', ascending: false)
        .range(from, to);

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

  @override
  Future<String> uploadPaymentScreenshot({
    required String registrationId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    // {registrationId}/{filename} — the payment_proofs_insert policy
    // reads the first path segment as the registration id and checks it
    // against a real row owned by the caller (see 0011's migration
    // comment). A fresh timestamped filename, never an overwrite, same
    // reasoning as trek cover images.
    final path =
        '$registrationId/${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    await _supabase.storage
        .from(AppConstants.bucketPaymentProofs)
        .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: false));

    return path;
  }

  @override
  Future<void> setPaymentScreenshotPath(String registrationId, String path) async {
    await _supabase
        .from(AppConstants.tableRegistrations)
        .update({'payment_screenshot_url': path}).eq('id', registrationId);
  }

  @override
  Future<String> getPaymentProofSignedUrl(String path) async {
    // 10 minutes — long enough to load one Image.network call, short
    // enough that a leaked/cached URL doesn't stay useful for long.
    // Bucket is private, so this is the only way to ever view a proof.
    return _supabase.storage
        .from(AppConstants.bucketPaymentProofs)
        .createSignedUrl(path, 600);
  }

  @override
  Future<TrekkingStreak> fetchMyStreak() async {
    final rows = await _supabase.rpc(AppConstants.rpcGetMyStreak) as List;
    if (rows.isEmpty) return TrekkingStreak.zero;
    return TrekkingStreakModel.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<DateTime> verifyCheckin({
    required String trekId,
    required String scannedToken,
  }) async {
    try {
      // A scalar-returning function (timestamptz), not RETURNS TABLE —
      // PostgREST hands the raw value straight back, not wrapped in a
      // List the way the TABLE-returning challenge RPCs are.
      final result = await _supabase.rpc(
        AppConstants.rpcVerifyTrekCheckin,
        params: {'p_trek_id': trekId, 'p_token': scannedToken},
      );
      final checkedInAt = DateTime.parse(result as String);

      // Award 100 points for the check-in — fire-and-forget. The user
      // already got their check-in confirmed above; a points failure
      // here should never surface as an error to them. award_points()
      // is SECURITY DEFINER and idempotent-safe for ledger inserts.
      final uid = _supabase.auth.currentUser?.id;
      if (uid != null) {
        _supabase.rpc('award_points', params: {
          'p_user_id': uid,
          'p_points': 100,
          'p_reason': 'trek_checkin',
          'p_reference_id': trekId,
        }).catchError((e) {
          debugPrint('verifyCheckin: award_points failed (non-fatal): $e');
        });
      }

      return checkedInAt;
    } on PostgrestException catch (error) {
      final reason = _checkinErrorReasons[error.code];
      if (reason != null) {
        throw TrekCheckinException(reason, _checkinFailureMessage(reason));
      }
      rethrow;
    }
  }
}

