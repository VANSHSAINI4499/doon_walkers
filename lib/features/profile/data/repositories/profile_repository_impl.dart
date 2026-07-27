import 'dart:typed_data';
import 'package:doon_walkers/features/profile/domain/repositories/profile_repository.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<void> updateDisplayName(String name) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _supabase.rpc(
      'update_profile',
      params: {'p_display_name': name.trim()},
    );
  }

  @override
  Future<String> uploadAvatar(Uint8List imageBytes) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Compress/resize image to max 512x512 and max 200KB quality
    final compressedBytes = await FlutterImageCompress.compressWithList(
      imageBytes,
      minWidth: 512,
      minHeight: 512,
      quality: 80,
      format: CompressFormat.jpeg,
    );

    final uploadBytes =
        compressedBytes.isNotEmpty ? compressedBytes : imageBytes;
    final path = '${user.id}/avatar.jpg';

    // Upload to avatars bucket with upsert = true
    await _supabase.storage
        .from('avatars')
        .uploadBinary(
          path,
          uploadBytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    final publicUrl = _supabase.storage.from('avatars').getPublicUrl(path);
    // Append a timestamp parameter to bust network cache when image is re-uploaded
    final cacheBustedUrl =
        '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

    await _supabase.rpc(
      'update_profile',
      params: {'p_avatar_url': cacheBustedUrl},
    );

    return cacheBustedUrl;
  }

  @override
  Future<void> removeAvatar() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _supabase.rpc('update_profile', params: {'p_clear_avatar': true});
  }
}
