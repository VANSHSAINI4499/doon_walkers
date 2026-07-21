import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:doon_walkers/features/registrations/presentation/widgets/registration_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Admin registrations roster — every registration across every trek.
///
/// Kept as its own Admin Dashboard destination rather than inlined into a
/// trek screen (unlike trek/gallery CRUD): a cross-trek roster has no
/// single-trek screen it naturally belongs to.
///
/// Reachable only via the admin-gated `/admin/registrations` route;
/// `registrations_select` backs that up independently by returning only
/// the caller's own rows to a non-admin.
class AdminRegistrationsScreen extends ConsumerWidget {
  const AdminRegistrationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final registrationsAsync = ref.watch(allRegistrationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Registrations')),
      body: SafeArea(
        child: registrationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) {
            debugPrint('AdminRegistrationsScreen: failed to load registrations: $error');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 40, color: theme.colorScheme.error),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load registrations.',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(allRegistrationsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (registrations) {
            Future<void> onRefresh() => ref.refresh(allRegistrationsProvider.future);

            if (registrations.isEmpty) {
              return RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [_EmptyRegistrations()],
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
                  return _RegistrationTile(
                    registration: registration,
                    // Sensitive fields (age/gender/emergency contact/
                    // medical notes) live behind this tap rather than in
                    // the list — see AdminRegistrationDetailScreen.
                    onTap: () => context.push(
                      AppConstants.adminRegistrationDetailLocation(registration.id),
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

/// Empty state. Deliberately explicit that the *user-facing registration
/// flow doesn't exist yet* (Phase 6) rather than a bare "nothing here" —
/// otherwise a working-but-empty roster reads as broken to an admin who
/// knows the community has members.
class _EmptyRegistrations extends StatelessWidget {
  const _EmptyRegistrations();

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
            'Trek registrations will appear here once members can sign up for treks.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RegistrationTile extends StatelessWidget {
  const _RegistrationTile({required this.registration, required this.onTap});

  final Registration registration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = registration;

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      r.userName,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  RegistrationStatusChip(status: r.paymentStatus),
                ],
              ),
              const SizedBox(height: 10),
              _DetailRow(icon: Icons.terrain_rounded, text: r.trekTitle),
              const SizedBox(height: 6),
              _DetailRow(icon: Icons.email_outlined, text: r.userEmail),
              const SizedBox(height: 6),
              // Phone is nullable in the schema — say so plainly rather than
              // rendering an empty row that looks like a rendering bug.
              _DetailRow(
                icon: Icons.phone_outlined,
                text: r.userPhone ?? 'No phone on file',
                muted: r.userPhone == null,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _DetailRow(
                      icon: Icons.event_outlined,
                      text: 'Registered ${formatRegistrationDate(r.createdAt)}',
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text, this.muted = false});

  final IconData icon;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontStyle: muted ? FontStyle.italic : FontStyle.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
