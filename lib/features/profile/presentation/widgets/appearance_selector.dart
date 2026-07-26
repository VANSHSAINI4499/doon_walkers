import 'package:doon_walkers/core/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app's light/dark override, in Profile.
///
/// A three-way choice rather than a switch, because [ThemeMode] genuinely
/// has three states and "System" is the default. A binary toggle would
/// have to either hide the default or silently drop out of it the first
/// time the user touched the control.
///
/// Writes through [themeModeProvider], which persists to
/// `SharedPreferences` — this is a real stored preference, not
/// session-local state.
class AppearanceSelector extends ConsumerWidget {
  const AppearanceSelector({super.key});

  static const _options = <(ThemeMode, String, IconData)>[
    (ThemeMode.system, 'System', AppIcons.themeSystem),
    (ThemeMode.light, 'Light', AppIcons.themeLight),
    (ThemeMode.dark, 'Dark', AppIcons.themeDark),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final mode = ref.watch(themeModeProvider);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: palette.primarySubtle,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: AppIcon(
                  AppIcons.themeSystem,
                  size: 20,
                  color: palette.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Appearance', style: AppTextStyles.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      'System follows your device setting.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              for (final (value, label, icon) in _options) ...[
                if (value != _options.first.$1)
                  const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _ModeOption(
                    label: label,
                    icon: icon,
                    selected: mode == value,
                    onTap: () =>
                        ref.read(themeModeProvider.notifier).set(value),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final ink = selected ? palette.primary : palette.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? palette.primarySubtle : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: selected ? palette.primary : palette.border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: 20, color: ink),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(color: ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
