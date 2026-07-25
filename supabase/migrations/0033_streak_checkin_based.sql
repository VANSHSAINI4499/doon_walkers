-- ============================================================
-- DoonWalkers — Trek Streak fix
-- Migration: 0033_streak_checkin_based.sql
--
-- get_my_streak() (0024_streaks.sql) previously treated a registration
-- as "attended" using `t.trek_date < CURRENT_DATE AND r.payment_status
-- <> 'cancelled'` — any paid, non-cancelled registration for a
-- past-dated trek counted, regardless of whether the user ever
-- actually checked in. Verified against live data: a user with a paid
-- registration and checked_in_at = NULL was credited a streak month,
-- while users who genuinely checked in (via the Phase QR-2 scan flow)
-- on the trek's own date got NO credit, because trek_date = CURRENT_DATE
-- failed the strict `<` comparison.
--
-- Fix: gate "attended" on r.checked_in_at IS NOT NULL — the only real
-- "valid completed activity" signal this schema has — instead of the
-- payment/date proxy. The trek_date < CURRENT_DATE filter is dropped
-- entirely; verified attendance already implies the trek happened.
--
-- Also replaces the two bare CURRENT_DATE references (used for the
-- "is the latest run still within grace period" check) with
-- `(now() AT TIME ZONE 'Asia/Kolkata')::date` — CURRENT_DATE evaluates
-- in the Postgres session's default timezone (UTC on Supabase), which
-- can disagree with Dehradun/IST by up to 5.5 hours right around a
-- month boundary.
--
-- The month-grouping ("islands and gaps") arithmetic itself is
-- unchanged and was verified correct independently — this migration
-- only changes which rows feed into it. Verified live: a non-checked-in
-- registration now correctly yields 0/0, and genuinely checked-in users
-- now correctly yield 1/1 (previously the reverse was true).
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
      AND r.checked_in_at IS NOT NULL
      AND t.trek_date IS NOT NULL
  ),
  numbered AS (
    SELECT attended_month, ROW_NUMBER() OVER (ORDER BY attended_month) AS rn
    FROM attended_months
  ),
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
           (date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date) - interval '1 month')::date
        THEN (SELECT lr.run_length FROM latest_run lr)::INTEGER
      ELSE 0
    END AS current_streak_months,
    COALESCE((SELECT MAX(r.run_length) FROM runs r), 0)::INTEGER AS longest_streak_months;
END;
$$;
