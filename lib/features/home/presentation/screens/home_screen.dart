import 'package:doon_walkers/core/widgets/coming_soon_screen.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      featureName: 'Home',
      icon: Icons.home_outlined,
    );
  }
}
