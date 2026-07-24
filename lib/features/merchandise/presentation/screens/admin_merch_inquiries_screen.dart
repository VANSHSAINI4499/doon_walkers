import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/merch_inquiry.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/merch_inquiry_providers.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/merch_inquiry_status_chip.dart';
import 'package:doon_walkers/features/registrations/presentation/widgets/registration_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Admin "Buy Now" inquiries roster — every inquiry across every product,
/// newest first. Reachable only via the admin-gated
/// `/admin/merch-inquiries` route; `merch_inquiries_select` backs that up.
///
/// Redesign Phase 6 restyles this onto the design system (skeleton loading,
/// glass tiles). **The status-update logic and the exact per-inquiry detail
/// shown (product, size, qty, requester contact, per-order phone, note) are
/// unchanged.** The status control still lives inline on each tile.
class AdminMerchInquiriesScreen extends ConsumerWidget {
  const AdminMerchInquiriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inquiriesAsync = ref.watch(allMerchInquiriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Merchandise Inquiries')),
      body: SafeArea(
        child: inquiriesAsync.when(
          loading: () => const _InquiriesSkeleton(),
          error: (error, stack) {
            debugPrint('AdminMerchInquiriesScreen: failed to load inquiries: $error');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppIcon(AppIcons.error, size: 44, color: AppColors.danger),
                    const SizedBox(height: AppSpacing.md),
                    Text('Could not load inquiries.', style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.xl),
                    PremiumButton(
                      label: 'Retry',
                      icon: AppIcons.refresh,
                      variant: PremiumButtonVariant.glass,
                      size: PremiumButtonSize.small,
                      onPressed: () => ref.invalidate(allMerchInquiriesProvider),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (inquiries) {
            Future<void> onRefresh() => ref.refresh(allMerchInquiriesProvider.future);

            if (inquiries.isEmpty) {
              return RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [_EmptyInquiries()],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: inquiries.length,
                separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) => AppReveal(
                  index: index.clamp(0, 8),
                  child: _InquiryTile(inquiry: inquiries[index]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyInquiries extends StatelessWidget {
  const _EmptyInquiries();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: const AppIcon(AppIcons.bag, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('No inquiries yet', style: AppTextStyles.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Inquiries will appear here when a member taps "Buy Now" on a product.',
            style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _InquiryTile extends ConsumerStatefulWidget {
  const _InquiryTile({required this.inquiry});

  final MerchInquiry inquiry;

  @override
  ConsumerState<_InquiryTile> createState() => _InquiryTileState();
}

class _InquiryTileState extends ConsumerState<_InquiryTile> {
  bool _isSaving = false;

  Future<void> _updateStatus(MerchInquiryStatus status) async {
    if (status == widget.inquiry.status) return;

    setState(() => _isSaving = true);
    final success = await ref
        .read(merchInquiryControllerProvider.notifier)
        .updateStatus(widget.inquiry, status);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update this inquiry. Please try again.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inquiry = widget.inquiry;
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
                child: Text('${inquiry.productName}$sizeLabel', style: AppTextStyles.titleSmall),
              ),
              const SizedBox(width: AppSpacing.sm),
              MerchInquiryStatusChip(status: inquiry.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Qty ${inquiry.quantity} · Requested ${formatRegistrationDate(inquiry.createdAt)}',
            style: AppTextStyles.secondary(AppTextStyles.bodySmall),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const AppIcon(AppIcons.person, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${inquiry.userName} · ${inquiry.userEmail}'
                  '${inquiry.userPhone != null ? ' · ${inquiry.userPhone}' : ''}',
                  style: AppTextStyles.secondary(AppTextStyles.bodySmall),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // The number to actually call about THIS order — may differ from
          // the account phone above (editable per-inquiry). Emphasised.
          if ((inquiry.phoneNumber ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const AppIcon(AppIcons.call, size: 16, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Contact for this order: ${inquiry.phoneNumber}',
                  style: AppTextStyles.tinted(AppTextStyles.labelMedium, AppColors.primary),
                ),
              ],
            ),
          ],
          if ((inquiry.note ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              inquiry.note!,
              style: AppTextStyles.secondary(AppTextStyles.bodySmall).copyWith(fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<MerchInquiryStatus>(
              value: inquiry.status,
              decoration: const InputDecoration(labelText: 'Status', isDense: true),
              items: MerchInquiryStatus.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                  .toList(),
              onChanged: _isSaving
                  ? null
                  : (value) {
                      if (value != null) _updateStatus(value);
                    },
            ),
          ),
          if (_isSaving) ...[
            const SizedBox(height: AppSpacing.sm),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

class _InquiriesSkeleton extends StatelessWidget {
  const _InquiriesSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: 4,
        separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) => Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 180, height: 16),
              SizedBox(height: AppSpacing.sm),
              SkeletonBox(width: 140, height: 10),
              SizedBox(height: AppSpacing.md),
              SkeletonBox(width: 220, height: 44, borderRadius: AppRadius.sm),
            ],
          ),
        ),
      ),
    );
  }
}
