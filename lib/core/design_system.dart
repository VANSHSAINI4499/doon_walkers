/// DoonWalkers design system — the **calm Material 3 foundation**.
///
/// A single import for everything a screen needs: the palette and
/// dimension tokens, the typography scale, the Material Symbols icon set,
/// the motion primitives, and the components (`AppCard`, `AppButton`,
/// `StatDisplay`, `AppProgressBar`, the skeleton family).
///
/// ```dart
/// import 'package:doon_walkers/core/design_system.dart';
/// ```
///
/// ## Using it
///
/// Colour comes from `AppPalette.of(context)`, which resolves light or
/// dark off the active theme. The older `AppColors` constants still
/// export from here so unmigrated screens compile, but they cannot
/// respond to theme — see that class's own doc before reaching for it.
///
/// Nothing here touches data, routing or business logic — it is the
/// visual layer only.
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
export 'package:doon_walkers/core/theme/app_palette.dart';
export 'package:doon_walkers/core/theme/app_shadows.dart';
export 'package:doon_walkers/core/theme/app_text_styles.dart';
export 'package:doon_walkers/core/theme/app_theme.dart';
export 'package:doon_walkers/core/theme/theme_mode_provider.dart';
// Components
export 'package:doon_walkers/core/widgets/app_progress.dart';
export 'package:doon_walkers/core/widgets/app_segmented_control.dart';
export 'package:doon_walkers/core/widgets/app_splash_screen.dart';
export 'package:doon_walkers/core/widgets/floating_nav_bar.dart';
export 'package:doon_walkers/core/widgets/glass_card.dart';
export 'package:doon_walkers/core/widgets/otp_input.dart';
export 'package:doon_walkers/core/widgets/premium_button.dart';
export 'package:doon_walkers/core/widgets/skeleton.dart';
export 'package:doon_walkers/core/widgets/stat_display.dart';
export 'package:doon_walkers/core/widgets/animated_streak_flame.dart';
