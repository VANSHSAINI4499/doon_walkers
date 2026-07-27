import 'package:doon_walkers/core/icons/app_icons.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

abstract final class ChallengeIcon {
  static const Map<String, IconData> _icons = {
    'hiking': LucideIcons.footprints,
    'terrain': LucideIcons.mountain,
    'landscape': LucideIcons.mountainSnow,
    'trophy': LucideIcons.trophy,
    'star': LucideIcons.star,
    'flag': LucideIcons.flag,
    'walk': LucideIcons.footprints,
    'run': LucideIcons.zap,
    'fire': LucideIcons.flame,
  };

  static IconData forKey(String? key) => _icons[key] ?? AppIcons.challenges;

  static List<String> get keys => _icons.keys.toList(growable: false);

  static String labelForKey(String key) =>
      key.isEmpty ? key : key[0].toUpperCase() + key.substring(1);
}
