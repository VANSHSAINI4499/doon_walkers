import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
      ),
      body: userAsync.when(
        // A transient RealtimeSubscribeException (WebSocket reconnect —
        // fires routinely on app background/foreground, screen lock, or
        // a network blip) would otherwise discard a still-valid cached
        // admin row and show the error state instead, which reads to the
        // user as if their admin access had disappeared. skipError
        // prefers the last-known-good value whenever one is cached and
        // only falls through to `error` when there truly is none yet.
        skipError: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) {
          debugPrint('AdminScreen: failed to load current user: $err');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, size: 40, color: theme.colorScheme.error),
                  const SizedBox(height: 12),
                  Text(
                    'Could not verify admin access.',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.invalidate(currentUserProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
        data: (user) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Verification Banner Card
                    Card(
                      color: theme.colorScheme.primaryContainer,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              size: 48,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Admin Access Verified ✅',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Welcome, ${user?.name ?? 'Administrator'}! You have full CRUD permissions across DoonWalkers.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Management Modules',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    // Module Cards placeholder grid for Phase 3+
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.05,
                      children: [
                        // Trek management has no own admin screen — its
                        // controls are inline on the public Trek Library
                        // screen now. Gallery's equivalent shortcut was
                        // removed for the same reason (inline on the
                        // public Gallery tab, already reachable from
                        // bottom nav) — keeping both here would just be
                        // two paths to the same place. `go` rather than
                        // `push`: this is a bottom-nav branch, so
                        // switching to it should select the tab, not
                        // stack on top of /admin.
                        _buildModuleCard(
                          context,
                          title: 'Manage Treks',
                          subtitle: 'Add, edit & publish on the Treks tab',
                          icon: Icons.landscape_rounded,
                          onTap: () => context.go(AppConstants.routeTrekLibrary),
                        ),
                        _buildModuleCard(
                          context,
                          title: 'Registrations',
                          subtitle: 'View & export trek rosters',
                          icon: Icons.people_alt_rounded,
                          onTap: () => context.push(AppConstants.routeAdminRegistrations),
                        ),
                        // Trek Registrations is now also its own bottom-nav
                        // tab for admins — `go`, same reasoning as Manage
                        // Treks: this should switch to that tab, not stack
                        // a second copy of it on top of /admin.
                        _buildModuleCard(
                          context,
                          title: 'Trek Registrations',
                          subtitle: 'View registered members by trek',
                          icon: Icons.groups_rounded,
                          onTap: () => context.go(AppConstants.routeAdminTrekRegistrations),
                        ),
                        // Cross-trek hidden-comments queue — `push`, not
                        // `go`: this stays under the /admin branch (same
                        // as Registrations above), not a bottom-nav tab.
                        _buildModuleCard(
                          context,
                          title: 'Comment Moderation',
                          subtitle: 'Approve or hide community posts',
                          icon: Icons.forum_rounded,
                          onTap: () => context.push(AppConstants.routeCommentModeration),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModuleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 28),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
