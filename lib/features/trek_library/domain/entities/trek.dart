/// Maps 1-to-1 with the `trek_difficulty` enum in Postgres
/// (`easy`, `moderate`, `hard`, `extreme`) — see 0001_baseline_schema.sql.
enum TrekDifficulty {
  easy,
  moderate,
  hard,
  extreme;

  /// Matches the Dart enum's identifier name exactly to the Postgres
  /// enum value — deliberately kept 1:1 so `.name` round-trips safely.
  static TrekDifficulty fromString(String? value) {
    return TrekDifficulty.values.firstWhere(
      (d) => d.name == value,
      orElse: () => TrekDifficulty.moderate, // matches the DB column default
    );
  }

  String toDbString() => name;

  String get label => switch (this) {
    TrekDifficulty.easy => 'Easy',
    TrekDifficulty.moderate => 'Moderate',
    TrekDifficulty.hard => 'Hard',
    TrekDifficulty.extreme => 'Extreme',
  };
}

/// Core domain representation of a row in `public.treks`.
class Trek {
  final String id;
  final String title;
  final String description;
  final TrekDifficulty difficulty;
  final double? distanceKm;
  final int? durationDays;
  final int? altitudeM;
  final String? bestSeason;
  final String? thingsToCarry;
  final String? googleMapLink;
  final String? coverImage;
  final bool isPublished;
  final DateTime createdAt;

  /// Scheduled start date (0010_trek_scheduling.sql). Nullable — unset
  /// for treks created before this column existed, until an admin edits
  /// them. Callers must handle null rather than assume every trek has
  /// one; see [isUpcoming] for the "unscheduled" case's meaning.
  final DateTime? trekDate;

  /// Amount a member must pay to register (0011_payment_verification.sql).
  /// 0 means free — callers should skip payment UI entirely rather than
  /// show a fee section for ₹0.
  final double registrationFee;

  /// Public URL of the admin-uploaded QR code image, in the same public
  /// `trek-covers` bucket [coverImage] lives in — a QR code is meant to
  /// be publicly scannable, unlike the member's payment screenshot
  /// (which lives in the private `payment-proofs` bucket instead; see
  /// Registration.paymentScreenshotUrl). Null when [registrationFee] is 0.
  final String? paymentQrCode;

  const Trek({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    this.distanceKm,
    this.durationDays,
    this.altitudeM,
    this.bestSeason,
    this.thingsToCarry,
    this.googleMapLink,
    this.coverImage,
    required this.isPublished,
    required this.createdAt,
    this.trekDate,
    this.registrationFee = 0,
    this.paymentQrCode,
  });

  /// True when registering for this trek requires payment.
  bool get requiresPayment => registrationFee > 0;

  /// True when [trekDate] is today or in the future. False both for a
  /// past date AND for no date at all — an unscheduled trek is neither
  /// "upcoming" nor "completed", it's simply unscheduled (see
  /// [isCompleted] and the sort/grouping notes in trek_library_screen.dart).
  bool get isUpcoming {
    final date = trekDate;
    if (date == null) return false;
    return !isTrekDateBefore(date, DateTime.now());
  }

  /// True when [trekDate] is set and in the past.
  bool get isCompleted {
    final date = trekDate;
    if (date == null) return false;
    return isTrekDateBefore(date, DateTime.now());
  }
}

/// Compares [trekDate] against [now] by calendar day, ignoring time of
/// day — `trek_date` is a Postgres `date` with no time component, so
/// comparing raw `DateTime`s (which carry a time) would misclassify a
/// trek scheduled for "today" as already past once the clock ticks
/// forward. Shared here since both [Trek.isUpcoming]/[Trek.isCompleted]
/// and the registrations feature's "attended" logic (Part D) need the
/// same day-level comparison against a joined trek's date.
bool isTrekDateBefore(DateTime trekDate, DateTime now) {
  final trekDay = DateTime(trekDate.year, trekDate.month, trekDate.day);
  final today = DateTime(now.year, now.month, now.day);
  return trekDay.isBefore(today);
}

/// Sorts treks for the library grid, fully automatic from [Trek.trekDate]
/// — there is deliberately no manual "upcoming/completed" toggle, since
/// an admin will be backfilling ~35 historical treks with real past
/// dates over time and this must keep sorting itself correctly as that
/// happens:
///   - Upcoming treks first, nearest date first (ascending).
///   - Completed treks next, most recently completed first (descending)
///     — older treks sink further down.
///   - Unscheduled treks (no [Trek.trekDate] at all — existing rows from
///     before trek scheduling existed) last, in whatever order they
///     arrived in.
///
/// A three-way partition rather than one [Comparator], because the
/// upcoming and completed groups sort the same field in opposite
/// directions — a single comparator would need the identical branching
/// anyway, just harder to unit-test in isolation.
///
/// Sorts client-side rather than pushing the three-way order into SQL:
/// at the ~35-trek scale this project runs at (every trek is fetched in
/// one unpaginated query already), an O(n log n) sort in Dart is free.
/// If the library ever grows into the hundreds and gets paginated, this
/// would need to move server-side — not a concern at today's scale.
List<Trek> sortTreksForLibrary(List<Trek> treks) {
  final upcoming = treks.where((t) => t.isUpcoming).toList()
    ..sort((a, b) => a.trekDate!.compareTo(b.trekDate!));
  final completed = treks.where((t) => t.isCompleted).toList()
    ..sort((a, b) => b.trekDate!.compareTo(a.trekDate!));
  final unscheduled = treks.where((t) => t.trekDate == null).toList();
  return [...upcoming, ...completed, ...unscheduled];
}
