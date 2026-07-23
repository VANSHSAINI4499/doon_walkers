import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Unit hint shown after each tier-threshold field — purely a UX aid,
/// same information [ChallengeMetric.formatValue] encodes for display
/// elsewhere; kept as a small separate switch here since a bare number
/// field doesn't have anywhere else to show it inline.
String? _thresholdSuffixFor(ChallengeMetric metric) => switch (metric) {
  ChallengeMetric.totalDistanceKm || ChallengeMetric.dailyDistanceKm => 'km',
  ChallengeMetric.dailySteps || ChallengeMetric.weeklySteps || ChallengeMetric.monthlySteps => 'steps',
  ChallengeMetric.caloriesBurned => 'kcal',
  ChallengeMetric.activeStreakDays => 'days',
  ChallengeMetric.trekCount => null,
};

/// Shared Add/Edit challenge form — [challengeId] null means "Add
/// Challenge" (empty form, calls createChallenge); non-null means
/// "Edit Challenge" (pre-filled from [challengeByIdProvider], calls
/// updateChallenge). Mirrors AdminProductFormScreen's dual-mode shape.
///
/// Unlike Product, there's no separate images/gallery step — a
/// challenge's only "content" beyond its fields is its 4 tier
/// thresholds, which this single form owns end-to-end (create+edit),
/// same reasoning as why tiers are written in the same repository call
/// as the challenge row itself rather than a separate screen.
class AdminChallengeFormScreen extends ConsumerStatefulWidget {
  const AdminChallengeFormScreen({super.key, this.challengeId});

  final String? challengeId;

  bool get isEdit => challengeId != null;

  @override
  ConsumerState<AdminChallengeFormScreen> createState() => _AdminChallengeFormScreenState();
}

