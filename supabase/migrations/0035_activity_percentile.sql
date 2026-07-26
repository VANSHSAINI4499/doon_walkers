-- ============================================================
-- DoonWalkers — Redesign 2.0, Phase 11: Activity Insights
-- Migration: 0035_activity_percentile.sql
--
-- Backs Insights' "more active than X% of Doon Walkers" line.
--
-- Why an RPC at all: daily_activity_summary is strictly own-row
-- (0027_daily_activity_summary.sql) — raw personal health data, no
-- admin override. A client cannot compare itself against anyone else,
-- and shouldn't be able to. This is SECURITY DEFINER so it reads across
-- users internally, exactly like get_community_stats() (0005) and
-- get_challenge_leaderboard() (0025), but returns ONE integer: no rows,
-- no user ids, no step counts, nothing that identifies anybody.
--
-- Cohort = users with >0 steps in the month, NOT every registered user.
-- Counting non-trackers as zero would inflate everyone's percentile
-- with every signup who never grants Health Connect, which would make
-- the number meaningless and flattering.
--
-- Returns NULL (not 0) in two cases, both meaning "cannot say":
--   * fewer than 5 people tracked that month — with a cohort of 2, a
--     percentile leaks the other person's relative standing, so this is
--     a small k-anonymity floor rather than a cosmetic guard;
--   * the caller has no data that month, so there is nothing to rank.
-- The client renders nothing at all for NULL — never "0%", which would
-- read as "you are the least active member".
--
-- NOTE at time of writing: only 4 users have any step data, so this
-- returns NULL for everyone until a 5th starts syncing. That is the
-- floor working as designed, not a fault.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_my_activity_percentile(p_month DATE)
RETURNS INTEGER
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  WITH bounds AS (
    SELECT date_trunc('month', p_month)::date AS from_date,
           (date_trunc('month', p_month) + INTERVAL '1 month')::date AS to_date
  ),
  totals AS (
    SELECT das.user_id, SUM(das.steps) AS total_steps
    FROM public.daily_activity_summary das, bounds b
    WHERE das.date >= b.from_date
      AND das.date <  b.to_date
    GROUP BY das.user_id
    HAVING SUM(das.steps) > 0
  ),
  me AS (
    SELECT total_steps FROM totals WHERE user_id = auth.uid()
  )
  SELECT CASE
    WHEN (SELECT COUNT(*) FROM totals) < 5 THEN NULL
    WHEN NOT EXISTS (SELECT 1 FROM me)     THEN NULL
    ELSE ROUND(
           100.0 * (
             SELECT COUNT(*) FROM totals
             WHERE total_steps < (SELECT total_steps FROM me)
           ) / GREATEST((SELECT COUNT(*) FROM totals) - 1, 1)
         )::INTEGER
  END;
$$;

-- Caller-specific (reads auth.uid()), so it is useless and meaningless
-- to anon — granted to authenticated only, unlike get_community_stats
-- which is deliberately guest-visible.
REVOKE ALL ON FUNCTION public.get_my_activity_percentile(DATE) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_activity_percentile(DATE) TO authenticated;
