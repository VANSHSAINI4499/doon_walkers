import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:flutter/material.dart';

/// Gets the consistent design color for a [TrekBookingStatus].
Color getTrekStatusColor(TrekBookingStatus status, AppPalette palette) {
  return switch (status) {
    TrekBookingStatus.open => const Color(0xFF4CAF50),       // Green
    TrekBookingStatus.almostFull => const Color(0xFFFB8C00), // Orange
    TrekBookingStatus.waitlist => const Color(0xFFFFB300),   // Amber
    TrekBookingStatus.closed => palette.danger,              // Red
    TrekBookingStatus.completed => Colors.blueGrey,          // Blue/Grey
    TrekBookingStatus.cancelled => Colors.grey,              // Grey
  };
}
