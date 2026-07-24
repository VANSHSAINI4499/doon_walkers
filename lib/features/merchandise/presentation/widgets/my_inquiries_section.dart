import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/widgets/glass_states.dart';
import 'package:doon_walkers/core/widgets/section_title.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/merch_inquiry.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/merch_inquiry_providers.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/merch_inquiry_status_chip.dart';
import 'package:doon_walkers/features/registrations/presentation/widgets/registration_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "My Inquiries" on Profile — the signed-in user's own "Buy Now"
/// submissions, **read-only**.
///
/// Redesign Phase 5 restyles this onto the design system. As before there
/// is deliberately no action button: a user has no self-service way to
/// cancel/withdraw an inquiry (only an admin changes its status). This
/// pass does not add one.
class MyInquiriesSection extends ConsumerWidget {
  const MyInquiriesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inquiriesAsync = ref.watch(myMerchInquiriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(title: 'My Inquiries', icon: AppIcons.bag, accent: AppColors.accent),
        const SizedBox(height: AppSpacing.md),
        inquiriesAsync.when(
          loading: () => const SkeletonList(count: 2, showImages: false, padding: EdgeInsets.zero),
          error: (error, stack) {
            debugPrint('MyInquiriesSection: failed to load inquiries: $error');
            return GlassSectionError(
              message: 'Could not load your inquiries.',
              onRetry: () => ref.invalidate(myMerchInquiriesProvider),
            );
          },
          data: (inquiries) {
            if (inquiries.isEmpty) return const _EmptyInquiries();
            return Column(
              children: [
                for (final inquiry in inquiries) ...[
                  _MyInquiryTile(inquiry: inquiry),
                  const SizedBox(height: AppSpacing.md),
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
    return const GlassEmptyState(
      icon: AppIcons.bag,
      message: 'You haven\'t sent any "Buy Now" inquiries yet.',
    );
  }
}

class _MyInquiryTile extends StatelessWidget {
  const _MyInquiryTile({required this.inquiry});

  final MerchInquiry inquiry;

  @override
  Widget build(BuildContext context) {
    final sizeLabel = inquiry.variantSize != null ? ' · Size ${inquiry.variantSize}' : '';

    return GlassCard(
      blurEnabled: false,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${inquiry.productName}$sizeLabel',
                  style: AppTextStyles.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              MerchInquiryStatusChip(status: inquiry.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Qty ${inquiry.quantity} · Sent ${formatRegistrationDate(inquiry.createdAt)}',
            style: AppTextStyles.secondary(AppTextStyles.bodySmall),
          ),
        ],
      ),
    );
  }
}
