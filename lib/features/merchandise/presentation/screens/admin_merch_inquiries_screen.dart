import 'package:doon_walkers/features/merchandise/domain/entities/merch_inquiry.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/merch_inquiry_providers.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/merch_inquiry_status_chip.dart';
import 'package:doon_walkers/features/registrations/presentation/widgets/registration_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Admin "Buy Now" inquiries roster — every inquiry across every
/// product, newest first.
///
/// Reachable only via the admin-gated `/admin/merch-inquiries` route
/// (Profile's "Merchandise Inquiries" card is the only entry point —
/// see AdminMerchInquiriesCard); `merch_inquiries_select` backs that up
/// independently by returning only the caller's own rows to a
/// non-admin.
///
/// Unlike AdminRegistrationsScreen, there is no separate tap-through
/// detail screen here — an inquiry carries no sensitive PII beyond
/// what the registrant already sees on their own registrations
/// (contact name/email/phone, already shown on the registrations
/// roster too), so the status control lives directly on this list
/// rather than gating it behind a second screen.
class AdminMerchInquiriesScreen extends ConsumerWidget {
  const AdminMerchInquiriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final inquiriesAsync = ref.watch(allMerchInquiriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Merchandise Inquiries')),
      body: SafeArea(
        child: inquiriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) {
            debugPrint('AdminMerchInquiriesScreen: failed to load inquiries: $error');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 40, color: theme.colorScheme.error),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load inquiries.',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(allMerchInquiriesProvider),
                      child: const Text('Retry'),
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: inquiries.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _InquiryTile(inquiry: inquiries[index]),
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'No inquiries yet',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Inquiries will appear here when a member taps "Buy Now" on a product.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
        SnackBar(
          content: const Text('Could not update this inquiry. Please try again.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inquiry = widget.inquiry;
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
                  ),
                ),
                const SizedBox(width: 8),
                MerchInquiryStatusChip(status: inquiry.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Qty ${inquiry.quantity} · Requested ${formatRegistrationDate(inquiry.createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${inquiry.userName} · ${inquiry.userEmail}'
                    '${inquiry.userPhone != null ? ' · ${inquiry.userPhone}' : ''}',
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            // The number to actually call about THIS order — may differ
            // from the account phone above (editable per-inquiry, see
            // MerchInquiry.phoneNumber's doc). Bold to stand out as the
            // one to use.
            if ((inquiry.phoneNumber ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.call_outlined, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Contact for this order: ${inquiry.phoneNumber}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
            if ((inquiry.note ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                inquiry.note!,
                style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<MerchInquiryStatus>(
                value: inquiry.status,
                decoration: const InputDecoration(labelText: 'Status', isDense: true),
                items: MerchInquiryStatus.values
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                    .toList(),
                onChanged: _isSaving ? null : (value) {
                  if (value != null) _updateStatus(value);
                },
              ),
            ),
            if (_isSaving) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}
