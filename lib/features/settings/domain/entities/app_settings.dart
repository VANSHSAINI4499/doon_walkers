/// Typed view over the key/value rows in `public.settings`.
///
/// Backed by a raw map rather than fixed columns because `settings` is a
/// key/value table by design (see AGENTS.md "SCALABILITY" — portable to
/// other trekking communities without a schema rewrite). Named getters
/// give call sites compile-time-checked access to the keys this app
/// currently knows about; [raw] is there for anything seeded later that
/// doesn't have a getter yet.
///
/// Missing keys resolve to `''` rather than throwing — a row deleted or
/// renamed via the Supabase dashboard should degrade the UI, not crash it.
class AppSettings {
  const AppSettings(this.raw);

  /// All rows as key -> value. Prefer the named getters below; this is
  /// an escape hatch for keys without one.
  final Map<String, String> raw;

  static const empty = AppSettings({});

  factory AppSettings.fromRows(List<Map<String, dynamic>> rows) {
    final map = <String, String>{};
    for (final row in rows) {
      final key = row['key'] as String?;
      if (key == null) continue;
      map[key] = (row['value'] as String?) ?? '';
    }
    return AppSettings(map);
  }

  String _get(String key) => raw[key] ?? '';

  // ── Organisation (seeded in 0001) ──────────────────────────────────
  String get orgName => _get('org_name');
  String get orgTagline => _get('org_tagline');
  String get orgCity => _get('org_city');
  String get orgState => _get('org_state');
  String get contactEmail => _get('contact_email');
  String get contactPhone => _get('contact_phone');
  String get instagramUrl => _get('instagram_url');
  String get whatsappUrl => _get('whatsapp_url');
  String get googleFormUrl => _get('google_form_url');

  // ── About page content (seeded in 0004) ────────────────────────────
  String get communityStory => _get('community_story');
  String get founderMessage => _get('founder_message');
  String get vision => _get('vision');
  String get mission => _get('mission');
  String get communityRules => _get('community_rules');
  String get whyJoin => _get('why_join');
}
