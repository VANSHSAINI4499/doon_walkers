import 'package:doon_walkers/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:doon_walkers/features/settings/domain/entities/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Live-streamed `public.settings` content, shared by Home and About.
///
/// Backed by `.stream()` (Supabase Realtime + an initial fetch) rather
/// than a one-shot `.select()`, so an admin editing a row via the
/// Supabase dashboard shows up in the app without a rebuild — same
/// pattern as `currentUserProvider` in core/providers/supabase_provider.dart.
final settingsProvider = StreamProvider<AppSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watchSettings(),
  name: 'settingsProvider',
);
