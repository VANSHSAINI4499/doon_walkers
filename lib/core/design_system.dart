/// DoonWalkers design system — Redesign Phase 1 foundations.
///
/// A single import for everything a screen needs to look like the
/// redesign: the palette and dimension tokens, the typography scale, the
/// Material Symbols icon set, the motion primitives, and the reusable
/// components (`GlassCard`, `PremiumButton`, the skeleton family).
///
/// ```dart
/// import 'package:doon_walkers/core/design_system.dart';
/// ```
///
/// Later phases build every screen out of these pieces. Nothing here
/// touches data, routing or business logic — it is the visual layer only.
library;

// Icons
export 'package:doon_walkers/core/icons/app_icons.dart';
// Motion
export 'package:doon_walkers/core/motion/app_hero.dart';
export 'package:doon_walkers/core/motion/app_motion.dart';
export 'package:doon_walkers/core/motion/app_transitions.dart';
export 'package:doon_walkers/core/motion/pressable.dart';
// Tokens
export 'package:doon_walkers/core/theme/app_colors.dart';
export 'package:doon_walkers/core/theme/app_dimens.dart';
export 'package:doon_walkers/core/theme/app_gradients.dart';
export 'package:doon_walkers/core/theme/app_shadows.dart';
export 'package:doon_walkers/core/theme/app_text_styles.dart';
export 'package:doon_walkers/core/theme/app_theme.dart';
// Components
export 'package:doon_walkers/core/widgets/glass_card.dart';
export 'package:doon_walkers/core/widgets/premium_button.dart';
export 'package:doon_walkers/core/widgets/skeleton.dart';
