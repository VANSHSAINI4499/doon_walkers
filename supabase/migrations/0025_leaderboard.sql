-- ============================================================
-- DoonWalkers — Version 2, Phase C3: Streaks & Leaderboard
-- Migration: 0025_leaderboard.sql
--
-- ── Scope decision: PER-CHALLENGE leaderboard only, not an "overall"
--    cross-challenge one. C1's two metrics (trek_count,
--    total_distance_km) have different units/scales, so combining
--    scores across challenges into one ranking would need an invented
--    weighting scheme with no natural justification — a real design
--    cost for a feature nobody asked for yet. Per-challenge ranks
--    users on exactly the number already being measured for that
--    challenge, which is both simpler and matches how C1's schema is
--    already shaped (one challenge, one metric, one set of thresholds).
--
-- ── Privacy: mirrors get_community_stats()'s aggregate-only pattern
--    (Phase 3) — the RPC below returns ONLY display_name/rank/score,
--    never a user id, email, phone, or any other column, and is
--    SECURITY DEFINER purely so it CAN read every eligible user's
--    registrations (impossible under normal per-row RLS, which only
--    ever exposes a caller's own registrations) while the function's
--    own fixed return shape is the actual privacy boundary — same
--    reasoning as get_my_challenge_progress() being SECURITY DEFINER
--    for the opposite reason (own data despite RLS gaps).
--
--    show_on_leaderboard is enforced INSIDE this function (the
--    eligible_users CTE below), not just filtered client-side — an
--    opted-out user is a row this function never computes a score
--    for, so there's nothing for a client to accidentally still
--    display even if it ignored the flag.
-- ============================================================

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS show_on_leaderboard BOOLEAN NOT NULL DEFAULT TRUE;

-- Self-editable via the EXISTING users_update_own_or_admin policy
-- (auth.uid() = id OR is_admin()) — no new RLS policy needed, this is
-- exactly the same "own profile preference" shape as name/phone, and
-- (unlike email — see prevent_email_self_edit() in
-- 0003_field_level_guards.sql) there's no reason to ever restrict this
-- one to admin-only: it's the user's own privacy choice, nobody
-- else's business to set for them.

CREATE OR REPLACE FUNCTION public.get_challenge_leaderboard(p_challenge_id UUID)
RETURNS TABLE (
  display_name  TEXT,
  rank          BIGINT,
  score         NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
  RETURN QUERY
  WITH target_challenge AS (
    -- is_active = TRUE here (not just relying on the caller only ever
    -- knowing active challenge ids): a guest CAN legally reach this
    -- function with an arbitrary UUID, so a draft challenge's
    -- existence must not be inferable from a non-empty result either.
    SELECT c.id, c.metric, c.time_window, c.start_date, c.end_date
    FROM public.challenges c
    WHERE c.id = p_challenge_id AND c.is_active = TRUE
  ),
  eligible_users AS (
    SELECT u.id, u.name
    FROM public.users u
    WHERE u.show_on_leaderboard = TRUE
  ),
  attended AS (
    SELECT r.user_id, t.distance_km, t.trek_date
    FROM public.registrations r
    JOIN public.treks t ON t.id = r.trek_id
    JOIN eligible_users eu ON eu.id = r.user_id
    WHERE r.payment_status <> 'cancelled'
      AND t.trek_date IS NOT NULL
      AND t.trek_date < CURRENT_DATE
  ),
  -- Same time-window filtering rule as get_my_challenge_progress()
  -- (0022_challenges.sql) — deliberately kept identical so a
  -- challenge's leaderboard always ranks by the exact same value its
  -- own progress bar shows.
  windowed AS (
    SELECT a.user_id, a.trek_date, a.distance_km
    FROM attended a
    CROSS JOIN target_challenge tc
    WHERE (tc.time_window = 'all_time'
        AND (tc.start_date IS NULL OR a.trek_date >= tc.start_date)
        AND (tc.end_date IS NULL OR a.trek_date <= tc.end_date))
      OR (tc.time_window = 'monthly'
        AND a.trek_date >= date_trunc('month', CURRENT_DATE)::date
        AND a.trek_date < (date_trunc('month', CURRENT_DATE) + interval '1 month')::date
        AND (tc.start_date IS NULL OR a.trek_date >= tc.start_date))
      OR (tc.time_window = 'custom_range'
        AND a.trek_date >= tc.start_date
        AND a.trek_date <= tc.end_date)
  ),
  scores AS (
    SELECT
      eu.id AS user_id,
      eu.name,
      COALESCE(
        CASE (SELECT tc.metric FROM target_challenge tc)
          WHEN 'trek_count' THEN COUNT(w.trek_date)
          WHEN 'total_distance_km' THEN SUM(w.distance_km)
        END,
        0
      ) AS score
    FROM eligible_users eu
    LEFT JOIN windowed w ON w.user_id = eu.id
    GROUP BY eu.id, eu.name
  )
  -- Zero-score users are excluded rather than shown tied at the
  -- bottom — a leaderboard is meant to reflect real progress, and
  -- surfacing every opted-in member (most of whom may never have
  -- attended a trek toward this specific challenge) would dilute it
  -- into a membership list rather than a ranking. LIMIT 50 is a
  -- sensible bound for this project's real scale, not a hit
  -- constraint being planned around.
  SELECT s.name, RANK() OVER (ORDER BY s.score DESC) AS rank, s.score
  FROM scores s
  WHERE s.score > 0
  ORDER BY rank, s.name
  LIMIT 50;
END;
$$;
