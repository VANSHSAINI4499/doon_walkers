import 'package:doon_walkers/core/design_system.dart';
import 'package:flutter/material.dart';

/// The **review harness for the calm design system foundation**.
///
/// Renders every token and component the foundation ships, with a
/// light/dark switch in the app bar so both themes can be checked in one
/// run. It is the answer to "does this actually look calm, and does it
/// hold up in light mode" without booting the real app.
///
/// ```
/// flutter run -t lib/main_design_demo.dart
/// ```
///
/// The switch wraps the content in a local [Theme], overriding the host
/// app's theme for this subtree only — no OS setting to change and no
/// restart. That is also why every section below reads colour from
/// [AppPalette.of]: this screen is the one place where getting that wrong
/// is immediately visible.
///
/// It is a developer/design surface, not a user destination: reachable at
/// [routeName] but not linked from any user-facing navigation. It reads
/// no data and calls no backend.
class DesignSystemDemoScreen extends StatefulWidget {
  const DesignSystemDemoScreen({super.key});

  static const String routeName = '/design-system';

  @override
  State<DesignSystemDemoScreen> createState() => _DesignSystemDemoScreenState();
}

class _DesignSystemDemoScreenState extends State<DesignSystemDemoScreen> {
  Brightness _brightness = Brightness.light;

