import 'package:doon_walkers/core/design_system.dart';
import 'package:flutter/material.dart';

/// Isolated review harness for the Redesign Phase 7 splash sequence.
///
/// The real splash (`SplashGate` wrapping `MaterialApp.router` in
/// `lib/main.dart`) needs Supabase/Firebase init to demonstrate the real
/// boot sequence, which this offline harness can't run. Instead this
/// mounts the exact same [SplashGate]/[AppSplashScreen] widgets around a
/// simple placeholder "landed" screen, so the visual — the pulsing badge,
/// the fixed hold, and the crossfade reveal — can be judged directly.
///
/// A "Replay" button rebuilds SplashGate under a fresh key so the whole
/// sequence can be watched more than once without restarting the app.
///
/// ```
/// flutter run -t lib/main_splash_demo.dart
/// ```
void main() => runApp(const _SplashDemoApp());

class _SplashDemoApp extends StatefulWidget {
  const _SplashDemoApp();

  @override
  State<_SplashDemoApp> createState() => _SplashDemoAppState();
}

class _SplashDemoAppState extends State<_SplashDemoApp> {
  int _replayCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DoonWalkers · Splash',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: SplashGate(
        key: ValueKey(_replayCount),
        child: _LandedScreen(onReplay: () => setState(() => _replayCount++)),
      ),
    );
  }
}

class _LandedScreen extends StatelessWidget {
  const _LandedScreen({required this.onReplay});

  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Landed')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlassCard(
                glowColor: AppColors.primary,
                child: Column(
                  children: [
                    const AppIcon(AppIcons.checkCircle, size: 40, color: AppColors.primary),
                    const SizedBox(height: AppSpacing.md),
                    Text('Real content, already here', style: AppTextStyles.titleLarge),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'This screen was built and laid out underneath the '
                      'splash for its ENTIRE duration — the splash just '
                      'faded away to reveal it. No navigation happened, no '
                      'jump, no re-route.',
                      style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              PremiumButton(
                label: 'Replay splash',
                icon: AppIcons.refresh,
                onPressed: onReplay,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
