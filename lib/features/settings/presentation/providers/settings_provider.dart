import 'package:doon_walkers/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:doon_walkers/features/settings/domain/entities/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `public.settings` content, shared by Home and About.
///
/// One-shot fetch rather than `.stream()` — community info changes
/// rarely, so it isn't worth holding a Realtime channel open for it.
/// Refetches via the error state's Retry button (`ref.invalidate`).
final settingsProvider = FutureProvider<AppSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).fetchSettings(),
  name: 'settingsProvider',
);
