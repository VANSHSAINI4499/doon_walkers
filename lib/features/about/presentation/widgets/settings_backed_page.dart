import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/settings/domain/entities/app_settings.dart';
import 'package:doon_walkers/features/settings/presentation/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared page shell for the three drawer destinations backed by
/// `public.settings` — About, Contact and Support.
///
/// All three are thin reads of the same provider with the same
/// loading/error/retry behaviour, so that lives here once rather than
/// three times. Each screen supplies only its title and its body.
///
/// Loads into a skeleton rather than a spinner, per the design system's
/// rule. The error state offers a retry that re-runs the fetch via
/// `ref.invalidate` — the same recovery the old Home section had.
class SettingsBackedPage extends ConsumerWidget {
  const SettingsBackedPage({
    super.key,
    required this.title,
    required this.builder,
  });

  final String title;
  final Widget Function(BuildContext context, AppSettings settings) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final palette = AppPalette.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: settingsAsync.when(
        loading: () => const _PageSkeleton(),
        error: (error, stack) {
          debugPrint('SettingsBackedPage($title): failed to load: $error');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(AppIcons.error, size: 40, color: palette.danger),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    "Couldn't load this page.",
                    style: AppTextStyles.titleMedium.copyWith(
                      color: palette.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'Retry',
                    icon: AppIcons.refresh,
                    onPressed: () => ref.invalidate(settingsProvider),
                  ),
                ],
              ),
            ),
          );
        },
        data:
            (settings) => Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: builder(context, settings),
                ),
              ),
            ),
      ),
    );
  }
}

class _PageSkeleton extends StatelessWidget {
  const _PageSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(AppSpacing.lg),
    child: Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 160, height: 22),
          SizedBox(height: AppSpacing.lg),
          SkeletonBox(height: 120, borderRadius: AppRadius.card),
          SizedBox(height: AppSpacing.xl),
          SkeletonBox(width: 140, height: 22),
          SizedBox(height: AppSpacing.lg),
          SkeletonBox(height: 120, borderRadius: AppRadius.card),
        ],
      ),
    ),
  );
}
