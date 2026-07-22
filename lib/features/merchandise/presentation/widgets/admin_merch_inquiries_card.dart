import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Admin-only entry point to [AppConstants.routeAdminMerchInquiries],
/// rendered on the Profile screen alongside
/// AdminSendNotificationCard — same reasoning applies here: a cross-
/// product inquiries roster has no single-product screen it
/// naturally belongs to (mirrors why Registrations got its own Admin
/// Dashboard destination rather than being inlined), and Profile is
/// already established as where this project puts admin-only tool
/// entry points that aren't worth a bottom-nav tab or drawer entry.
/// Gated on [isAdminProvider], same convention as every other
/// admin-only affordance.
class AdminMerchInquiriesCard extends ConsumerWidget {
  const AdminMerchInquiriesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(Icons.shopping_bag_outlined, color: theme.colorScheme.onPrimaryContainer),
        ),
        title: const Text('Merchandise Inquiries', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Review and follow up on "Buy Now" requests'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push(AppConstants.routeAdminMerchInquiries),
      ),
    );
  }
}
