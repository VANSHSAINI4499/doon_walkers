import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Admin-only entry point to [AppConstants.routeAdminMerchInquiries],
/// rendered on the Profile screen alongside AdminSendNotificationCard.
///
/// Redesign Phase 5 restyles it as a [PremiumButton]. Gating unchanged:
/// renders nothing for a non-admin, same [isAdminProvider] convention.
class AdminMerchInquiriesCard extends ConsumerWidget {
  const AdminMerchInquiriesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) return const SizedBox.shrink();

    return PremiumButton(
      label: 'Merchandise Inquiries',
      icon: AppIcons.bag,
      variant: PremiumButtonVariant.glass,
      fullWidth: true,
      onPressed: () => context.push(AppConstants.routeAdminMerchInquiries),
    );
  }
}
