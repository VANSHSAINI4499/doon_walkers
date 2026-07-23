import 'package:doon_walkers/core/design_system.dart';
import 'package:flutter/material.dart';

/// A living gallery of the Redesign Phase 1 foundation.
///
/// This screen renders every token and component the design system ships
/// — palette, type scale, icons, `GlassCard`, `PremiumButton` in each
/// state, and the skeleton loaders — in isolation, so the foundation can
/// be reviewed and signed off *before* any real screen is rebuilt on top
/// of it in Phase 2.
///
/// It is a developer/design surface, not a user destination: it is
/// reachable at [routeName] but not linked from any user-facing
/// navigation. It reads no data and calls no backend.
class DesignSystemDemoScreen extends StatefulWidget {
  const DesignSystemDemoScreen({super.key});

  static const String routeName = '/design-system';

  @override
  State<DesignSystemDemoScreen> createState() => _DesignSystemDemoScreenState();
}

class _DesignSystemDemoScreenState extends State<DesignSystemDemoScreen> {
  // Drives the "tap to see the loading state" demo on the buttons and
  // the skeleton-vs-content toggle.
  bool _buttonLoading = false;
  bool _showSkeletons = true;

  Future<void> _simulateLoad() async {
    setState(() => _buttonLoading = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _buttonLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // A faint radial wash behind the page so the glass surfaces have
      // something to actually frost — glass over a flat fill reads as a
      // plain tint (see GlassCard's doc).
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.6, -0.8),
            radius: 1.4,
            colors: [Color(0xFF15241B), AppColors.background],
            stops: [0, 0.7],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              backgroundColor: Colors.transparent,
              title: const Text('Design System'),
              leading: IconButton(
                icon: const AppIcon(AppIcons.back),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.huge,
              ),
              sliver: SliverList.list(
                children: [
                  const _SectionTitle('Redesign · Phase 1', 'Foundations'),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Dark-mode-first · Plus Jakarta Sans · Material Symbols '
                    'Rounded (filled) · glassmorphism · bold motion.',
                    style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),

                  const _SectionHeader('Palette'),
                  const _PaletteGrid(),
                  const SizedBox(height: AppSpacing.xxxl),

                  const _SectionHeader('Gradients'),
                  const _GradientRow(),
                  const SizedBox(height: AppSpacing.xxxl),

                  const _SectionHeader('Typography'),
                  const _TypeScale(),
                  const SizedBox(height: AppSpacing.xxxl),

                  const _SectionHeader('Stat numerals'),
                  const _StatShowcase(),
                  const SizedBox(height: AppSpacing.xxxl),

                  const _SectionHeader('Icons · Rounded, filled'),
                  const _IconGrid(),
                  const SizedBox(height: AppSpacing.xxxl),

                  const _SectionHeader('GlassCard'),
                  const _GlassCardShowcase(),
                  const SizedBox(height: AppSpacing.xxxl),

                  const _SectionHeader('PremiumButton'),
                  _ButtonShowcase(
                    loading: _buttonLoading,
                    onSimulate: _simulateLoad,
                  ),
                  const SizedBox(height: AppSpacing.xxxl),

                  _SkeletonHeader(
                    showSkeletons: _showSkeletons,
                    onToggle: () =>
                        setState(() => _showSkeletons = !_showSkeletons),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SkeletonShowcase(showSkeletons: _showSkeletons),
                  const SizedBox(height: AppSpacing.xxxl),

                  const _SectionHeader('Motion'),
                  const _MotionShowcase(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section scaffolding ──────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.eyebrow, this.title);

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(eyebrow, style: AppTextStyles.overline),
      const SizedBox(height: AppSpacing.xs),
      Text(title, style: AppTextStyles.headlineLarge),
    ],
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: AppGradients.primary,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(label, style: AppTextStyles.titleLarge),
      ],
    ),
  );
}

// ── Palette ──────────────────────────────────────────────────────────

class _PaletteGrid extends StatelessWidget {
  const _PaletteGrid();

