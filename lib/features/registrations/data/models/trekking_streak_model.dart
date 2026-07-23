import 'package:doon_walkers/features/registrations/domain/entities/trekking_streak.dart';

/// Data model for the single row returned by the `get_my_streak()` RPC.
class TrekkingStreakModel extends TrekkingStreak {
  const TrekkingStreakModel({required super.currentMonths, required super.longestMonths});

  factory TrekkingStreakModel.fromJson(Map<String, dynamic> json) {
    return TrekkingStreakModel(
      currentMonths: (json['current_streak_months'] as num?)?.toInt() ?? 0,
      longestMonths: (json['longest_streak_months'] as num?)?.toInt() ?? 0,
    );
  }
}
