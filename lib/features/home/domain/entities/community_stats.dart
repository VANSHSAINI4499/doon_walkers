/// Aggregate, non-PII community numbers shown on the Home screen.
///
/// Sourced from `public.get_community_stats()` — a SECURITY DEFINER
/// function — because `public.users` RLS is own-row-or-admin only, so a
/// guest/regular user can't COUNT(*) it directly. See
/// supabase/migrations/0005_community_stats_function.sql.
class CommunityStats {
  const CommunityStats({
    required this.memberCount,
    required this.publishedTrekCount,
    required this.registrationCount,
  });

  final int memberCount;
  final int publishedTrekCount;
  final int registrationCount;

  static const zero = CommunityStats(
    memberCount: 0,
    publishedTrekCount: 0,
    registrationCount: 0,
  );

  factory CommunityStats.fromJson(Map<String, dynamic> json) {
    return CommunityStats(
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      publishedTrekCount: (json['published_trek_count'] as num?)?.toInt() ?? 0,
      registrationCount: (json['registration_count'] as num?)?.toInt() ?? 0,
    );
  }
}