  static const _swatches = <(String, Color, Color)>[
    ('Background', AppColors.background, AppColors.white),
    ('Surface', AppColors.surface, AppColors.white),
    ('Card', AppColors.card, AppColors.white),
    ('Glass border', AppColors.cardHigh, AppColors.white),
    ('Primary', AppColors.primary, AppColors.onPrimary),
    ('Secondary', AppColors.secondary, AppColors.onSecondary),
    ('Accent', AppColors.accent, AppColors.onAccent),
    ('Danger', AppColors.danger, AppColors.onDanger),
    ('Gold', AppColors.gold, AppColors.onGold),
    ('White', AppColors.white, AppColors.background),
  ];

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.md,
    runSpacing: AppSpacing.md,
    children: [
      for (final (name, color, on) in _swatches)
        Container(
          width: 104,
          height: 96,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                name,
                style: AppTextStyles.labelMedium.copyWith(color: on),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: on.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class _GradientRow extends StatelessWidget {
  const _GradientRow();

  static const _gradients = <(String, LinearGradient)>[
    ('Primary', AppGradients.primary),
    ('Secondary', AppGradients.secondary),
    ('Accent', AppGradients.accent),
    ('Danger', AppGradients.danger),
    ('Gold', AppGradients.gold),
  ];

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.md,
    runSpacing: AppSpacing.md,
    children: [
      for (final (name, gradient) in _gradients)
        Container(
          width: 100,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            name,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.background,
            ),
          ),
        ),
    ],
  );
}

// ── Typography ───────────────────────────────────────────────────────

class _TypeScale extends StatelessWidget {
  const _TypeScale();

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Display', style: AppTextStyles.displaySmall),
        const SizedBox(height: AppSpacing.sm),
        Text('Headline Large', style: AppTextStyles.headlineLarge),
        const SizedBox(height: AppSpacing.sm),
        Text('Title Large', style: AppTextStyles.titleLarge),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Body large — Plus Jakarta Sans stays comfortable in long trek '
          'descriptions, packing lists and comment threads, right down to '
          'the small sizes where the app actually spends most of its time.',
          style: AppTextStyles.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Body small / secondary — captions and metadata.',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        Text('LABEL · OVERLINE', style: AppTextStyles.overline),
      ],
    ),
  );
}

class _StatShowcase extends StatelessWidget {
  const _StatShowcase();

  @override
  Widget build(BuildContext context) => GlassCard(
    glowColor: AppColors.primary,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _stat('128', 'KM WALKED', AppColors.primary),
        _stat('14', 'TREKS', AppColors.secondary),
        _stat('7', 'DAY STREAK', AppColors.accent),
      ],
    ),
  );

  Widget _stat(String value, String label, Color color) => Column(
    children: [
      Text(
        value,
        style: AppTextStyles.tinted(AppTextStyles.statLarge, color),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(label, style: AppTextStyles.statLabel),
    ],
  );
}

// ── Icons ────────────────────────────────────────────────────────────

class _IconGrid extends StatelessWidget {
  const _IconGrid();

