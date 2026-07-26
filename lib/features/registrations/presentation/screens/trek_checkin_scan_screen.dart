import 'dart:async';
import 'dart:io';

import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;

/// Member-facing check-in QR scanner (Phase QR-2) — reached from the
/// "Check In" entry point on Trek Detail
/// (TrekRegisterButton's `_AlreadyRegistered` state, only shown
/// near/within the active window — see trek_checkin_window.dart).
///
/// Scans the QR QR-1's admin screen displays and calls
/// `verify_trek_checkin` via [RegistrationController.checkIn]. All the
/// real validation (registered? token match? window open? already
/// checked in?) happens server-side in that RPC — this screen only
/// captures a scan, shows the specific rejection reason on failure
/// (never a raw exception), and shows a clear confirmation on success.
class TrekCheckinScanScreen extends ConsumerStatefulWidget {
  const TrekCheckinScanScreen({super.key, required this.trekId});

  final String trekId;

  @override
  ConsumerState<TrekCheckinScanScreen> createState() => _TrekCheckinScanScreenState();
}

class _TrekCheckinScanScreenState extends ConsumerState<TrekCheckinScanScreen> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);

  /// True from the moment a scan is captured until the RPC call
  /// resolves — guards against the camera firing `onDetect` several
  /// times a second for the same still-visible code, which would
  /// otherwise fire multiple overlapping verify calls.
  bool _submitting = false;

  DateTime? _checkedInAt;
  Object? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_submitting || _checkedInAt != null) return;
    if (capture.barcodes.isEmpty) return;
    final token = capture.barcodes.first.rawValue;
    if (token == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    unawaited(_controller.stop());

    final result = await ref
        .read(registrationControllerProvider.notifier)
        .checkIn(trekId: widget.trekId, scannedToken: token);

    if (!mounted) return;

    if (result != null) {
      setState(() => _checkedInAt = result);
      return;
    }

    final error = ref.read(registrationControllerProvider).error;
    setState(() {
      _submitting = false;
      _error = error;
    });
    // Ready to try again — a wrong/expired QR shouldn't strand the
    // member on a frozen camera.
    unawaited(_controller.start());
  }

  String _errorMessage(Object? error) {
    if (error is TrekCheckinException) return error.toString();
    // Realistic "no signal" shape on Android: a DNS/connect failure
    // from the underlying http client surfaces as SocketException.
    // Offline support is explicitly out of scope (deferred) — this is
    // just a clear message, not a queue/retry mechanism.
    if (error is SocketException) return 'No connection — try again.';
    debugPrint('TrekCheckinScanScreen: check-in failed: $error');
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check In')),
      body: SafeArea(
        child: _checkedInAt != null
            ? _SuccessState(checkedInAt: _checkedInAt!, onDone: () => context.pop())
            : _buildScanner(context),
      ),
    );
  }

  Widget _buildScanner(BuildContext context) {
    final palette = AppPalette.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error) => _CameraError(error: error),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.xxxl, AppSpacing.xl, AppSpacing.xl,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [palette.background, palette.background.withValues(alpha: 0)],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Point your camera at the check-in QR code',
                  style: AppTextStyles.tinted(AppTextStyles.bodyMedium, palette.textPrimary),
                  textAlign: TextAlign.center,
                ),
                if (_submitting) ...[
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: palette.primary),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _ErrorBanner(message: _errorMessage(_error)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SuccessState extends StatelessWidget {
  const _SuccessState({required this.checkedInAt, required this.onDone});

  final DateTime checkedInAt;
  final VoidCallback onDone;

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final period = local.hour < 12 ? 'AM' : 'PM';
    final minute = local.minute.toString().padLeft(2, '0');
    return 'Checked in at $hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: AppCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(AppIcons.checkCircle, size: 48, color: palette.primary),
              const SizedBox(height: AppSpacing.lg),
              Text("You're checked in!", style: AppTextStyles.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(_formatTime(checkedInAt), style: AppTextStyles.secondary(AppTextStyles.bodyMedium)),
              const SizedBox(height: AppSpacing.xl),
              PremiumButton(label: 'Done', fullWidth: true, onPressed: onDone),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.danger.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppIcons.error, size: 18, color: palette.danger),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              message,
              style: AppTextStyles.tinted(AppTextStyles.bodySmall, palette.danger),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown by [MobileScanner]'s `errorBuilder` — most commonly a denied
/// camera permission, which mobile_scanner requests itself.
class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isPermissionDenied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: palette.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(AppIcons.error, size: 40, color: palette.danger),
              const SizedBox(height: AppSpacing.md),
              Text(
                isPermissionDenied
                    ? 'Camera access is needed to scan the check-in QR code.'
                    : 'Could not start the camera. Please try again.',
                style: AppTextStyles.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (isPermissionDenied) ...[
                const SizedBox(height: AppSpacing.lg),
                const PremiumButton(
                  label: 'Open Settings',
                  variant: PremiumButtonVariant.glass,
                  onPressed: openAppSettings,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
