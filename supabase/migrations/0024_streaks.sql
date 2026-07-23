-- ============================================================
-- DoonWalkers — Version 2, Phase C3: Streaks & Leaderboard
-- Migration: 0024_streaks.sql
--
-- ── Streak definition (a concrete choice, not left implicit):
--    a streak is measured in CONSECUTIVE CALENDAR MONTHS with at
--    least one attended trek — same "attended" definition as
--    everywhere else in this project (payment_status <> 'cancelled'
--    AND trek_date < CURRENT_DATE). A calendar month with zero
--    attended treks breaks it.
--
--    "Current streak" has a one-month GRACE PERIOD: if the most
--    recent run of consecutive attended months ends at THIS month or
--    LAST month, it still counts as the active current streak — the
--    current month isn't over yet, so having no attended trek in it
--    SO FAR doesn't retroactively kill a streak that was alive last
--    month. If the most recent run ends any earlier than that, the
--    streak is broken (current = 0), even though "longest ever" still
--    remembers it.
--
--    Alternative definitions considered and rejected: (a) no grace
--    period (this month must already have an attended trek, or the
--    streak reads 0 even on day 1 of a new month) — rejected as overly
--    punishing given trips are typically planned/attended later in a
--    month; (b) per-trek/rolling-30-day windows instead of calendar
--    months — rejected as needlessly complex for a "how consistently
--    do you trek" signal, and calendar-month is what most people
--    intuitively mean by "streak" in this context anyway.
--
-- ── Computed live (get_my_streak() below), not a maintained counter —
--    same reasoning as get_my_challenge_progress() (0022_challenges.sql):
--    nothing to keep in sync via triggers, trivial at this project's
--    real scale. Not tied to the challenges/challenge_tiers tables at
--    all — this is a general attendance-consistency stat (a sibling of
--    LoyaltyBadge), not scoped to any one challenge.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_my_streak()
RETURNS TABLE (
  current_streak_months  INTEGER,
  longest_streak_months  INTEGER
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
    RETURN;
  END IF;

  RETURN QUERY
  WITH attended_months AS (
    SELECT DISTINCT date_trunc('month', t.trek_date)::date AS attended_month
    FROM public.registrations r
    JOIN public.treks t ON t.id = r.trek_id
    WHERE r.user_id = v_user_id
      AND r.payment_status <> 'cancelled'
      AND t.trek_date IS NOT NULL
      AND t.trek_date < CURRENT_DATE
  ),
  numbered AS (
    SELECT attended_month, ROW_NUMBER() OVER (ORDER BY attended_month) AS rn
    FROM attended_months
  ),
  -- Classic gaps-and-islands grouping: subtracting a run-local,
  -- ever-increasing offset (rn months) from each date collapses every
  -- month in a CONSECUTIVE run to the same constant `island_key`,
  -- while any gap shifts it — so GROUP BY island_key below isolates
  -- each unbroken run.
  grouped AS (
    SELECT attended_month, (attended_month - (rn || ' months')::interval)::date AS island_key
    FROM numbered
  ),
  runs AS (
    SELECT MIN(attended_month) AS run_start, MAX(attended_month) AS run_end, COUNT(*) AS run_length
    FROM grouped
    GROUP BY island_key
  ),
  latest_run AS (
    SELECT run_length, run_end
    FROM runs
    ORDER BY run_end DESC
    LIMIT 1
  )
  SELECT
    CASE
      WHEN NOT EXISTS (SELECT 1 FROM latest_run) THEN 0
      WHEN (SELECT lr.run_end FROM latest_run lr) >=
           (date_trunc('month', CURRENT_DATE) - interval '1 month')::date
        THEN (SELECT lr.run_length FROM latest_run lr)::INTEGER
      ELSE 0
    END AS current_streak_months,
    COALESCE((SELECT MAX(r.run_length) FROM runs r), 0)::INTEGER AS longest_streak_months;
END;
$$;
