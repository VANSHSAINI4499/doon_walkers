import 'package:doon_walkers/features/merchandise/domain/entities/merch_inquiry.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/merch_inquiry_providers.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/merch_inquiry_status_chip.dart';
import 'package:doon_walkers/features/registrations/presentation/widgets/registration_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "My Inquiries" on Profile (Version 2, Phase M2 fix) — the signed-in
/// user's own "Buy Now" submissions, read-only. Mirrors
/// [MyRegistrationsSection]/[MyWishlistSection]'s list-of-cards shape,
/// but with no action button: this phase gives a user no self-service
/// way to cancel/withdraw an inquiry (see
/// MerchInquiryRepository.updateStatus's doc) — only admin changes
/// status, and the requester now finds out about that via a targeted
/// push notification as well as by checking back here.
class MyInquiriesSection extends ConsumerWidget {
  const MyInquiriesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final inquiriesAsync = ref.watch(myMerchInquiriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.shopping_bag_outlined, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'My Inquiries',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        inquiriesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) {
            debugPrint('MyInquiriesSection: failed to load inquiries: $error');
            return Row(
              children: [
                Expanded(
                  child: Text(
                    'Could not load your inquiries.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(myMerchInquiriesProvider),
                  child: const Text('Retry'),
                ),
              ],
            );
          },
          data: (inquiries) {
            if (inquiries.isEmpty) return const _EmptyInquiries();
            return Column(
              children: [
                for (final inquiry in inquiries) ...[
                  _MyInquiryTile(inquiry: inquiry),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _EmptyInquiries extends StatelessWidget {
  const _EmptyInquiries();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        "You haven't sent any \"Buy Now\" inquiries yet.",
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _MyInquiryTile extends StatelessWidget {
  const _MyInquiryTile({required this.inquiry});

  final MerchInquiry inquiry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sizeLabel = inquiry.variantSize != null ? ' · Size ${inquiry.variantSize}' : '';

    return Card(
      elevation: 1,
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
                    '${inquiry.productName}$sizeLabel',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                MerchInquiryStatusChip(status: inquiry.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Qty ${inquiry.quantity} · Sent ${formatRegistrationDate(inquiry.createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