  @override
  Widget build(BuildContext context) {
    final entries = AppIcons.all.entries.take(28).toList();
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.lg,
        children: [
          for (final e in entries)
            SizedBox(
              width: 52,
              child: Column(
                children: [
                  AppIcon(e.value, size: 26, color: AppColors.white),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    e.key,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── GlassCard ────────────────────────────────────────────────────────

class _GlassCardShowcase extends StatelessWidget {
  const _GlassCardShowcase();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      GlassCard(
        glowColor: AppColors.primary,
        onTap: () {},
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const AppIcon(
                AppIcons.hiking,
                color: AppColors.onPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tappable glass card', style: AppTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Press it — the whole card scales.',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            const AppIcon(AppIcons.chevronRight, color: AppColors.textSecondary),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      // IntrinsicHeight gives the stretch Row a bounded cross-axis extent
      // so the two cards match height; without it, stretch + Expanded +
      // the cards' own max-height Columns expand toward the viewport
      // inside the scroll view.
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: GlassCard(
                glowColor: AppColors.secondary,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppIcon(AppIcons.insights, color: AppColors.secondary),
                    const SizedBox(height: AppSpacing.md),
                    Text('Glow: blue', style: AppTextStyles.titleSmall),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: PulsingGlassCard(
                glowColor: AppColors.accent,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppIcon(AppIcons.bolt, color: AppColors.accent),
                    const SizedBox(height: AppSpacing.md),
                    Text('Pulsing · live', style: AppTextStyles.titleSmall),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

// ── PremiumButton ────────────────────────────────────────────────────

class _ButtonShowcase extends StatelessWidget {
  const _ButtonShowcase({required this.loading, required this.onSimulate});

  final bool loading;
  final VoidCallback onSimulate;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PremiumButton(
        label: loading ? 'Registering…' : 'Register for this trek',
        icon: AppIcons.hiking,
        isLoading: loading,
        fullWidth: true,
        onPressed: onSimulate,
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          Expanded(
            child: PremiumButton(
              label: 'Secondary',
              icon: AppIcons.map,
              variant: PremiumButtonVariant.secondary,
              onPressed: () {},
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: PremiumButton(
              label: 'Accent',
              variant: PremiumButtonVariant.accent,
              trailingIcon: AppIcons.forward,
              onPressed: () {},
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          Expanded(
            child: PremiumButton(
              label: 'Danger',
              icon: AppIcons.delete,
              variant: PremiumButtonVariant.danger,
              onPressed: () {},
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: PremiumButton(
              label: 'Gold',
              icon: AppIcons.medal,
              variant: PremiumButtonVariant.gold,
              onPressed: () {},
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          Expanded(
            child: PremiumButton(
              label: 'Glass',
              icon: AppIcons.share,
              variant: PremiumButtonVariant.glass,
              onPressed: () {},
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: PremiumButton(
              label: 'Ghost',
              variant: PremiumButtonVariant.ghost,
              onPressed: () {},
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          const PremiumButton.icon(
            icon: AppIcons.favorite,
            variant: PremiumButtonVariant.glass,
          ),
          const SizedBox(width: AppSpacing.md),
          PremiumButton.icon(
            icon: AppIcons.add,
            variant: PremiumButtonVariant.primary,
            onPressed: () {},
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: PremiumButton(
              label: 'Disabled',
              icon: AppIcons.lock,
              onPressed: null,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'Tap “Register” to see the in-place loading state (no reflow).',
        style: AppTextStyles.bodySmall,
      ),
    ],
  );
}

// ── Skeletons ────────────────────────────────────────────────────────

class _SkeletonHeader extends StatelessWidget {
  const _SkeletonHeader({required this.showSkeletons, required this.onToggle});

  final bool showSkeletons;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 4,
        height: 20,
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      const SizedBox(width: AppSpacing.md),
      Text('Skeleton loaders', style: AppTextStyles.titleLarge),
      const Spacer(),
      PremiumButton(
        label: showSkeletons ? 'Show content' : 'Show loading',
        size: PremiumButtonSize.small,
        variant: PremiumButtonVariant.glass,
        icon: showSkeletons ? AppIcons.visible : AppIcons.sync,
        onPressed: onToggle,
      ),
    ],
  );
}

class _SkeletonShowcase extends StatelessWidget {
  const _SkeletonShowcase({required this.showSkeletons});

  final bool showSkeletons;

  @override
  Widget build(BuildContext context) {
    if (showSkeletons) {
      return const Column(
        children: [
          SkeletonCardPlaceholder(),
          SizedBox(height: AppSpacing.lg),
          SkeletonStatRow(),
          SizedBox(height: AppSpacing.lg),
          SkeletonTileList(count: 2),
        ],
      );
    }
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Roopkund Trek', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'The real content lands into the exact shape the skeleton '
            'held — no layout jump, no spinner.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          const Row(
            children: [
              _MetaChip(icon: AppIcons.altitude, label: '5,029 m'),
              SizedBox(width: AppSpacing.sm),
              _MetaChip(icon: AppIcons.duration, label: '8 days'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: AppColors.cardHigh,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(color: AppColors.glassBorder),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTextStyles.labelMedium),
      ],
    ),
  );
}

// ── Motion ───────────────────────────────────────────────────────────

class _MotionShowcase extends StatefulWidget {
  const _MotionShowcase();

  @override
  State<_MotionShowcase> createState() => _MotionShowcaseState();
}

class _MotionShowcaseState extends State<_MotionShowcase> {
  bool _expanded = false;
  bool _favorited = false;
  int _revealNonce = 0;

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reusable primitives other phases call into — AnimatedContainer, '
          'AnimatedScale, AppReveal (staggered entrance), plus the shared-'
          'axis / fade-through page transitions in AppTransitions.',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            PremiumButton(
              label: _expanded ? 'Collapse' : 'Expand',
              size: PremiumButtonSize.small,
              variant: PremiumButtonVariant.glass,
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
            const SizedBox(width: AppSpacing.md),
            Pressable(
              onTap: () => setState(() => _favorited = !_favorited),
              child: AnimatedScale(
                scale: _favorited ? 1.15 : 1,
                duration: AppMotion.medium,
                curve: AppMotion.spring,
                child: AppIcon(
                  AppIcons.favorite,
                  color: _favorited ? AppColors.danger : AppColors.textDisabled,
                ),
              ),
            ),
            const Spacer(),
            PremiumButton(
              label: 'Replay reveal',
              size: PremiumButtonSize.small,
              variant: PremiumButtonVariant.ghost,
              onPressed: () => setState(() => _revealNonce++),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AnimatedContainer(
          duration: AppMotion.medium,
          curve: AppMotion.emphasized,
          height: _expanded ? 96 : 44,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppGradients.primary,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Text(
            'AnimatedContainer',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.onPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Rebuilt with a fresh key each replay so AppReveal re-runs.
        Column(
          key: ValueKey(_revealNonce),
          children: [
            for (var i = 0; i < 3; i++)
              AppReveal(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      const AppIcon(AppIcons.taskDone, size: 18, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Staggered item ${i + 1}',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
