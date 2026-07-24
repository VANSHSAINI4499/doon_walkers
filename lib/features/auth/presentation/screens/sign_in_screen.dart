import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/auth/presentation/controllers/auth_controller.dart';
import 'package:doon_walkers/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SignInScreen extends ConsumerStatefulWidget {
  final String? redirectTo;

  const SignInScreen({super.key, this.redirectTo});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authControllerProvider.notifier).signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  Future<void> _submitGoogle() async {
    await ref.read(authControllerProvider.notifier).signInWithGoogle();
    // On success the router's redirect (session now non-null) takes over,
    // same as email/password sign-in — no explicit navigation here.
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stackTrace) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sign in failed: ${_cleanErrorMessage(error)}'),
              backgroundColor: AppColors.danger,
            ),
          );
        },
      );
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIcon(AppIcons.landscape, size: 56, color: AppColors.primary),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Welcome Back',
                    style: AppTextStyles.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Sign in to register for treks and join the conversation.',
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
                            prefixIcon: AppIcons.lock,
                            isPassword: true,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => context.push(AppConstants.routeForgotPassword),
                              child: const Text('Forgot Password?'),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          PremiumButton(
                            label: 'Sign In',
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
                        "Don't have an account? ",
                        style: AppTextStyles.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () {
                          final signUpUrl = widget.redirectTo != null
                              ? '${AppConstants.routeSignUp}?redirectTo=${Uri.encodeComponent(widget.redirectTo!)}'
                              : AppConstants.routeSignUp;
                          context.push(signUpUrl);
                        },
                        child: const Text('Create Account'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: () => context.go(AppConstants.routeHome),
                    icon: const AppIcon(AppIcons.explore, size: 18, color: AppColors.textSecondary),
                    label: Text(
                      'Continue as Guest',
                      style: AppTextStyles.secondary(AppTextStyles.labelLarge),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _cleanErrorMessage(Object error) {
    debugPrint('SignInScreen: sign-in failed: $error');
    final msg = error.toString();
    if (msg.contains('Invalid login credentials')) {
      return 'Invalid email or password.';
    }
    return 'Something went wrong. Please try again.';
  }
}
