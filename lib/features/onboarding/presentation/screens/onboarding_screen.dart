import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/shared_preferences_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class _OnboardingSlide {
  const _OnboardingSlide({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;
}

/// Grounded in what the app actually does — no generic template copy.
const _slides = [
  _OnboardingSlide(
    icon: AppIcons.landscape,
    title: 'Welcome to Doon Walkers',
    body: 'A Dehradun-based community of trekkers exploring the Himalayas '
        'together — real treks, real people.',
  ),
  _OnboardingSlide(
    icon: AppIcons.treks,
    title: 'Discover & Register for Treks',
    body: 'Browse upcoming treks, check difficulty and distance, and '
        'register in a few taps — from easy weekend walks to multi-day '
        'Himalayan routes.',
  ),
  _OnboardingSlide(
    icon: AppIcons.challenges,
    title: 'Turn Your Treks into Challenges',
    body: 'Your steps, distance, and trekking streaks are tracked '
        'automatically — climb from Bronze to Platinum as you go.',
  ),
  _OnboardingSlide(
    icon: AppIcons.group,
    title: 'Stay Connected',
    body: 'Join the conversation on every trek, relive the trip through '
        'shared photos, and grab official Doon Walkers merch.',
  ),
];

/// First-launch intro carousel — shown once per device, before Sign In.
///
/// Gated entirely by app_router.dart's `initialLocation` check against
/// [AppConstants.prefsHasSeenOnboarding]; this screen's only
/// responsibility once shown is to record that flag and hand off to
/// Sign In, via [_finish] (Skip and the final slide's CTA both call it).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (page != _page) setState(() => _page = page);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(sharedPreferencesProvider).setBool(AppConstants.prefsHasSeenOnboarding, true);
    if (!mounted) return;
    context.go(AppConstants.routeSignIn);
  }

  void _next() {
    if (_page == _slides.length - 1) {
      _finish();
    } else {
      _pageController.nextPage(duration: AppMotion.page, curve: AppMotion.emphasized);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: TextButton(
                  onPressed: _finish,
                  child: Text('Skip', style: AppTextStyles.secondary(AppTextStyles.labelLarge)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                itemBuilder: (context, index) => AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    var t = (_page - index).toDouble();
                    if (_pageController.hasClients && _pageController.position.haveDimensions) {
                      t = (_pageController.page ?? _page.toDouble()) - index;
                    }
                    final distance = t.clamp(-1.0, 1.0).abs();
                    return Opacity(
                      opacity: 1 - distance,
                      child: Transform.scale(scale: 1 - (distance * 0.1), child: child),
                    );
                  },
                  child: _SlideContent(slide: _slides[index]),
                ),
              ),
            ),
            _DotIndicator(count: _slides.length, activePage: _page),
            const SizedBox(height: AppSpacing.xxl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: PremiumButton(
                label: isLast ? 'Get Started' : 'Next',
                trailingIcon: isLast ? null : AppIcons.forward,
                fullWidth: true,
                onPressed: _next,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _SlideContent extends StatelessWidget {
  const _SlideContent({required this.slide});

  final _OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              shape: BoxShape.circle,
              boxShadow: AppShadows.glow(AppColors.primary, opacity: 0.28, radius: 40),
            ),
            child: AppIcon(slide.icon, size: 64, color: AppColors.onPrimary),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Text(slide.title, style: AppTextStyles.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          Text(
            slide.body,
            style: AppTextStyles.secondary(AppTextStyles.bodyLarge),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.count, required this.activePage});

  final int count;
  final int activePage;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: AppMotion.medium,
            curve: AppMotion.emphasized,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            width: i == activePage ? 28 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              color: i == activePage ? AppColors.primary : AppColors.glassBorder,
              boxShadow: i == activePage
                  ? AppShadows.glow(AppColors.primary, opacity: 0.5, radius: 12)
                  : null,
            ),
          ),
      ],
    );
  }
}
