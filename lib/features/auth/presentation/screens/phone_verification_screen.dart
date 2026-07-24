import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/auth/presentation/controllers/phone_verification_controller.dart';
import 'package:doon_walkers/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// How many digits MSG91's OTP widget sends — confirmed via live testing
/// (Version 2, Phase Auth Upgrade UX pass), not assumed.
const _otpLength = 4;

/// Phone/OTP verification (Version 2, Phase Auth Upgrade), built on
/// MSG91's OTP Widget SDK — reached via [AuthGuard.requirePhoneVerified]
/// the same way Sign In is reached via [AuthGuard.requireAuth].
///
/// On success this navigates explicitly via [GoRouter.go] to
/// [redirectTo] (or Home) rather than relying solely on the router's
/// reactive `redirect` rule for /verify-phone (app_router.dart) — that
/// rule is keyed off [currentUserProvider]'s realtime stream, which in
/// practice isn't always fast/reliable enough to bounce the user away on
/// its own; explicit `.go()` (not `.push()`) replaces this screen in the
/// stack immediately, same "land back on the original action" outcome
/// Sign In/Sign Up give via their own mechanism, just driven directly
/// instead of purely reactively. The router rule stays in place as a
/// defensive fallback (e.g. a stale bookmark landing here already
/// verified).
class PhoneVerificationScreen extends ConsumerStatefulWidget {
  final String? redirectTo;

  const PhoneVerificationScreen({super.key, this.redirectTo});

  @override
  ConsumerState<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends ConsumerState<PhoneVerificationScreen> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpInputKey = GlobalKey<OTPInputState>();
  final _phoneController = TextEditingController();
  bool _prefilled = false;
  String _otpCode = '';
  String? _otpError;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    final verified = await ref
        .read(phoneVerificationControllerProvider.notifier)
        .sendOtp(_phoneController.text.trim());
    if (verified) _completeVerification();
  }

  Future<void> _resend() async {
    await ref.read(phoneVerificationControllerProvider.notifier).retryOtp();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code resent.')));
    }
  }

  Future<void> _verify() async {
    if (_otpCode.length != _otpLength) {
      setState(() => _otpError = 'Enter the $_otpLength-digit code');
      return;
    }
    final verified = await ref.read(phoneVerificationControllerProvider.notifier).verifyOtp(_otpCode);
    if (verified) _completeVerification();
  }

  void _completeVerification() {
    if (!mounted) return;
    // .go() replaces this screen rather than pushing on top of it — see
    // class doc for why this doesn't just rely on the router's reactive
    // redirect rule alone.
    context.go(widget.redirectTo ?? AppConstants.routeHome);
  }

  void _changeNumber() {
    ref.read(phoneVerificationControllerProvider.notifier).resetToPhoneStep();
    setState(() {
      _otpCode = '';
      _otpError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Prefill from the user's existing `phone`, if any — done once, off
    // currentUserProvider rather than a constructor param, since this
    // screen doesn't own that fetch.
    final existingPhone = ref.watch(currentUserProvider).value?.phone;
    if (!_prefilled && existingPhone != null && existingPhone.isNotEmpty) {
      _phoneController.text = existingPhone;
      _prefilled = true;
    }

    final verificationState = ref.watch(phoneVerificationControllerProvider);
    final isLoading = verificationState.isLoading;
    final data = verificationState.valueOrNull ?? const PhoneVerificationState();

    ref.listen<AsyncValue<PhoneVerificationState>>(phoneVerificationControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stackTrace) {
          // A failed verify attempt shouldn't leave stale/wrong digits
          // sitting in the boxes — no-ops harmlessly if we're still on
          // the phone step (OTPInput isn't mounted, so the key's
          // currentState is null).
          _otpInputKey.currentState?.clear();
          setState(() => _otpCode = '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_cleanErrorMessage(error)),
              backgroundColor: AppColors.danger,
            ),
          );
        },
      );
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Phone Number')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: data.step == PhoneVerificationStep.enterPhone
                  ? _buildPhoneStep(isLoading)
                  : _buildOtpStep(isLoading, data),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneStep(bool isLoading) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppIcon(AppIcons.phone, size: 56, color: AppColors.primary),
        const SizedBox(height: AppSpacing.lg),
        Text('Verify Your Phone', style: AppTextStyles.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        Text(
          "We'll text you a one-time code to confirm your number before you continue.",
          style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxl),
        GlassCard(
          child: Form(
            key: _phoneFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  hint: 'e.g. 919876543210',
                  prefixIcon: AppIcons.phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _sendOtp(),
                  validator: (value) {
                    final digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                    if (digits.length < 10 || digits.length > 15) {
                      return 'Enter a valid phone number with country code';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                PremiumButton(
                  label: 'Send Code',
                  fullWidth: true,
                  isLoading: isLoading,
                  onPressed: _sendOtp,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpStep(bool isLoading, PhoneVerificationState data) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppIcon(AppIcons.verified, size: 56, color: AppColors.primary),
        const SizedBox(height: AppSpacing.lg),
        Text('Enter the Code', style: AppTextStyles.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'We sent a code to ${data.phone}.',
          style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxl),
        GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OTPInput(
                key: _otpInputKey,
                length: _otpLength,
                enabled: !isLoading,
                errorText: _otpError,
                onChanged: (code) {
                  _otpCode = code;
                  if (_otpError != null) setState(() => _otpError = null);
                },
                onCompleted: (code) => _otpCode = code,
              ),
              const SizedBox(height: AppSpacing.xl),
              PremiumButton(
                label: 'Verify',
                fullWidth: true,
                isLoading: isLoading,
                onPressed: _verify,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: isLoading ? null : _resend,
              child: const Text('Resend Code'),
            ),
            const SizedBox(width: AppSpacing.md),
            TextButton(
              onPressed: isLoading ? null : _changeNumber,
              child: const Text('Change Number'),
            ),
          ],
        ),
      ],
    );
  }

  String _cleanErrorMessage(Object error) {
    debugPrint('PhoneVerificationScreen: $error');
    if (error is Exception) {
      final msg = error.toString().replaceFirst('Exception: ', '');
      if (msg.isNotEmpty) return msg;
    }
    return 'Something went wrong. Please try again.';
  }
}
