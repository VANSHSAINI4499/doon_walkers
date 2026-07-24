import 'package:doon_walkers/core/icons/app_icons.dart';
import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Maps a challenge's `icon` column (a small known identifier string,
/// e.g. 'hiking') to an [IconData] — see the Challenge entity's doc for
/// why this is a string key rather than an image reference. [keys] is the
/// fixed vocabulary the admin form's picker offers; [forKey] is what the
/// member-facing challenge UI uses to render the same icon.
///
/// Redesign Phase 4: the glyphs now resolve to Material Symbols Rounded
/// (the design system's icon family) instead of the old Material Icons —
/// the string keys and the picker vocabulary are unchanged, so no stored
/// `icon` value needs migrating. Render with [AppIcon] so they draw
/// filled, like every other icon in the app.
abstract final class ChallengeIcon {
  static const Map<String, IconData> _icons = {
    'hiking': Symbols.hiking_rounded,
    'terrain': Symbols.terrain_rounded,
    'landscape': Symbols.landscape_rounded,
    'trophy': Symbols.emoji_events_rounded,
    'star': Symbols.star_rounded,
    'flag': Symbols.flag_rounded,
    'walk': Symbols.directions_walk_rounded,
    'run': Symbols.directions_run_rounded,
    'fire': Symbols.local_fire_department_rounded,
  };

  /// Falls back to a generic trophy for an unset or unknown key — never
  /// throws on a null/stale value.
  static IconData forKey(String? key) => _icons[key] ?? AppIcons.challenges;

  static List<String> get keys => _icons.keys.toList(growable: false);

  static String labelForKey(String key) =>
      key.isEmpty ? key : key[0].toUpperCase() + key.substring(1);
}
