import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/widgets/preview_section.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/merch_inquiry.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/merch_inquiry_providers.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/merch_inquiry_status_chip.dart';
import 'package:doon_walkers/features/registrations/presentation/widgets/registration_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// "My Inquiries" on Profile — a dashboard preview of the signed-in
/// user's 2 most recent "Buy Now" submissions, **read-only**, with a
/// "View All" link to [MyEnquiriesScreen] once there are more than 2.
///
/// As before there is deliberately no action button: a user has no
/// self-service way to cancel/withdraw an inquiry (only an admin
/// changes its status).
class MyInquiriesSection extends ConsumerWidget {
  const MyInquiriesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inquiriesAsync = ref.watch(myMerchInquiriesPreviewProvider);

    return PreviewSection<MerchInquiry>(
      title: 'My Inquiries',
      icon: AppIcons.bag,
      accent: AppColors.accent,
      asyncItems: inquiriesAsync,
      itemBuilder: (inquiry) => MyInquiryTile(inquiry: inquiry),
      onViewAll: () => context.push(AppConstants.routeMyEnquiries),
      onRetry: () => ref.invalidate(myMerchInquiriesPreviewProvider),
      errorMessage: 'Could not load your inquiries.',
      emptyIcon: AppIcons.bag,
      emptyMessage: 'You haven\'t sent any "Buy Now" inquiries yet.',
    );
  }
}

/// One inquiry row — shared by [MyInquiriesSection]'s preview and
/// [MyEnquiriesScreen]'s full list.
class MyInquiryTile extends StatelessWidget {
  const MyInquiryTile({super.key, required this.inquiry});

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
          if ((inquiry.note ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              inquiry.note!,
              style: AppTextStyles.secondary(AppTextStyles.bodySmall),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
