import 'dart:typed_data';

import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';

/// Abstract interface for reading and managing treks.
///
/// The read methods (`fetchPublishedTreks`, `fetchAllTreks`,
/// `fetchTrekById`) are safe to call regardless of caller role — RLS
/// (0002_role_policies.sql) already restricts what rows come back.
/// The write methods are only ever exposed through admin-gated UI, but
/// RLS enforces the same admin-only rule server-side either way.
abstract class TrekRepository {
  /// Published treks only — used by the public Trek Library screen for
  /// every viewer, admin included. Filtered explicitly rather than left
  /// to RLS, so an admin browsing the public screen sees the same list
  /// a guest would; drafts are only visible in the dedicated admin list.
  ///
  /// One-shot fetch, not a live stream — see [publishedTreksProvider]'s
  /// doc for why this table isn't on Realtime.
  Future<List<Trek>> fetchPublishedTreks();

  /// All treks, published and draft. RLS only actually returns drafts
  /// to an admin caller — for anyone else this behaves the same as
  /// [fetchPublishedTreks]. Intended for the admin trek list only.
  ///
  /// One-shot fetch, not a live stream — see [adminAllTreksProvider]'s
  /// doc for why this table isn't on Realtime.
  Future<List<Trek>> fetchAllTreks();

  /// A single trek by id, or `null` if it doesn't exist *or* the caller
  /// isn't allowed to see it (e.g. a guest requesting a draft's id) —
  /// RLS makes those two cases indistinguishable, which is the point.
  Future<Trek?> fetchTrekById(String id);

  Future<Trek> createTrek({
    required String title,
    required String description,
    required TrekDifficulty difficulty,
    double? distanceKm,
    int? durationDays,
    int? altitudeM,
    String? bestSeason,
    String? thingsToCarry,
    String? googleMapLink,
    DateTime? trekDate,
    double registrationFee = 0,
  });

  Future<void> updateTrek({
    required String id,
    required String title,
    required String description,
    required TrekDifficulty difficulty,
    double? distanceKm,
    int? durationDays,
    int? altitudeM,
    String? bestSeason,
    String? thingsToCarry,
    String? googleMapLink,
    DateTime? trekDate,
    double registrationFee = 0,
  });

  /// Deletes the trek row. Best-effort deletes its cover image from
  /// Storage first (see impl) — Storage objects aren't tied to the row
  /// by a DB foreign key, so nothing does this automatically.
  Future<void> deleteTrek(String id);

  Future<void> setPublished(String id, bool isPublished);

  /// Uploads [bytes] to the `trek-covers` bucket under [trekId] and
  /// updates `treks.cover_image` with the resulting public URL. If
  /// [previousImageUrl] is provided, best-effort removes that old
  /// object afterwards. Always uploads to a fresh, timestamped path
  /// rather than overwriting — avoids serving a stale cached image at
  /// an unchanged URL after a replacement.
  Future<String> uploadCoverImage({
    required String trekId,
    required Uint8List bytes,
    required String fileExtension,
    String? previousImageUrl,
  });

  /// Uploads [bytes] to the same public `trek-covers` bucket
  /// [uploadCoverImage] uses (a QR code is meant to be publicly
  /// scannable, so it doesn't need the private `payment-proofs`
  /// bucket) and updates `treks.payment_qr_code`. Same fresh-path and
  /// best-effort-cleanup behaviour as [uploadCoverImage].
  Future<String> uploadPaymentQrCode({
    required String trekId,
    required Uint8List bytes,
    required String fileExtension,
    String? previousImageUrl,
  });
}
