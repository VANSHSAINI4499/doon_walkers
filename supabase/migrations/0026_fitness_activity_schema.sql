-- ============================================================
-- DoonWalkers — Version 2, Challenges Module Pivot: Fitness Activity
-- Migration: 0026_fitness_activity_schema.sql
--
-- Pivots Challenges from trek-attendance metrics to daily fitness
-- activity (steps/distance/calories/activity streaks), sourced from
-- Health Connect on Android. The 4 existing trek-based challenges and
-- their tier history were deleted directly (not by this migration —
-- see the session's DELETE statement, shown for confirmation first
-- per the destructive-change rule).
--
-- ── Why extend, not rebuild: C1's engine (challenges + challenge_tiers,
--    metric + time_window + admin-configurable tier thresholds) was
--    already metric-source-agnostic — nothing in that shape assumes
--    trek data. Only the computation layer (the RPCs) was coupled to
--    treks/registrations; this migration widens the vocabulary those
--    RPCs branch on (new enum values here; the RPCs themselves are
--    replaced in 0027).
--
-- ── New metric values (trek_count/total_distance_km are KEPT, not
--    dropped — Postgres can't cheaply remove enum values without
--    recreating the type, and nothing asked for the CAPABILITY to be
--    removed, only the 4 challenge ROWS that used it):
--      daily_steps        — sum of daily_activity_summary.steps
--      weekly_steps        \  within the challenge's time_window.
--      monthly_steps        > These three are intentionally the SAME
--      daily_distance_km   /  underlying column summed differently
--      calories_burned    —  only by which time_window the admin
--                             pairs them with (see below) — kept as
--                             separate enum values because that's the
--                             vocabulary explicitly specified, not
--                             because the computation differs.
--      active_streak_days — NOT a windowed sum. Consecutive CALENDAR
--                            DAYS with at least one active day (any
--                            daily_activity_summary row with steps >
--                            0), same one-day-grace-period shape as
--                            get_my_streak() (0024_streaks.sql) but
--                            day-granular instead of month-granular
--                            and metric-driven instead of hardcoded to
--                            trek attendance. Ignores time_window
--                            entirely — a streak is inherently "as of
--                            today," not a period sum.
--
--    Metric and time_window stay ORTHOGONAL, exactly like the
--    original trek_count/total_distance_km design: metric picks WHICH
--    column to sum, time_window picks the date range. A challenge
--    titled "50,000 Steps This Week" is metric=daily_steps (or
--    weekly_steps — either computes identically) + time_window=weekly;
--    the admin is expected to pair them sensibly, same "trust the
--    admin form" convention as tier-threshold ordering (app-level
--    guidance, not a DB constraint).
--
-- ── New time_window values: 'daily' (today only) and 'weekly'
--    (Monday-start ISO week via date_trunc('week', ...)) — needed for
--    "steps today" / "steps this week" style challenges that didn't
--    exist in the trek-only design.
--
-- ── daily_activity_summary: the new data table this whole pivot
--    depends on. Trek attendance was always derivable from data
--    Postgres already had (registrations+treks); steps/distance/
--    calories do NOT exist anywhere until a device reports them — this
--    table is what ActivitySyncService (Dart layer) upserts into after
--    reading from Health Connect (or, later, any other ActivityProvider
--    implementation — the engine only ever reads this table, never a
--    specific provider). One row per (user, calendar date).
--
--    RLS: strictly own-row read/write, NO admin override — same
--    "nobody else's business" reasoning as user_wishlist
--    (0019_user_wishlist.sql), and arguably stronger here since this
--    is raw personal health data. The leaderboard/progress RPCs still
--    read across every user's rows because they're SECURITY DEFINER,
--    exactly the same mechanism that already lets
--    get_challenge_leaderboard() rank other users' trek attendance
--    without an RLS override on registrations/treks.
-- ============================================================

ALTER TYPE challenge_metric ADD VALUE IF NOT EXISTS 'daily_steps';
ALTER TYPE challenge_metric ADD VALUE IF NOT EXISTS 'weekly_steps';
ALTER TYPE challenge_metric ADD VALUE IF NOT EXISTS 'monthly_steps';
ALTER TYPE challenge_metric ADD VALUE IF NOT EXISTS 'daily_distance_km';
ALTER TYPE challenge_metric ADD VALUE IF NOT EXISTS 'calories_burned';
ALTER TYPE challenge_metric ADD VALUE IF NOT EXISTS 'active_streak_days';

ALTER TYPE challenge_time_window ADD VALUE IF NOT EXISTS 'daily';
ALTER TYPE challenge_time_window ADD VALUE IF NOT EXISTS 'weekly';
