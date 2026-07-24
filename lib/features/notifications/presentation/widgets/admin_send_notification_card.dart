import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Admin-only entry point to [AppConstants.routeAdminSendNotification],
/// rendered on the Profile screen — the old standalone Admin Panel it used
/// to live on is gone, so this is now the only way in.
///
/// Redesign Phase 5 restyles it as a [PremiumButton]. The gating is
/// unchanged: it renders nothing for a non-admin (defence in depth — the
/// Profile screen also gates the whole admin group), same
/// [isAdminProvider] convention as every other admin-only affordance.
class AdminSendNotificationCard extends ConsumerWidget {
  const AdminSendNotificationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) return const SizedBox.shrink();

    return PremiumButton(
      label: 'Send Notification',
      icon: AppIcons.announce,
      variant: PremiumButtonVariant.accent,
      fullWidth: true,
      onPressed: () => context.push(AppConstants.routeAdminSendNotification),
    );
  }
}
