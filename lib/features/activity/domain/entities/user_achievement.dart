/// Entity representing an unlocked achievement for the signed-in user,
/// joining `user_achievements` and `achievement_definitions`.
class UserAchievement {
  final String id;
  final String key;
  final String title;
  final String description;
  final String iconAsset;
  final String unlockMetric;
  final int unlockValue;
  final int pointsReward;
  final DateTime unlockedAt;

  const UserAchievement({
    required this.id,
    required this.key,
    required this.title,
    required this.description,
    required this.iconAsset,
    required this.unlockMetric,
    required this.unlockValue,
    required this.pointsReward,
    required this.unlockedAt,
  });

  factory UserAchievement.fromJson(Map<String, dynamic> json) {
    final def = json['achievement_definitions'] as Map<String, dynamic>? ?? json;
    return UserAchievement(
      id: json['id'] as String? ?? '',
      key: def['key'] as String? ?? '',
      title: def['title'] as String? ?? '',
      description: def['description'] as String? ?? '',
      iconAsset: def['icon_asset'] as String? ?? '',
      unlockMetric: def['unlock_metric'] as String? ?? '',
      unlockValue: (def['unlock_value'] as num?)?.toInt() ?? 0,
      pointsReward: (def['points_reward'] as num?)?.toInt() ?? 0,
      unlockedAt: json['unlocked_at'] != null
          ? DateTime.parse(json['unlocked_at'] as String)
          : DateTime.now(),
    );
  }
}
