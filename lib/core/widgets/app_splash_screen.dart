import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/icons/app_icons.dart';
import 'package:doon_walkers/core/motion/app_motion.dart';
import 'package:doon_walkers/core/theme/app_colors.dart';
import 'package:doon_walkers/core/theme/app_dimens.dart';
import 'package:doon_walkers/core/theme/app_gradients.dart';
import 'package:doon_walkers/core/theme/app_shadows.dart';
import 'package:doon_walkers/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Branded launch splash — the Flutter-side half of the app's boot
/// sequence (Redesign Phase 7). The other half is the NATIVE platform
/// splash (`android/app/src/main/res/.../launch_background.xml`,
/// `ios/Runner/Base.lproj/LaunchScreen.storyboard`), both re-themed to
/// this same near-black background so there is no default white/bare
/// flash before Flutter can even paint its first frame.
///
/// ## Why this never blocks on a real async gate
///
/// By the time `main()` calls `runApp()`, `Supabase.initialize()` has
/// already completed — and inside it, `SupabaseAuth.initialize()` calls
/// `auth.setInitialSession(...)` from whatever session is persisted in
/// local storage *before its own future resolves*. So
/// `Supabase.instance.client.auth.currentUser` already reflects the real
/// signed-in/guest state at the very first frame, and the router's
/// initial `redirect` decision is already correct synchronously — there
/// is no genuine "waiting for auth" moment left to gate this screen on.
/// (`recoverSession()`, which does a network token-refresh, runs
/// unawaited in the background and only matters for keeping a session
/// alive over time, not for the first frame's routing decision.)
///
/// [SplashGate] therefore holds this screen up for a short **fixed**
/// minimum duration purely so the brand moment reads as intentional
/// rather than a one-frame flicker — never as a real loading wait that
/// could hang on a slow network. See its own doc.
class AppSplashScreen extends StatefulWidget {
  const AppSplashScreen({super.key});

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.pulse,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // A faint radial wash behind the badge, same device Home's hero and
      // the Phase 1 demo gallery use for a glass surface to sit on top of.
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.3, -0.6),
          radius: 1.3,
          colors: [Color(0xFF15241B), AppColors.background],
          stops: [0, 0.7],
        ),
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_controller.value);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.glow(
                      AppColors.primary,
                      opacity: 0.26 + 0.22 * t,
                      radius: 30 + 14 * t,
                    ),
                  ),
                  child: const AppIcon(AppIcons.hiking, color: AppColors.onPrimary, size: 44),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(AppConstants.appName, style: AppTextStyles.headlineMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppConstants.appTagline,
                  style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Wraps the router's already-built content in [AppSplashScreen] for a
/// short fixed minimum, then fades it away to reveal what's underneath.
///
/// The real content is mounted and laid out for the *entire* splash
/// duration (it's simply painted under an opaque overlay, not deferred) —
/// so when the splash fades, there is no navigation, no re-route, no
/// layout jump: whatever screen the router already resolved to is just
/// revealed, which is what makes the transition smooth rather than a cut.
///
/// Used from `MaterialApp.router`'s `builder`, which is why it takes a
/// `child` rather than owning the router itself — see `main.dart`.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  /// The fixed minimum time the splash stays fully opaque before it
  /// starts fading — a brand-polish floor, not a real wait (see
  /// [AppSplashScreen]'s doc for why nothing async gates this).
  static const minDuration = Duration(milliseconds: 550);

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _fadeOut = false;
  bool _removed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(SplashGate.minDuration, () {
      if (mounted) setState(() => _fadeOut = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        if (!_removed)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: _fadeOut,
              child: AnimatedOpacity(
                opacity: _fadeOut ? 0 : 1,
                duration: AppMotion.slow,
                curve: AppMotion.emphasized,
                onEnd: () {
                  // Actually remove the splash (not just hide it) once the
                  // fade finishes, so its pulse AnimationController stops
                  // ticking for the rest of the app's lifetime.
                  if (mounted && _fadeOut) setState(() => _removed = true);
                },
                child: const AppSplashScreen(),
              ),
            ),
          ),
      ],
    );
  }
}
