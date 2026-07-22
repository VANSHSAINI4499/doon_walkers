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
  ConsumerState<AdminSendNotificationScreen> createState() => _AdminSendNotificationScreenState();
}

class _AdminSendNotificationScreenState extends ConsumerState<AdminSendNotificationScreen> {
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

    final created = await ref.read(notificationControllerProvider.notifier).sendNotification(
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

    final error = ref.read(notificationControllerProvider).error;
    debugPrint('AdminSendNotificationScreen: failed to send: $error');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Could not send this notification. Please try again.'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSaving = ref.watch(notificationControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Send Notification')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'This goes out to every registered member as a push '
                      'notification, and shows up in everyone\'s in-app list. '
                      'There\'s no way to target a specific trek or group this '
                      'phase — broadcast only.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty) ? 'Please enter a title' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bodyController,
                      decoration: const InputDecoration(labelText: 'Message'),
                      maxLines: 4,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty) ? 'Please enter a message' : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: isSaving ? null : _submit,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      icon: isSaving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.campaign_rounded),
                      label: const Text('Send to Everyone'),
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
