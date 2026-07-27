class MemberDirectoryEntry {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int totalPoints;
  final int level;
  final DateTime createdAt;

  const MemberDirectoryEntry({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.totalPoints,
    required this.level,
    required this.createdAt,
  });

  factory MemberDirectoryEntry.fromJson(Map<String, dynamic> json) {
    return MemberDirectoryEntry(
      userId: json['user_id'] as String? ?? '',
      displayName: (json['display_name'] as String?)?.isNotEmpty == true
          ? json['display_name'] as String
          : 'Doon Walker',
      avatarUrl: json['avatar_url'] as String?,
      totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
