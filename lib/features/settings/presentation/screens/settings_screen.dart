import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/profile/presentation/widgets/appearance_selector.dart';
import 'package:flutter/material.dart';

/// Settings — device-local preferences.
///
/// Currently just appearance. That is a thin screen, deliberately: the
/// alternative was inventing preferences the app does not have (there is
/// no per-device notification toggle, no units setting, no language), and
/// the calm direction would rather show one real control than pad a
/// screen out.
///
/// ## Appearance moved here from Profile
///
/// The theme selector shipped on Profile in the foundation phase, because
/// at the time Profile was the only plausible home for it. Phase 10 gives
/// the drawer a real Settings destination, which is where a device
/// preference belongs — so it **moved** rather than being duplicated.
/// Profile keeps the leaderboard-visibility toggle, which is genuinely an
/// account setting (it writes a user column) rather than a device one.
///
/// Anything that writes to the user's row belongs on Profile; anything
/// that stays on this device belongs here. That is the line to keep as
/// more settings arrive.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppearanceSelector(),
                const SizedBox(height: AppSpacing.xxl),
                Center(
                  child: Text(
                    '${AppConstants.appName} v${AppConstants.appVersion}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: palette.textDisabled,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
