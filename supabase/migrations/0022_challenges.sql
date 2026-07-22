-- ============================================================
-- DoonWalkers — Version 2, Phase C1: Challenges Schema & Progress Engine
-- Migration: 0022_challenges.sql
--
-- Data layer + admin tooling only — no user-facing tab this phase
-- (that's C2). The system must be genuinely generic: adding a new
-- challenge (any title/metric/window/thresholds) is new ROWS, never
-- new app code — nothing here or in the Dart layer ever references a
-- specific challenge by name.
--
-- ── Two metrics only (elevation-gain explicitly deferred — treks only
--    track max altitude, not real elevation gain, which isn't the
--    same thing):
--      total_distance_km — SUM(treks.distance_km) over attended treks
--      trek_count        — COUNT(*) over attended treks
--
-- ── "Attended" reuses the EXACT definition already established for
--    Profile's stats (RegistrationStats.fromRegistrations /
--    isTrekDateBefore), not a second one:
--      registrations.payment_status <> 'cancelled'
--      AND treks.trek_date IS NOT NULL
--      AND treks.trek_date < CURRENT_DATE   (strictly before "today",
--        matching isTrekDateBefore's day-level comparison — today
--        itself is "upcoming", not "attended")
--
-- ── Progress is computed ON DEMAND (get_my_challenge_progress()
--    below), not stored in a maintained table kept in sync by
--    triggers. Deliberate: a maintained/cached progress table is
--    faster to read at very large scale, but requires triggers on
--    registrations AND treks (a trek's distance_km or trek_date can
--    change after the fact, same as attendance itself being entirely
--    date-driven rather than admin-marked) to avoid exactly the kind
--    of "derived data drifted from its source" bug class this project
--    has hit before with denormalized fields. At this project's real
--    scale (a few dozen treks, a small membership), computing live
--    over a two-table join is trivial; if Challenges ever needs to
--    serve a leaderboard across hundreds of members at high frequency
--    (C3?), that's the point to revisit and introduce a maintained
--    table with real trigger-based invalidation — not preemptively
--    now.
--
-- ── Time window filtering restricts which treks COUNT, not just what
--    the UI displays:
--      all_time:     no restriction beyond challenges.start_date/
--                     end_date if either is set.
--      monthly:      only treks whose trek_date falls in the CURRENT
--                     calendar month (recomputed relative to today on
--                     every call — there's no stored "which month" is
--                     current). challenges.start_date, if set, still
--                     applies on top — this is what "anchors a
--                     monthly challenge's first eligible month": if
--                     today's month is before start_date, the
--                     intersection is empty and progress is 0, so a
--                     monthly challenge created partway through a
--                     month/year never credits activity from before
--                     it existed.
--      custom_range:  only treks within [start_date, end_date],
--                     both expected set (enforced by the CHECK below).
--    start_date/end_date are applied uniformly across all three
--    window types (see the get_my_challenge_progress query) rather
--    than being custom_range-only special cases — one filtering rule,
--    not three.
-- ============================================================

DO $$ BEGIN
  CREATE TYPE challenge_metric AS ENUM ('total_distance_km', 'trek_count');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE challenge_time_window AS ENUM ('all_time', 'monthly', 'custom_range');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE challenge_tier AS ENUM ('bronze', 'silver', 'gold', 'platinum');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;


-- ════════════════════════════════════════════════════════════════
-- TABLE: challenges
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.challenges (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title         TEXT NOT NULL,
  description   TEXT NOT NULL DEFAULT '',
  metric        challenge_metric NOT NULL,
  time_window   challenge_time_window NOT NULL DEFAULT 'all_time',
  start_date    DATE,
  end_date      DATE,
  -- Free-form identifier string, e.g. 'hiking' / 'terrain' / 'trophy'
  -- — the Dart layer maps a small known vocabulary of these to
  -- Material icons (see ChallengeIcon). Deliberately TEXT rather than
  -- an image upload: C1 needs no new Storage bucket for a tab that
  -- doesn't render until C2, and this column can just as easily hold
  -- a future image URL instead without a schema change if C2 wants
  -- richer art.
  icon          TEXT,
  -- Defaults FALSE, same "draft until explicitly published" contract
  -- as treks.is_published / products.is_active — an admin can set up
  -- a challenge's tiers before it's visible to anyone else.
  is_active     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CHECK (time_window <> 'custom_range' OR (start_date IS NOT NULL AND end_date IS NOT NULL)),
  CHECK (start_date IS NULL OR end_date IS NULL OR end_date >= start_date)
);

ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;

