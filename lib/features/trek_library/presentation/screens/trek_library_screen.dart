import 'package:doon_walkers/core/widgets/coming_soon_screen.dart';
import 'package:flutter/material.dart';

class TrekLibraryScreen extends StatelessWidget {
  const TrekLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      featureName: 'Trek Library',
      icon: Icons.terrain_outlined,
    );
  }
}
