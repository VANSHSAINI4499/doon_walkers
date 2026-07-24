import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/auth/domain/repositories/auth_repository.dart';
import 'package:doon_walkers/features/auth/presentation/controllers/auth_controller.dart';
import 'package:doon_walkers/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  final String? redirectTo;

  const SignUpScreen({super.key, this.redirectTo});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// True once sign-up succeeded but Supabase requires email confirmation
  /// before a session can be created (no session came back with the
  /// response). Mirrors [ForgotPasswordScreen]'s `_emailSent` pattern.
  bool _confirmationPending = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final result = await ref.read(authControllerProvider.notifier).signUp(
          fullName: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );

    if (!mounted || result == null) return;

    if (result == SignUpResult.confirmationPending) {
      setState(() => _confirmationPending = true);
    }
    // If a session was created immediately (confirmation disabled), the
    // router's redirect kicks in automatically once auth state changes —
    // same as SignInScreen, no explicit navigation needed here.
  }

  Future<void> _submitGoogle() async {
    await ref.read(authControllerProvider.notifier).signInWithGoogle();
    // Same as email/password: router redirect handles navigation once a
    // session exists, whether this account is new or returning.
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stackTrace) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sign up failed: ${_cleanErrorMessage(error)}'),
              backgroundColor: AppColors.danger,
            ),
          );
        },
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _confirmationPending
                  ? _buildSuccessView()
                  : _buildFormView(authState),
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
        Text(
          'Join Doon Walkers',
          style: AppTextStyles.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Create an account to register for treks, post comments, and receive community updates.',
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
                  controller: _nameController,
                  label: 'Full Name',
                  hint: 'Aarav Sharma',
                  prefixIcon: AppIcons.person,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                AuthTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  hint: 'yourname@example.com',
                  prefixIcon: AppIcons.email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
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
                const SizedBox(height: AppSpacing.lg),
                AuthTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'At least 6 characters',
                  prefixIcon: AppIcons.lock,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                PremiumButton(
                  label: 'Sign Up',
                  fullWidth: true,
                  isLoading: authState.isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.glassBorder)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text('OR', style: AppTextStyles.secondary(AppTextStyles.labelMedium)),
            ),
            const Expanded(child: Divider(color: AppColors.glassBorder)),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        PremiumButton(
          label: 'Continue with Google',
          variant: PremiumButtonVariant.glass,
          fullWidth: true,
          isLoading: authState.isLoading,
          onPressed: _submitGoogle,
        ),
        const SizedBox(height: AppSpacing.xxl),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Already have an account? ',
              style: AppTextStyles.bodyMedium,
            ),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Sign In'),
            ),
          ],
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
            'Confirm Your Email',
            style: AppTextStyles.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'We sent a confirmation link to ${_emailController.text}. '
            'Verify your email, then sign in to continue.',
            style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          PremiumButton(
            label: 'Back to Sign In',
            fullWidth: true,
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }

  String _cleanErrorMessage(Object error) {
    debugPrint('SignUpScreen: sign-up failed: $error');
    return 'Something went wrong. Please try again.';
  }
}
