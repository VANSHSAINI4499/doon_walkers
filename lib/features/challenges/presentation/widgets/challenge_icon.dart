import 'package:flutter/material.dart';

/// Maps a challenge's `icon` column (a small known identifier string,
/// e.g. 'hiking') to a Material [IconData] — see the Challenge
/// entity's doc for why this is a string key rather than an image
/// reference in C1. [keys] is the fixed vocabulary the admin form's
/// picker offers; [forKey] is also what a future C2 progress UI would
/// use to render the same icon.
abstract final class ChallengeIcon {
  static const Map<String, IconData> _icons = {
    'hiking': Icons.hiking_rounded,
    'terrain': Icons.terrain_rounded,
    'landscape': Icons.landscape_rounded,
    'trophy': Icons.emoji_events_rounded,
    'star': Icons.star_rounded,
    'flag': Icons.flag_rounded,
    'walk': Icons.directions_walk_rounded,
    // Added for the Challenges Module fitness pivot (Version 2) —
    // 'run'/'fire' fit steps/distance/calories/streak challenges better
    // than the trek-oriented icons above, without removing any of them
    // (existing challenges keep whatever icon they already picked).
    'run': Icons.directions_run_rounded,
    'fire': Icons.local_fire_department_rounded,
  };

  /// Falls back to a generic trophy outline for an unset or unknown
  /// key — never throws on a null/stale value.
  static IconData forKey(String? key) => _icons[key] ?? Icons.emoji_events_outlined;

  static List<String> get keys => _icons.keys.toList(growable: false);

  static String labelForKey(String key) =>
      key.isEmpty ? key : key[0].toUpperCase() + key.substring(1);
}
