import 'dart:typed_data';

abstract class ProfileRepository {
  /// Updates the user's display name.
  Future<void> updateDisplayName(String name);

  /// Compresses and uploads a photo to the `avatars` bucket, returning the public URL.
  Future<String> uploadAvatar(Uint8List imageBytes);

  /// Removes the user's current avatar.
  Future<void> removeAvatar();
}
