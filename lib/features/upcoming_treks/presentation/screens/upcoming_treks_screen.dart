import 'package:doon_walkers/core/widgets/coming_soon_screen.dart';
import 'package:flutter/material.dart';

class UpcomingTreksScreen extends StatelessWidget {
  const UpcomingTreksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      featureName: 'Upcoming Treks',
      icon: Icons.event_outlined,
    );
  }
}