-- Mirrors treks_select exactly: active challenges are public (no
-- sign-in required to browse — this is what C2's tab will read from),
-- draft ones are admin-only.
CREATE POLICY "challenges_select" ON public.challenges
  FOR SELECT
  USING (is_active = TRUE OR public.is_admin());

CREATE POLICY "challenges_insert_admin" ON public.challenges
  FOR INSERT
  WITH CHECK (public.is_admin());

CREATE POLICY "challenges_update_admin" ON public.challenges
  FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "challenges_delete_admin" ON public.challenges
  FOR DELETE
  USING (public.is_admin());


-- ════════════════════════════════════════════════════════════════
-- TABLE: challenge_tiers
-- Exactly one row per (challenge, tier) — all 4 tiers are set
-- together by the admin form, not added/removed individually the way
-- product sizes are (a challenge always has all 4, never a subset).
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.challenge_tiers (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  challenge_id      UUID NOT NULL REFERENCES public.challenges(id) ON DELETE CASCADE,
  tier              challenge_tier NOT NULL,
  threshold_value   NUMERIC(10, 2) NOT NULL CHECK (threshold_value > 0),
  UNIQUE (challenge_id, tier)
);

ALTER TABLE public.challenge_tiers ENABLE ROW LEVEL SECURITY;

-- Joined through the parent challenge's is_active, same shape as
-- product_variants_select / gallery_select_publish_gate.
CREATE POLICY "challenge_tiers_select" ON public.challenge_tiers
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.challenges c
      WHERE c.id = challenge_tiers.challenge_id
      AND (c.is_active = TRUE OR public.is_admin())
    )
  );

CREATE POLICY "challenge_tiers_insert_admin" ON public.challenge_tiers
  FOR INSERT
  WITH CHECK (public.is_admin());

CREATE POLICY "challenge_tiers_update_admin" ON public.challenge_tiers
  FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "challenge_tiers_delete_admin" ON public.challenge_tiers
  FOR DELETE
  USING (public.is_admin());


-- ════════════════════════════════════════════════════════════════
-- FUNCTION: get_my_challenge_progress()
-- Returns the CALLING user's current value + tier for every active
-- challenge, computed live from registrations/treks. auth.uid() is
-- read internally — there is deliberately no user_id parameter, so
-- there is no way to call this for anyone but yourself; this is the
-- entire security model for this function, not an RLS policy (a
-- function's own body isn't subject to table RLS the normal way,
-- which is exactly why it must not accept a caller-supplied id).
--
-- SECURITY DEFINER (like public.is_admin(), same file/pattern as
-- 0002_role_policies.sql) so a trek's current is_published state (or
-- a registration somehow existing without matching RLS elsewhere)
-- can never cause a real attended trek to silently vanish from a
-- user's own progress — this reads the ground truth for the caller's
-- own data, not whatever RLS happens to currently expose to them.
-- Still perfectly safe: v_user_id is hardcoded to auth.uid(), so a
-- caller can only ever see this computed for themselves.
-- ════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.get_my_challenge_progress()
RETURNS TABLE (
  challenge_id    UUID,
  current_value   NUMERIC,
  current_tier    challenge_tier
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN; -- guest/unauthenticated caller: no rows, not an error
  END IF;

  RETURN QUERY
  WITH attended_treks AS (
    SELECT t.distance_km, t.trek_date
    FROM public.registrations r
    JOIN public.treks t ON t.id = r.trek_id
    WHERE r.user_id = v_user_id
      AND r.payment_status <> 'cancelled'
      AND t.trek_date IS NOT NULL
      AND t.trek_date < CURRENT_DATE
  ),
  -- Computed once per challenge here, then looked up against
  -- challenge_tiers below — deliberately NOT re-derived inside a
  -- correlated subquery per tier-lookup row, which would mean
  -- re-aggregating attended_treks (and re-evaluating the CASE) once
  -- per candidate tier row instead of once per challenge.
  challenge_values AS (
    SELECT
      c.id AS challenge_id,
      CASE c.metric
        WHEN 'trek_count' THEN COUNT(at.trek_date)::NUMERIC
        WHEN 'total_distance_km' THEN COALESCE(SUM(at.distance_km), 0)
      END AS current_value
    FROM public.challenges c
    LEFT JOIN attended_treks at ON (
      (c.time_window = 'all_time'
        AND (c.start_date IS NULL OR at.trek_date >= c.start_date)
        AND (c.end_date IS NULL OR at.trek_date <= c.end_date))
      OR (c.time_window = 'monthly'
        AND at.trek_date >= date_trunc('month', CURRENT_DATE)::date
        AND at.trek_date < (date_trunc('month', CURRENT_DATE) + interval '1 month')::date
        AND (c.start_date IS NULL OR at.trek_date >= c.start_date))
      OR (c.time_window = 'custom_range'
        AND at.trek_date >= c.start_date
        AND at.trek_date <= c.end_date)
    )
    WHERE c.is_active = TRUE
    GROUP BY c.id, c.metric
  )
  SELECT
    cv.challenge_id,
    cv.current_value,
    (
      SELECT ct.tier
      FROM public.challenge_tiers ct
      WHERE ct.challenge_id = cv.challenge_id
        AND ct.threshold_value <= cv.current_value
      ORDER BY ct.threshold_value DESC
      LIMIT 1
    ) AS current_tier
  FROM challenge_values cv;
END;
$$;
