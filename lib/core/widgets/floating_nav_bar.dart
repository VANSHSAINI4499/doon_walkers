import 'package:doon_walkers/core/icons/app_icons.dart';
import 'package:doon_walkers/core/motion/app_motion.dart';
import 'package:doon_walkers/core/motion/pressable.dart';
import 'package:doon_walkers/core/theme/app_dimens.dart';
import 'package:doon_walkers/core/theme/app_palette.dart';
import 'package:doon_walkers/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// One tab in a [FloatingNavBar] — a Material Symbol plus a label.
class FloatingNavBarDestination {
  const FloatingNavBarDestination({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// The app's bottom navigation chrome.
///
/// Deliberately a thin presentation layer: it takes an already-resolved
/// [selectedIndex] and a flat [destinations] list and renders them. It
/// does **not** decide which tabs exist for the current role or clamp the
/// selected index — that logic (`resolveSelectedTabIndex`, the
/// role-conditional destinations list) lives in `AppShell` and has its own
/// crash-history-driven test coverage.
///
/// ## Visual language
///
/// A flat bar sitting flush against the bottom edge, separated from the
/// page by a single hairline. The previous version floated as an inset
/// glass pill with a glowing halo behind the active tab; both are gone.
///
/// Selection is now carried by three quiet signals that stack:
/// the accent colour on the icon and label, a soft [AppPalette.primarySubtle]
/// pill behind the icon, and a small scale. That is enough — a user
/// looking for "which tab am I on" finds it instantly, and a user
/// reading the content above never notices the bar at all.
///
/// The bar deliberately does not float. Chrome that hovers over content
/// competes with it; chrome pinned to the edge disappears.
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
    final palette = AppPalette.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _NavTab(
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

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final FloatingNavBarDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final color = selected ? palette.primary : palette.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Pressable(
        onTap: onTap,
        scale: AppMotion.pressScale,
        haptic: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AppMotion.medium,
              curve: AppMotion.standard,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: selected ? palette.primarySubtle : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: AppIcon(destination.icon, color: color, size: 22),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: AppMotion.fast,
              style: AppTextStyles.labelSmall.copyWith(color: color),
              child: Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
