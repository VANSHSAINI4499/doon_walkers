import 'package:doon_walkers/core/widgets/coming_soon_screen.dart';
import 'package:flutter/material.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      featureName: 'Admin Panel',
      icon: Icons.admin_panel_settings_outlined,
    );
  }
}
