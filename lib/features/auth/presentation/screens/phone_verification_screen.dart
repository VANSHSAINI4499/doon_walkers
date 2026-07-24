import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/auth/presentation/controllers/phone_verification_controller.dart';
import 'package:doon_walkers/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Phone/OTP verification (Version 2, Phase Auth Upgrade), built on
/// MSG91's OTP Widget SDK — reached via [AuthGuard.requirePhoneVerified]
/// the same way Sign In is reached via [AuthGuard.requireAuth]. No
/// explicit navigation on success: once verify-phone-token flips
/// `phone_verified` true, [currentUserProvider]'s live stream picks it
/// up, which re-triggers app_router.dart's `redirect` and bounces back
/// to [redirectTo] — exactly the same mechanism Sign In/Sign Up already
/// use, not a parallel one.
class PhoneVerificationScreen extends ConsumerStatefulWidget {
  final String? redirectTo;

  const PhoneVerificationScreen({super.key, this.redirectTo});

  @override
  ConsumerState<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends ConsumerState<PhoneVerificationScreen> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _prefilled = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    final verified = await ref
        .read(phoneVerificationControllerProvider.notifier)
        .sendOtp(_phoneController.text.trim());
    if (verified) _showVerifiedSnackBar();
  }

  Future<void> _resend() async {
    await ref.read(phoneVerificationControllerProvider.notifier).retryOtp();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code resent.')));
    }
  }

  Future<void> _verify() async {
    if (!_otpFormKey.currentState!.validate()) return;
    final verified =
        await ref.read(phoneVerificationControllerProvider.notifier).verifyOtp(_otpController.text.trim());
    if (verified) _showVerifiedSnackBar();
  }

  void _showVerifiedSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone verified!')));
    // No explicit navigation — see class doc. The router redirect
    // handles the bounce-back once currentUserProvider reflects it.
  }

  void _changeNumber() {
    _otpController.clear();
    ref.read(phoneVerificationControllerProvider.notifier).resetToPhoneStep();
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
          child: Form(
            key: _otpFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  controller: _otpController,
                  label: 'Verification Code',
                  hint: 'Enter the code',
                  prefixIcon: AppIcons.verified,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _verify(),
                  validator: (value) {
                    final digits = (value ?? '').trim();
                    if (digits.isEmpty) {
                      return 'Enter the verification code';
                    }
                    return null;
                  },
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