class _AdminChallengeFormScreenState extends ConsumerState<AdminChallengeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final Map<ChallengeTier, TextEditingController> _tierControllers = {
    for (final tier in ChallengeTier.values) tier: TextEditingController(),
  };

  ChallengeMetric _metric = ChallengeMetric.trekCount;
  ChallengeTimeWindow _timeWindow = ChallengeTimeWindow.allTime;
  DateTime? _startDate;
  DateTime? _endDate;
  String _icon = ChallengeIcon.keys.first;

  bool _prefilled = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (final controller in _tierControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _prefillFrom(Challenge challenge) {
    if (_prefilled) return;
    _titleController.text = challenge.title;
    _descriptionController.text = challenge.description;
    _metric = challenge.metric;
    _timeWindow = challenge.timeWindow;
    _startDate = challenge.startDate;
    _endDate = challenge.endDate;
    _icon = challenge.icon ?? ChallengeIcon.keys.first;
    for (final threshold in challenge.tiers) {
      _tierControllers[threshold.tier]?.text = _trimZero(threshold.thresholdValue);
    }
    _prefilled = true;
  }

  String _trimZero(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toString();

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  /// Thresholds must strictly increase bronze → platinum — app-level
  /// only, not a DB constraint, same convention as other
  /// admin-form-only validation in this project (e.g. required fields
  /// that are nullable at the DB layer).
  String? _validateTiers() {
    double? previous;
    for (final tier in ChallengeTier.values) {
      final text = _tierControllers[tier]!.text.trim();
      if (text.isEmpty) return '${tier.label} threshold is required.';
      final value = double.tryParse(text);
      if (value == null) return '${tier.label} threshold must be a number.';
      if (value < 0) return '${tier.label} threshold can\'t be negative.';
      if (previous != null && value <= previous) {
        return 'Tier thresholds must strictly increase (${tier.label} must be greater '
            'than the tier before it).';
      }
      previous = value;
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_timeWindow == ChallengeTimeWindow.customRange &&
        (_startDate == null || _endDate == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set both a start and end date for a custom range.')),
      );
      return;
    }
    if (_startDate != null && _endDate != null && !_endDate!.isAfter(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date must be after the start date.')),
      );
      return;
    }

    final tiersError = _validateTiers();
    if (tiersError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tiersError)));
      return;
    }

    final controller = ref.read(challengeAdminControllerProvider.notifier);
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final tierThresholds = {
      for (final tier in ChallengeTier.values)
        tier: double.parse(_tierControllers[tier]!.text.trim()),
    };
    // customRange is the only window that persists dates; all_time/monthly
    // ignore start/end entirely (see 0022_challenges.sql / RPC filtering).
    final startDate = _timeWindow == ChallengeTimeWindow.customRange ? _startDate : null;
    final endDate = _timeWindow == ChallengeTimeWindow.customRange ? _endDate : null;

    if (widget.isEdit) {
      final success = await controller.updateChallenge(
        id: widget.challengeId!,
        title: title,
        description: description,
        metric: _metric,
        timeWindow: _timeWindow,
        startDate: startDate,
        endDate: endDate,
        icon: _icon,
        tierThresholds: tierThresholds,
      );
      if (!mounted || !success) return;
      context.pop();
    } else {
      final created = await controller.createChallenge(
        title: title,
        description: description,
        metric: _metric,
        timeWindow: _timeWindow,
        startDate: startDate,
        endDate: endDate,
        icon: _icon,
        tierThresholds: tierThresholds,
      );
      if (!mounted || created == null) return;
      context.pop();
    }
  }

  String _cleanError(Object error) {
    debugPrint('AdminChallengeFormScreen: mutation failed: $error');
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    ref.listen<AsyncValue<void>>(challengeAdminControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stack) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_cleanError(error)),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        },
      );
    });

    if (widget.isEdit) {
      final challengeAsync = ref.watch(challengeByIdProvider(widget.challengeId!));
      return challengeAsync.when(
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Edit Challenge')),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) {
          debugPrint(
            'AdminChallengeFormScreen: failed to load challenge ${widget.challengeId}: $error',
          );
          return Scaffold(
            appBar: AppBar(title: const Text('Edit Challenge')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 40, color: theme.colorScheme.error),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load this challenge.',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(challengeByIdProvider(widget.challengeId!)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        data: (challenge) {
          if (challenge == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Edit Challenge')),
              body: const Center(child: Text('Challenge not found.')),
            );
          }
          _prefillFrom(challenge);
          return _buildForm(context, title: 'Edit Challenge');
        },
      );
    }

    return _buildForm(context, title: 'Add Challenge');
  }

  Widget _buildForm(BuildContext context, {required String title}) {
    final theme = Theme.of(context);
    final isSaving = ref.watch(challengeAdminControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty) ? 'Please enter a title' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<ChallengeMetric>(
                      value: _metric,
                      decoration: const InputDecoration(labelText: 'Metric'),
                      items: ChallengeMetric.values
                          .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _metric = value);
                      },
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<ChallengeTimeWindow>(
                      value: _timeWindow,
                      decoration: const InputDecoration(labelText: 'Time Window'),
                      items: ChallengeTimeWindow.values
                          .map((w) => DropdownMenuItem(value: w, child: Text(w.label)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _timeWindow = value);
                      },
                    ),
                    if (_timeWindow == ChallengeTimeWindow.customRange) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _pickDate(isStart: true),
                              child: Text(
                                _startDate == null ? 'Start date' : _formatDate(_startDate!),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _pickDate(isStart: false),
                              child: Text(
                                _endDate == null ? 'End date' : _formatDate(_endDate!),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: _icon,
                      decoration: const InputDecoration(labelText: 'Icon'),
                      items: ChallengeIcon.keys
                          .map(
                            (key) => DropdownMenuItem(
                              value: key,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(ChallengeIcon.forKey(key), size: 20),
                                  const SizedBox(width: 10),
                                  Text(ChallengeIcon.labelForKey(key)),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _icon = value);
                      },
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Tier Thresholds',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Each tier\'s threshold must be greater than the one before it.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    for (final tier in ChallengeTier.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: _tierControllers[tier],
                          decoration: InputDecoration(
                            labelText: '${tier.label} threshold',
                            suffixText: _thresholdSuffixFor(_metric),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    const SizedBox(height: 8),

                    FilledButton(
                      onPressed: isSaving ? null : _submit,
                      style:
                          FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(widget.isEdit ? 'Save Changes' : 'Create Challenge'),
                    ),
                    const SizedBox(height: 24),
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
