import 'dart:typed_data';

import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/trek_library/data/models/trek_model.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:doon_walkers/features/trek_library/domain/repositories/trek_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Riverpod provider exposing the implementation of [TrekRepository].
final trekRepositoryProvider = Provider<TrekRepository>(
  (ref) => TrekRepositoryImpl(ref.watch(supabaseClientProvider)),
  name: 'trekRepositoryProvider',
);

/// Supabase implementation of [TrekRepository].
class TrekRepositoryImpl implements TrekRepository {
  final SupabaseClient _supabase;

  const TrekRepositoryImpl(this._supabase);

  @override
  Future<List<Trek>> fetchPublishedTreks() async {
    final rows = await _supabase
        .from(AppConstants.tableTreks)
        .select()
        .eq('is_published', true)
        .order('created_at', ascending: false);
    return rows.map(TrekModel.fromJson).toList();
  }

  @override
  Future<List<Trek>> fetchAllTreks() async {
    final rows = await _supabase
        .from(AppConstants.tableTreks)
        .select()
        .order('created_at', ascending: false);
    return rows.map(TrekModel.fromJson).toList();
  }

  @override
  Future<Trek?> fetchTrekById(String id) async {
    final row = await _supabase
        .from(AppConstants.tableTreks)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return TrekModel.fromJson(row);
  }

  @override
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
  }) async {
    final row = await _supabase
        .from(AppConstants.tableTreks)
        .insert(_writablePayload(
          title: title,
          description: description,
          difficulty: difficulty,
          distanceKm: distanceKm,
          durationDays: durationDays,
          altitudeM: altitudeM,
          bestSeason: bestSeason,
          thingsToCarry: thingsToCarry,
          googleMapLink: googleMapLink,
        ))
        .select()
        .single();
    // is_published isn't in the insert payload — it defaults to FALSE at
    // the DB level (0001_baseline_schema.sql), so every new trek starts
    // as a draft until explicitly published.
    return TrekModel.fromJson(row);
  }

  @override
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
  }) async {
    await _supabase
        .from(AppConstants.tableTreks)
        .update(_writablePayload(
          title: title,
          description: description,
          difficulty: difficulty,
          distanceKm: distanceKm,
          durationDays: durationDays,
          altitudeM: altitudeM,
          bestSeason: bestSeason,
          thingsToCarry: thingsToCarry,
          googleMapLink: googleMapLink,
        ))
        .eq('id', id);
  }

  @override
  Future<void> deleteTrek(String id) async {
    // Storage objects aren't tied to the row by a DB foreign key —
    // nothing cascades this automatically, so clean up the cover image
    // first. Best-effort: a failed cleanup shouldn't block deleting the
    // trek itself, it just leaves an orphaned file at worst.
    try {
      final row = await _supabase
          .from(AppConstants.tableTreks)
          .select('cover_image')
          .eq('id', id)
          .maybeSingle();
      final coverImage = row?['cover_image'] as String?;
      if (coverImage != null) {
        final path = _extractObjectPath(coverImage);
        if (path != null) {
          await _supabase.storage.from(AppConstants.bucketTrekCovers).remove([path]);
        }
      }
    } catch (_) {
      // Orphaned file at worst — not worth failing the delete over.
    }

    await _supabase.from(AppConstants.tableTreks).delete().eq('id', id);
  }

  @override
  Future<void> setPublished(String id, bool isPublished) async {
    await _supabase
        .from(AppConstants.tableTreks)
        .update({'is_published': isPublished}).eq('id', id);
  }

  @override
  Future<String> uploadCoverImage({
    required String trekId,
    required Uint8List bytes,
    required String fileExtension,
    String? previousImageUrl,
  }) async {
    // Always a fresh path, never an overwrite — reusing the same path
    // on replacement risks the browser/CDN serving a stale cached image
    // at an unchanged URL.
    final path = '$trekId/${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    await _supabase.storage
        .from(AppConstants.bucketTrekCovers)
        .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: false));

    final newUrl = _supabase.storage.from(AppConstants.bucketTrekCovers).getPublicUrl(path);

    if (previousImageUrl != null) {
      try {
        final oldPath = _extractObjectPath(previousImageUrl);
        if (oldPath != null) {
          await _supabase.storage.from(AppConstants.bucketTrekCovers).remove([oldPath]);
        }
      } catch (_) {
        // Same reasoning as deleteTrek — don't fail a successful upload
        // over a failed cleanup of the old file.
      }
    }

    await _supabase
        .from(AppConstants.tableTreks)
        .update({'cover_image': newUrl}).eq('id', trekId);

    return newUrl;
  }

  Map<String, dynamic> _writablePayload({
    required String title,
    required String description,
    required TrekDifficulty difficulty,
    double? distanceKm,
    int? durationDays,
    int? altitudeM,
    String? bestSeason,
    String? thingsToCarry,
    String? googleMapLink,
  }) {
    return {
      'title': title,
      'description': description,
      'difficulty': difficulty.toDbString(),
      'distance_km': distanceKm,
      'duration_days': durationDays,
      'altitude_m': altitudeM,
      'best_season': bestSeason,
      'things_to_carry': thingsToCarry,
      'google_map_link': googleMapLink,
    };
  }

  /// Extracts the object path from a Supabase Storage public URL
  /// (`.../storage/v1/object/public/{bucket}/{path}`). Returns null if
  /// the URL doesn't match that shape — defensive against a malformed
  /// or manually-edited cover_image value.
  String? _extractObjectPath(String publicUrl) {
    const marker = '/object/public/${AppConstants.bucketTrekCovers}/';
    final index = publicUrl.indexOf(marker);
    if (index == -1) return null;
    return publicUrl.substring(index + marker.length);
  }
}
