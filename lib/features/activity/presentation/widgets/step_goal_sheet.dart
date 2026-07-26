import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/activity/presentation/providers/activity_dashboard_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom sheet for editing the daily step goal.
///
/// A sheet rather than a Settings row because the goal is only meaningful
/// next to the number it grades — the affordance sits on the Day view's
/// goal ring, where "6,500" is already on screen. Settings lands in a
/// later phase; if a global preferences list wants to host this too, this
/// same sheet can be opened from there without change.
///
/// Offers preset steps plus a free-text field. The presets are what most
/// people actually want (a round number near their current average) and
/// save typing on a phone; the field is there because a goal is personal.
Future<void> showStepGoalSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _StepGoalSheet(),
  );
}

class _StepGoalSheet extends ConsumerStatefulWidget {
  const _StepGoalSheet();

  @override
  ConsumerState<_StepGoalSheet> createState() => _StepGoalSheetState();
}

class _StepGoalSheetState extends ConsumerState<_StepGoalSheet> {
  static const _presets = [4000, 6500, 8000, 10000, 12000];

  late final TextEditingController _controller = TextEditingController(
    text: ref.read(dailyStepGoalProvider).toString(),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? get _parsed {
    final raw = _controller.text.replaceAll(',', '').trim();
    final value = int.tryParse(raw);
    if (value == null) return null;
    // Mirrors the DB CHECK (0034): out-of-band values are rejected here so
    // the user sees a disabled Save rather than a constraint violation.
    if (value < 500 || value > 100000) return null;
    return value;
  }

  Future<void> _save() async {
    final goal = _parsed;
    if (goal == null) return;

    final success = await ref
        .read(stepGoalControllerProvider.notifier)
        .setGoal(goal);
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Couldn't save your goal. Please try again."),
          backgroundColor: AppPalette.of(context).danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isSaving = ref.watch(stepGoalControllerProvider).isLoading;
    final valid = _parsed != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        // Clears the keyboard when the field has focus.
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Daily step goal',
            style: AppTextStyles.titleLarge.copyWith(
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Your weekly and monthly targets follow from this — seven times '
            'it, and once per day of the month.',
            style: AppTextStyles.bodySmall.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final preset in _presets)
                _PresetChip(
                  value: preset,
                  selected: _parsed == preset,
                  onTap: () => setState(() {
                    _controller.text = preset.toString();
                  }),
                  palette: palette,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Steps per day',
              suffixText: 'steps',
              errorText: _controller.text.trim().isEmpty || valid
                  ? null
                  : 'Enter a number between 500 and 100,000',
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Save goal',
            icon: AppIcons.check,
            fullWidth: true,
            isLoading: isSaving,
            onPressed: valid ? _save : null,
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.value,
    required this.selected,
    required this.onTap,
    required this.palette,
  });

  final int value;
  final bool selected;
  final VoidCallback onTap;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? palette.primarySubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? palette.primary : palette.border,
          ),
        ),
        child: Text(
          '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k',
          style: AppTextStyles.labelMedium.copyWith(
            color: selected ? palette.primary : palette.textSecondary,
          ),
        ),
      ),
    );
  }
}