  bool get _isDark => _brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _isDark ? AppTheme.dark : AppTheme.light,
      // A Builder so the sections below resolve the *overridden* theme
      // rather than the host app's.
      child: Builder(
        builder: (context) {
          final palette = AppPalette.of(context);
          return Scaffold(
            backgroundColor: palette.background,
            appBar: AppBar(
              title: const Text('Design System'),
              actions: [
                _ThemeSwitch(
                  isDark: _isDark,
                  onChanged: (dark) => setState(
                    () =>
                        _brightness = dark ? Brightness.dark : Brightness.light,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ),
            bottomNavigationBar: const _DemoNavBar(),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.huge,
              ),
              children: const [
                _Section(
                  title: 'Hero stat',
                  caption: 'One number per screen. Everything else whispers.',
                  child: _HeroStatDemo(),
                ),
                _Section(
                  title: 'Stat row',
                  caption: 'Two to four. Hairlines instead of three cards.',
                  child: _StatRowDemo(),
                ),
                _Section(
                  title: 'Progress',
                  caption: 'Flat track, flat fill, animates to its value.',
                  child: _ProgressDemo(),
                ),
                _Section(
                  title: 'Cards',
                  caption: 'Flat fill, hairline, level-1 shadow. No blur.',
                  child: _CardsDemo(),
                ),
                _Section(
                  title: 'Buttons',
                  caption: 'Flat fills. At most one primary per screen.',
                  child: _ButtonsDemo(),
                ),
                _Section(
                  title: 'Button sizes & states',
                  child: _ButtonStatesDemo(),
                ),
                _Section(
                  title: 'Surfaces',
                  caption: 'Back to front. Same order in both themes.',
                  child: _SurfacesDemo(),
                ),
                _Section(
                  title: 'Accent & meaning',
                  caption: 'One dominant accent; the rest carry meaning.',
                  child: _AccentDemo(),
                ),
                _Section(
                  title: 'Achievement metals',
                  caption: 'Badges and medals only — never a card fill.',
                  child: _MetalsDemo(),
                ),
                _Section(
                  title: 'Typography',
                  caption: 'Heavy numerals, medium titles, calm body.',
                  child: _TypeDemo(),
                ),
                _Section(
                  title: 'Material widgets',
                  caption: 'Themed, so unmigrated screens land here too.',
                  child: _MaterialDemo(),
                ),
                _Section(
                  title: 'Loading',
                  caption: 'Screens load into skeletons, not spinners.',
                  child: _SkeletonDemo(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The light/dark switch in the app bar.
class _ThemeSwitch extends StatelessWidget {
  const _ThemeSwitch({required this.isDark, required this.onChanged});

  final bool isDark;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Row(
      children: [
        Text(
          isDark ? 'Dark' : 'Light',
          style: AppTextStyles.labelMedium.copyWith(
            color: palette.textSecondary,
          ),
        ),
        Switch(value: isDark, onChanged: onChanged),
      ],
    );
  }
}

/// A titled block. The generous gap above each one is doing most of the
/// work of making this page readable — which is rather the point.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.caption});

  final String title;
  final String? caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: AppTextStyles.overline.copyWith(
              color: palette.textSecondary,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              caption!,
              style: AppTextStyles.bodySmall.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _HeroStatDemo extends StatelessWidget {
  const _HeroStatDemo();

  @override
  Widget build(BuildContext context) => const AppCard(
    child: AnimatedStatDisplay(
      value: 8432,
      eyebrow: 'Today',
      label: 'steps',
      size: StatSize.hero,
    ),
  );
}

class _StatRowDemo extends StatelessWidget {
  const _StatRowDemo();

  @override
  Widget build(BuildContext context) => const AppCard(
    child: StatRow(
      stats: [
        StatDisplay(value: '12', label: 'treks'),
        StatDisplay(value: '86', label: 'km'),
        StatDisplay(value: '5', label: 'badges'),
      ],
    ),
  );
}

class _ProgressDemo extends StatelessWidget {
  const _ProgressDemo();

  @override
  Widget build(BuildContext context) => const AppCard(
    child: Column(
      children: [
        AppProgressBar(
          value: 0.62,
          label: 'Progress to Gold',
          trailing: '62%',
        ),
        SizedBox(height: AppSpacing.xl),
        Center(
          child: AppProgressRing(
            value: 0.62,
            child: StatDisplay(
              value: '62',
              unit: '%',
              label: 'complete',
              size: StatSize.medium,
              alignment: CrossAxisAlignment.center,
            ),
          ),
        ),
      ],
    ),
  );
}

class _CardsDemo extends StatelessWidget {
  const _CardsDemo();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Column(
      children: [
        AppCard(
          onTap: () {},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tappable card', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Scales slightly on press. That is the only feedback it '
                'needs.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          borderColor: palette.primary.withValues(alpha: 0.55),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Active card', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'A tinted hairline marks this as live — the calm '
                'replacement for a coloured glow.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          elevation: 0,
          color: palette.backgroundAlt,
          child: Row(
            children: [
              AppIcon(AppIcons.info, size: 20, color: palette.textSecondary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Flat, shadowless — for a card on an already-banded '
                  'section.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ButtonsDemo extends StatelessWidget {
  const _ButtonsDemo();

  static const _variants = <(String, AppButtonVariant)>[
    ('Primary', AppButtonVariant.primary),
    ('Secondary', AppButtonVariant.secondary),
    ('Accent', AppButtonVariant.accent),
    ('Danger', AppButtonVariant.danger),
    ('Gold', AppButtonVariant.gold),
    ('Outlined', AppButtonVariant.glass),
    ('Ghost', AppButtonVariant.ghost),
  ];

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.md,
    runSpacing: AppSpacing.md,
    children: [
      for (final (label, variant) in _variants)
        AppButton(label: label, variant: variant, onPressed: () {}),
    ],
  );
}

class _ButtonStatesDemo extends StatelessWidget {
  const _ButtonStatesDemo();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          AppButton(
            label: 'Small',
            size: AppButtonSize.small,
            onPressed: () {},
          ),
          AppButton(
            label: 'Medium',
            size: AppButtonSize.medium,
            onPressed: () {},
          ),
          AppButton(label: 'Large', size: AppButtonSize.large, onPressed: () {}),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const AppButton(label: 'Disabled'),
          const AppButton(label: 'Loading', isLoading: true),
          AppButton(
            label: 'With icon',
            icon: AppIcons.hiking,
            onPressed: () {},
          ),
          AppButton.icon(icon: AppIcons.favorite, onPressed: () {}),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      AppButton(
        label: 'Full width primary',
        icon: AppIcons.check,
        fullWidth: true,
        onPressed: () {},
      ),
    ],
  );
}

class _SurfacesDemo extends StatelessWidget {
  const _SurfacesDemo();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return _SwatchGrid(
      swatches: [
        ('background', p.background),
        ('backgroundAlt', p.backgroundAlt),
        ('surface', p.surface),
        ('card', p.card),
        ('cardHigh', p.cardHigh),
        ('border', p.border),
      ],
    );
  }
}

class _AccentDemo extends StatelessWidget {
  const _AccentDemo();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return _SwatchGrid(
      swatches: [
        ('primary', p.primary),
        ('primaryContainer', p.primaryContainer),
        ('secondary', p.secondary),
        ('accent', p.accent),
        ('danger', p.danger),
        ('textSecondary', p.textSecondary),
      ],
    );
  }
}

class _MetalsDemo extends StatelessWidget {
  const _MetalsDemo();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final tiers = <(String, Color)>[
      ('Bronze', p.bronze),
      ('Silver', p.silver),
      ('Gold', p.gold),
      ('Platinum', p.platinum),
    ];
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final (label, color) in tiers)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(AppIcons.medal, size: 16, color: color),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: AppTextStyles.labelMedium.copyWith(color: color),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SwatchGrid extends StatelessWidget {
  const _SwatchGrid({required this.swatches});

  final List<(String, Color)> swatches;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final (name, color) in swatches)
          SizedBox(
            width: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: palette.border),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  name,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: palette.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TypeDemo extends StatelessWidget {
  const _TypeDemo();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final samples = <(String, TextStyle)>[
      ('displaySmall', AppTextStyles.displaySmall),
      ('headlineMedium', AppTextStyles.headlineMedium),
      ('titleLarge', AppTextStyles.titleLarge),
      ('titleMedium', AppTextStyles.titleMedium),
      ('bodyLarge', AppTextStyles.bodyLarge),
      ('labelLarge', AppTextStyles.labelLarge),
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (name, style) in samples) ...[
            Text(
              name,
              style: AppTextStyles.labelSmall.copyWith(
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text('Walk the Doon valley', style: style),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(
            'Body copy sets loose at a 1.5 line height, because trek '
            'descriptions and community rules run long and need to stay '
            'comfortable at length.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialDemo extends StatefulWidget {
  const _MaterialDemo();

  @override
  State<_MaterialDemo> createState() => _MaterialDemoState();
}

class _MaterialDemoState extends State<_MaterialDemo> {
  bool _switched = true;
  bool _checked = true;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TextField(
          decoration: InputDecoration(
            labelText: 'Trek name',
            hintText: 'e.g. Nag Tibba',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            const Chip(label: Text('Easy')),
            FilterChip(
              label: const Text('Selected'),
              selected: true,
              onSelected: (_) {},
            ),
            const Chip(label: Text('Weekend')),
          ],
        ),
        SwitchListTile(
          value: _switched,
          onChanged: (v) => setState(() => _switched = v),
          title: const Text('Show me on the leaderboard'),
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          value: _checked,
          onChanged: (v) => setState(() => _checked = v ?? false),
          title: const Text('I have read the trek rules'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const Divider(),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            TextButton(onPressed: () {}, child: const Text('Text')),
            OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
            FilledButton(onPressed: () {}, child: const Text('Filled')),
          ],
        ),
      ],
    ),
  );
}

class _SkeletonDemo extends StatelessWidget {
  const _SkeletonDemo();

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      SkeletonList(count: 1, padding: EdgeInsets.zero),
      SizedBox(height: AppSpacing.lg),
      SkeletonTileList(count: 2),
      SizedBox(height: AppSpacing.lg),
      AppCard(child: SkeletonStatRow()),
    ],
  );
}

/// The real [FloatingNavBar], so the chrome gets reviewed in the same
/// pass as the components it frames.
class _DemoNavBar extends StatefulWidget {
  const _DemoNavBar();

  @override
  State<_DemoNavBar> createState() => _DemoNavBarState();
}

class _DemoNavBarState extends State<_DemoNavBar> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => FloatingNavBar(
    selectedIndex: _index,
    onDestinationSelected: (i) => setState(() => _index = i),
    destinations: const [
      FloatingNavBarDestination(icon: AppIcons.home, label: 'Home'),
      FloatingNavBarDestination(icon: AppIcons.treks, label: 'Treks'),
      FloatingNavBarDestination(icon: AppIcons.challenges, label: 'Challenges'),
      FloatingNavBarDestination(icon: AppIcons.profile, label: 'Profile'),
    ],
  );
}
