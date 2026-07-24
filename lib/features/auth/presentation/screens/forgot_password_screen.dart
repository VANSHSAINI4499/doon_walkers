import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/auth/presentation/controllers/auth_controller.dart';
import 'package:doon_walkers/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authControllerProvider.notifier).sendPasswordResetEmail(
          _emailController.text,
        );
    if (mounted && !ref.read(authControllerProvider).hasError) {
      setState(() {
        _emailSent = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stackTrace) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send reset link: ${_cleanErrorMessage(error)}'),
              backgroundColor: AppColors.danger,
            ),
          );
        },
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _emailSent ? _buildSuccessView() : _buildFormView(authState),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView(AsyncValue<void> authState) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppIcon(AppIcons.lockReset, size: 56, color: AppColors.primary),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Password Recovery',
          style: AppTextStyles.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Enter your registered email address and we will send you a link to reset your password.',
          style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxl),
        GlassCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  hint: 'yourname@example.com',
                  prefixIcon: AppIcons.email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                PremiumButton(
                  label: 'Send Reset Link',
                  fullWidth: true,
                  isLoading: authState.isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return GlassCard(
      glowColor: AppColors.primary,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppIcon(AppIcons.emailRead, size: 56, color: AppColors.primary),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Check Your Email',
            style: AppTextStyles.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'We sent a password reset link to ${_emailController.text}. Follow the instructions in the email to set a new password.',
            style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          PremiumButton(
            label: 'Back to Sign In',
            fullWidth: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  String _cleanErrorMessage(Object error) {
    debugPrint('ForgotPasswordScreen: reset email failed: $error');
    return 'Something went wrong. Please try again.';
  }
}
