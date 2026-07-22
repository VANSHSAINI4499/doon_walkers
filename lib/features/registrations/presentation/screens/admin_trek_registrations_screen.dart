import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:doon_walkers/features/registrations/presentation/widgets/registration_tile.dart';
import 'package:doon_walkers/features/trek_library/presentation/providers/trek_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// One trek's registered members only — reached by tapping a trek on
/// [AdminTrekPickerScreen]. Shows name, phone, email, registration date
/// and status, via the shared [RegistrationTile] with the trek-title
/// row suppressed (it's already this screen's AppBar title).
///
/// Reuses [registrationsForTrekProvider], which reuses
/// [RegistrationRepository] with a `.eq('trek_id', ...)` filter — no
/// parallel registrations implementation for this screen.
class AdminTrekRegistrationsScreen extends ConsumerWidget {
  const AdminTrekRegistrationsScreen({super.key, required this.trekId});

  final String trekId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final trekAsync = ref.watch(trekByIdProvider(trekId));
    final registrationsAsync = ref.watch(registrationsForTrekProvider(trekId));

    return Scaffold(
      appBar: AppBar(
        title: trekAsync.maybeWhen(
          data: (trek) => Text(trek?.title ?? 'Trek Registrations'),
          orElse: () => const Text('Trek Registrations'),
        ),
      ),
      body: SafeArea(
        child: registrationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) {
            debugPrint('AdminTrekRegistrationsScreen: failed to load registrations: $error');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 40, color: theme.colorScheme.error),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load registrations for this trek.',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(registrationsForTrekProvider(trekId)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (registrations) {
            Future<void> onRefresh() =>
                ref.refresh(registrationsForTrekProvider(trekId).future);

            if (registrations.isEmpty) {
              return RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [_EmptyTrekRegistrations()],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: registrations.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final registration = registrations[index];
                  return RegistrationTile(
                    registration: registration,
                    showTrekTitle: false,
                    // Nested under THIS tab's own branch, not
                    // adminRegistrationDetailLocation — see that
                    // constant's doc for why pushing the flat roster's
                    // path here would switch tabs and misplace "back".
                    onTap: () => context.push(
                      AppConstants.adminTrekRegistrationsDetailLocation(
                        trekId,
                        registration.id,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyTrekRegistrations extends StatelessWidget {
  const _EmptyTrekRegistrations();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline_rounded, size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'No registrations yet',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Members who register for this trek will show up here.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
