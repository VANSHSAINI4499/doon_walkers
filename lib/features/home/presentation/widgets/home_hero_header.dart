import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/theme/app_colors.dart';
import 'package:doon_walkers/features/settings/presentation/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hero banner at the top of Home — greets the visitor with the
/// community's tagline pulled live from [settingsProvider].
///
/// Falls back to [AppConstants.appTagline] while settings are still
/// loading or if `org_tagline` is empty, so the header never shows
/// blank text.
class HomeHeroHeader extends ConsumerWidget {
  const HomeHeroHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider).valueOrNull;
    final tagline = settings == null || settings.orgTagline.isEmpty
        ? AppConstants.appTagline
        : settings.orgTagline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Namaste 🙏',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white.withAlpha(200),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tagline,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
