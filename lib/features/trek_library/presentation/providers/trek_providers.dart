import 'dart:async';
import 'dart:typed_data';

import 'package:doon_walkers/features/trek_library/data/repositories/trek_repository_impl.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Published treks only — used by the public Trek Library screen for
/// every viewer, admin included. See [TrekRepository.watchPublishedTreks].
final publishedTreksProvider = StreamProvider<List<Trek>>(
  (ref) => ref.watch(trekRepositoryProvider).watchPublishedTreks(),
  name: 'publishedTreksProvider',
);

/// All treks (published + draft) — admin trek list only. RLS returns
/// draft rows only when the caller is actually an admin; anyone else
/// gets the same result as [publishedTreksProvider].
final adminAllTreksProvider = StreamProvider<List<Trek>>(
  (ref) => ref.watch(trekRepositoryProvider).watchAllTreks(),
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
/// cover image failed to upload — distinct from a full failure so the
/// form can show a more specific message than a generic error.
class TrekCoverUploadException implements Exception {
  const TrekCoverUploadException(this.message);
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
  /// [state] carries the [TrekCoverUploadException] separately so the
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
    Uint8List? coverImageBytes,
    String? coverImageExtension,
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
          throw const TrekCoverUploadException(
            'Trek saved, but the cover image failed to upload. '
            'You can add it from Edit.',
          );
        }
      }
    });
    return created;
  }

  /// Updates a trek's fields, then replaces the cover image if a new
  /// one was picked. Same partial-failure semantics as [createTrek].
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
    Uint8List? coverImageBytes,
    String? coverImageExtension,
    String? previousCoverImageUrl,
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
          throw const TrekCoverUploadException(
            'Trek updated, but the new cover image failed to upload. '
            'The previous image (if any) is unchanged.',
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
