import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/widgets/admin_form.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:doon_walkers/features/trek_library/presentation/providers/trek_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// How long before/after the scheduled start the check-in QR is
/// considered "open" — a Phase QR-1 design call, not derived from
/// anything else. Easy to retune later; not configurable per trek in
/// this phase.
const _checkinWindowHours = 3;

enum _CheckinWindowStatus { notScheduled, notYetOpen, open, closed }

/// Admin-only "Display Check-in QR" screen (Phase QR-1) — renders the
/// trek's check-in token (0029_trek_checkin_qr.sql) as a scannable QR
/// code, with a status banner for whether the check-in window is
/// currently open. Reached from [TrekAdminActions]; gated by
/// `_isTrekAdminRoute` in app_router.dart the same way the edit form is.
///
/// This screen only DISPLAYS the token — scanning it and actually
/// recording a check-in is Phase QR-2.
class TrekCheckinQrScreen extends ConsumerWidget {
  const TrekCheckinQrScreen({super.key, required this.trekId});

  final String trekId;

  _CheckinWindowStatus _windowStatus(Trek trek) {
    final date = trek.trekDate;
    final startTime = trek.trekStartTime;
    if (date == null || startTime == null) return _CheckinWindowStatus.notScheduled;

    final start = startTime.onDate(date);
    final now = DateTime.now();
    final opensAt = start.subtract(const Duration(hours: _checkinWindowHours));
    final closesAt = start.add(const Duration(hours: _checkinWindowHours));

    if (now.isBefore(opensAt)) return _CheckinWindowStatus.notYetOpen;
    if (now.isAfter(closesAt)) return _CheckinWindowStatus.closed;
    return _CheckinWindowStatus.open;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trekAsync = ref.watch(trekByIdProvider(trekId));
    final tokenAsync = ref.watch(trekCheckinTokenProvider(trekId));

    return Scaffold(
      appBar: AppBar(title: const Text('Check-in QR')),
      body: SafeArea(
        child: trekAsync.when(
          loading: () => const AdminFormLoadingSkeleton(),
          error: (error, stack) => AdminFormErrorState(
            message: 'Could not load this trek.',
            onRetry: () => ref.invalidate(trekByIdProvider(trekId)),
          ),
          data: (trek) {
            if (trek == null) {
              return const Center(child: Text('Trek not found.'));
            }
            return tokenAsync.when(
              loading: () => const AdminFormLoadingSkeleton(),
              error: (error, stack) => AdminFormErrorState(
                message: 'Could not load the check-in QR.',
                onRetry: () => ref.invalidate(trekCheckinTokenProvider(trekId)),
              ),
              data: (token) {
                if (token == null) {
                  // Admin-only RLS returns zero rows for anyone else, and
                  // every trek gets a token row automatically on create
                  // (plus a one-time backfill for pre-existing treks) —
                  // reaching this as an actual admin would mean the
                  // backfill somehow missed this trek.
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xxl),
                      child: Text('No check-in QR is available for this trek yet.'),
                    ),
                  );
                }
                return _buildContent(context, trek, token);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Trek trek, String token) {
    final status = _windowStatus(trek);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(trek.title, style: AppTextStyles.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.xxl),

              GlassCard(
                child: Column(
                  children: [
                    // A white plate behind the QR regardless of the
                    // app's dark theme — scanners are tuned for
                    // dark-on-light contrast.
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: QrImageView(
                        data: token,
                        version: QrVersions.auto,
                        size: 240,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              _StatusBanner(status: status, trek: trek),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status, required this.trek});

  final _CheckinWindowStatus status;
  final Trek trek;

  ({Color color, IconData icon, String title, String subtitle}) get _content {
    switch (status) {
      case _CheckinWindowStatus.notScheduled:
        return (
          color: AppColors.textSecondary,
          icon: AppIcons.info,
          title: 'Not scheduled',
          subtitle: 'Set a trek date and start time to enable check-in.',
        );
      case _CheckinWindowStatus.notYetOpen:
        final start = trek.trekStartTime!.onDate(trek.trekDate!);
        final opensAt = start.subtract(const Duration(hours: _checkinWindowHours));
        return (
          color: AppColors.gold,
          icon: AppIcons.schedule,
          title: 'Not open yet',
          subtitle: 'Opens ${_formatDateTime(opensAt)} '
              '($_checkinWindowHours hours before the trek starts).',
        );
      case _CheckinWindowStatus.open:
        return (
          color: AppColors.primary,
          icon: AppIcons.checkCircle,
          title: 'Check-in window is open',
          subtitle: 'Members can be checked in now.',
        );
      case _CheckinWindowStatus.closed:
        return (
          color: AppColors.danger,
          icon: AppIcons.eventBusy,
          title: 'Check-in window closed',
          subtitle: 'More than $_checkinWindowHours hours have passed since the trek started.',
        );
    }
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour < 12 ? 'AM' : 'PM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]}, $hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final c = _content;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: c.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: c.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(c.icon, size: 22, color: c.color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.title, style: AppTextStyles.tinted(AppTextStyles.titleSmall, c.color)),
                const SizedBox(height: AppSpacing.xs),
                Text(c.subtitle, style: AppTextStyles.secondary(AppTextStyles.bodySmall)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
