/// One row from `points_ledger` (0036_phase19_schema_foundations.sql) —
/// an append-only, signed entry in the caller's points history.
class PointsLedgerEntry {
  const PointsLedgerEntry({
    required this.id,
    required this.points,
    required this.reason,
    required this.referenceId,
    required this.createdAt,
  });

  final String id;

  /// Signed — positive for an award, negative for a deduction (none exist
  /// yet, but the column allows it and the UI renders the sign either way).
  final int points;

  /// The machine reason string as stored (e.g. `'challenge_enrolled'`) —
  /// map this through [PointsReasonLabels] before showing it, never raw.
  final String reason;

  final String? referenceId;
  final DateTime createdAt;

  factory PointsLedgerEntry.fromJson(Map<String, dynamic> json) {
    return PointsLedgerEntry(
      id: json['id'] as String,
      points: (json['points'] as num).toInt(),
      reason: json['reason'] as String,
      referenceId: json['reference_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
