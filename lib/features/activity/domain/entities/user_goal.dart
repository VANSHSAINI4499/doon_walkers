/// Entity for a user's personal step target (daily or monthly).
class UserGoal {
  final String id;
  final String userId;
  final String goalType; // 'daily_steps' | 'monthly_steps'
  final int targetValue;
  final DateTime updatedAt;

  const UserGoal({
    required this.id,
    required this.userId,
    required this.goalType,
    required this.targetValue,
    required this.updatedAt,
  });

  factory UserGoal.fromJson(Map<String, dynamic> json) {
    return UserGoal(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      goalType: json['goal_type'] as String,
      targetValue: (json['target_value'] as num).toInt(),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
