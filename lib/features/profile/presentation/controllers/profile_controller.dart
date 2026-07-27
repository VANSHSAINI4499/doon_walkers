import 'dart:typed_data';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:doon_walkers/features/profile/domain/repositories/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ProfileRepositoryImpl(supabase);
});

final profileControllerProvider =
    StateNotifierProvider<ProfileController, AsyncValue<void>>((ref) {
      return ProfileController(ref);
    });

class ProfileController extends StateNotifier<AsyncValue<void>> {
  ProfileController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  ProfileRepository get _repository => _ref.read(profileRepositoryProvider);

  Future<bool> updateDisplayName(String name) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateDisplayName(name);
      _ref.invalidate(currentUserProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> uploadAvatarFromGallery() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (file == null) return false;

    state = const AsyncValue.loading();
    try {
      final Uint8List bytes = await file.readAsBytes();
      await _repository.uploadAvatar(bytes);
      _ref.invalidate(currentUserProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> removeAvatar() async {
    state = const AsyncValue.loading();
    try {
      await _repository.removeAvatar();
      _ref.invalidate(currentUserProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}
