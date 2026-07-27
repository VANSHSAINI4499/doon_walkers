import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/notifications/presentation/providers/notification_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Admin composer — title + body, broadcast to everyone.
///
/// Submitting inserts into `public.notifications`, which is
/// simultaneously "save the in-app record" and "trigger the database
/// webhook that sends the real push" (see the Phase 8 report's Edge
/// Function section — NOT YET DEPLOYED, so a submit here saves the row
/// and shows up in the in-app list immediately; actual device push
/// delivery is deferred until that follow-up deployment step happens).
///
/// Broadcast-only, matching the Phase 8 brief's explicit scope
/// boundary — no per-trek/per-registration targeting exists here or
/// anywhere in this phase.
class AdminSendNotificationScreen extends ConsumerStatefulWidget {
  const AdminSendNotificationScreen({super.key});

  @override
  ConsumerState<AdminSendNotificationScreen> createState() =>
      _AdminSendNotificationScreenState();
}

class _AdminSendNotificationScreenState
    extends ConsumerState<AdminSendNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final created = await ref
        .read(notificationControllerProvider.notifier)
        .sendNotification(
          title: _titleController.text.trim(),
          body: _bodyController.text.trim(),
        );

    if (!mounted) return;

    if (created != null) {
      _titleController.clear();
      _bodyController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification sent to everyone.')),
      );
      return;
    }

    final palette = AppPalette.of(context);
    final error = ref.read(notificationControllerProvider).error;
    debugPrint('AdminSendNotificationScreen: failed to send: $error');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Could not send this notification. Please try again.',
        ),
        backgroundColor: palette.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(notificationControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Send Notification')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'This goes out to every registered member as a push '
                            'notification, and shows up in everyone\'s in-app list. '
                            'Broadcast only.',
                            style: AppTextStyles.secondary(
                              AppTextStyles.bodySmall,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Title',
                            ),
                            textInputAction: TextInputAction.next,
                            validator:
                                (value) =>
                                    (value == null || value.trim().isEmpty)
                                        ? 'Please enter a title'
                                        : null,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          TextFormField(
                            controller: _bodyController,
                            decoration: const InputDecoration(
                              labelText: 'Message',
                            ),
                            maxLines: 4,
                            validator:
                                (value) =>
                                    (value == null || value.trim().isEmpty)
                                        ? 'Please enter a message'
                                        : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    PremiumButton(
                      label: 'Send to Everyone',
                      icon: AppIcons.announce,
                      fullWidth: true,
                      isLoading: isSaving,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
