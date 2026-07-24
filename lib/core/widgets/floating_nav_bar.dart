import 'package:doon_walkers/core/icons/app_icons.dart';
import 'package:doon_walkers/core/motion/app_motion.dart';
import 'package:doon_walkers/core/motion/pressable.dart';
import 'package:doon_walkers/core/theme/app_colors.dart';
import 'package:doon_walkers/core/theme/app_dimens.dart';
import 'package:doon_walkers/core/theme/app_shadows.dart';
import 'package:doon_walkers/core/theme/app_text_styles.dart';
import 'package:doon_walkers/core/widgets/glass_card.dart';
import 'package:flutter/material.dart';

/// One tab in a [FloatingNavBar] — a filled Material Symbol plus a label.
class FloatingNavBarDestination {
  const FloatingNavBarDestination({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// The app's bottom navigation chrome — a floating glass pill, restyled
/// onto the design system in Redesign Phase 7.
///
/// Deliberately a thin presentation layer: it takes an already-resolved
/// [selectedIndex] and a flat [destinations] list and renders them. It
/// does **not** decide which tabs exist for the current role or clamp the
/// selected index — that logic (`resolveSelectedTabIndex`, the
/// role-conditional destinations list) lives in `AppShell` and has its own
/// dedicated crash-history-driven test coverage; this widget only ever
/// receives a value that's already safe to render, same contract the
/// stock `NavigationBar` it replaces had.
///
/// Visual language: a [GlassCard] shell (blur off — this widget is
/// mounted for the app's entire session and repaints under every
/// scrolling screen, exactly the persistent/perf-sensitive case
/// [GlassCard]'s own doc says to skip backdrop blur for for) with each tab
/// getting a spring-scaled icon and a soft glow pill behind it while
/// selected — the "scale/glow on the active tab" the redesign asks for,
/// built from the same [Pressable]/[AppMotion]/[AppShadows] vocabulary as
/// every other animated control in the app.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  }) : assert(
         selectedIndex >= 0 && selectedIndex < destinations.length,
         'selectedIndex must already be clamped by the caller — see '
         'AppShell.resolveSelectedTabIndex.',
       );

  final List<FloatingNavBarDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: GlassCard(
          blurEnabled: false,
          padding: EdgeInsets.zero,
          borderRadius: AppRadius.xl,
          height: 68,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _FloatingNavTab(
                    destination: destinations[i],
                    selected: i == selectedIndex,
                    onTap: () => onDestinationSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingNavTab extends StatelessWidget {
  const _FloatingNavTab({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final FloatingNavBarDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Pressable(
        onTap: onTap,
        scale: AppMotion.pressScale,
        haptic: true,
        child: AnimatedContainer(
          duration: AppMotion.medium,
          curve: AppMotion.emphasized,
          margin: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: selected ? AppShadows.glow(AppColors.primary, opacity: 0.35, radius: 14) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: selected ? 1.08 : 1.0,
                duration: AppMotion.medium,
                curve: AppMotion.spring,
                child: AppIcon(destination.icon, color: color, size: 24),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: AppMotion.fast,
                style: AppTextStyles.tinted(AppTextStyles.labelSmall, color),
                child: Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
