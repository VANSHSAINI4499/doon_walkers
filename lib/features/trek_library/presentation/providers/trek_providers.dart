import 'dart:async';
import 'dart:typed_data';

import 'package:doon_walkers/features/trek_library/data/repositories/trek_repository_impl.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Published treks only — used by the public Trek Library screen for
/// every viewer, admin included. See [TrekRepository.fetchPublishedTreks].
///
/// One-shot fetch rather than `.stream()` — `treks` is the
/// highest-traffic table in the app (every guest hits Trek Library),
/// and edits are made by the same small admin team viewing this same
/// list, so a live-push channel per session isn't worth the cost. The
/// screen refetches via pull-to-refresh or the error state's Retry
/// button (`ref.invalidate(publishedTreksProvider)`).
///
/// [sortTreksForLibrary] runs here rather than in the repository, which
/// stays a plain data-access layer — ordering is a presentation rule.
final publishedTreksProvider = FutureProvider<List<Trek>>(
  (ref) async {
    final treks = await ref.watch(trekRepositoryProvider).fetchPublishedTreks();
    return sortTreksForLibrary(treks);
  },
  name: 'publishedTreksProvider',
);

/// All treks (published + draft) — admin trek list only. RLS returns
/// draft rows only when the caller is actually an admin; anyone else
/// gets the same result as [publishedTreksProvider].
///
/// One-shot fetch — same reasoning as [publishedTreksProvider]. Same
/// [sortTreksForLibrary] ordering as the public list, so an admin's view
/// doesn't reshuffle relative to what members see.
final adminAllTreksProvider = FutureProvider<List<Trek>>(
  (ref) async {
    final treks = await ref.watch(trekRepositoryProvider).fetchAllTreks();
    return sortTreksForLibrary(treks);
  },
  name: 'adminAllTreksProvider',
);

/// A single trek by id, for the Trek Detail screen. `autoDispose` since
/// detail pages are visited transiently — no reason to keep every trek
/// a user has ever opened cached for the whole app session.
final trekByIdProvider = FutureProvider.autoDispose.family<Trek?, String>(
  (ref, id) => ref.watch(trekRepositoryProvider).fetchTrekById(id),
  name: 'trekByIdProvider',
);

/// Thrown when a trek row was created/updated successfully but its
/// cover image or QR code image failed to upload — distinct from a
/// full failure so the form can show a more specific message than a
/// generic error.
class TrekImageUploadException implements Exception {
  const TrekImageUploadException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Riverpod AsyncNotifier managing admin trek mutations (create, update,
/// delete, publish toggle). Mirrors AuthController's shape: [state] is
/// shared loading/error status across all actions; each method also
/// returns its own result so callers don't have to read state.value.
final trekAdminControllerProvider = AsyncNotifierProvider<TrekAdminController, void>(
  TrekAdminController.new,
  name: 'trekAdminControllerProvider',
);

class TrekAdminController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Creates a trek (starts as a draft — see repository), then uploads
  /// the cover image if one was picked. Returns the created [Trek] even
  /// if the image upload step fails, since the row itself did save —
  /// [state] carries the [TrekImageUploadException] separately so the
  /// caller can distinguish "nothing saved" from "saved, image failed".
  Future<Trek?> createTrek({
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
    Uint8List? coverImageBytes,
    String? coverImageExtension,
    Uint8List? qrCodeBytes,
    String? qrCodeExtension,
  }) async {
    state = const AsyncLoading();
    Trek? created;
    state = await AsyncValue.guard(() async {
      final repo = ref.read(trekRepositoryProvider);
      final trek = await repo.createTrek(
        title: title,
        description: description,
        difficulty: difficulty,
        distanceKm: distanceKm,
        durationDays: durationDays,
        altitudeM: altitudeM,
        bestSeason: bestSeason,
        thingsToCarry: thingsToCarry,
        googleMapLink: googleMapLink,
        trekDate: trekDate,
        registrationFee: registrationFee,
      );
      created = trek;

      if (coverImageBytes != null && coverImageExtension != null) {
        try {
          await repo.uploadCoverImage(
            trekId: trek.id,
            bytes: coverImageBytes,
            fileExtension: coverImageExtension,
          );
        } catch (_) {
          throw const TrekImageUploadException(
            'Trek saved, but the cover image failed to upload. '
            'You can add it from Edit.',
          );
        }
      }

      // Only meaningful when registrationFee > 0 — the form doesn't
      // offer a QR picker at all for a free trek, so these should
      // always be null together in that case.
      if (qrCodeBytes != null && qrCodeExtension != null) {
        try {
          await repo.uploadPaymentQrCode(
            trekId: trek.id,
            bytes: qrCodeBytes,
            fileExtension: qrCodeExtension,
          );
        } catch (_) {
          throw const TrekImageUploadException(
            'Trek saved, but the payment QR code failed to upload. '
            'You can add it from Edit.',
          );
        }
      }
    });
    return created;
  }

  /// Updates a trek's fields, then replaces the cover image and/or QR
  /// code if new ones were picked. Same partial-failure semantics as
  /// [createTrek].
  Future<bool> updateTrek({
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
    Uint8List? coverImageBytes,
    String? coverImageExtension,
    String? previousCoverImageUrl,
    Uint8List? qrCodeBytes,
    String? qrCodeExtension,
    String? previousQrCodeUrl,
  }) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      final repo = ref.read(trekRepositoryProvider);
      await repo.updateTrek(
        id: id,
        title: title,
        description: description,
        difficulty: difficulty,
        distanceKm: distanceKm,
        durationDays: durationDays,
        altitudeM: altitudeM,
        bestSeason: bestSeason,
        thingsToCarry: thingsToCarry,
        googleMapLink: googleMapLink,
        trekDate: trekDate,
        registrationFee: registrationFee,
      );
      success = true;

      if (coverImageBytes != null && coverImageExtension != null) {
        try {
          await repo.uploadCoverImage(
            trekId: id,
            bytes: coverImageBytes,
            fileExtension: coverImageExtension,
            previousImageUrl: previousCoverImageUrl,
          );
        } catch (_) {
          throw const TrekImageUploadException(
            'Trek updated, but the new cover image failed to upload. '
            'The previous image (if any) is unchanged.',
          );
        }
      }

      if (qrCodeBytes != null && qrCodeExtension != null) {
        try {
          await repo.uploadPaymentQrCode(
            trekId: id,
            bytes: qrCodeBytes,
            fileExtension: qrCodeExtension,
            previousImageUrl: previousQrCodeUrl,
          );
        } catch (_) {
          throw const TrekImageUploadException(
            'Trek updated, but the new payment QR code failed to upload. '
            'The previous QR code (if any) is unchanged.',
          );
        }
      }
    });
    return success;
  }

  Future<bool> deleteTrek(String id) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await ref.read(trekRepositoryProvider).deleteTrek(id);
      success = true;
    });
    return success;
  }

  Future<bool> setPublished(String id, bool isPublished) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await ref.read(trekRepositoryProvider).setPublished(id, isPublished);
      success = true;
    });
    return success;
  }
}
