-- ============================================================
-- DoonWalkers — Phase QR-3: Trek Attendance — Grandfathered Definition
-- Migration: 0031_trek_attendance_grandfather.sql
--
-- Replaces the pure date-based "attended" approximation (registered +
-- trek_date passed + not cancelled) with real checked_in_at data
-- (Phase QR-2), wherever attendance is computed — with a grandfather
-- rule for treks that already happened before checked_in_at could
-- possibly exist.
--
-- Two new helper functions centralise the rule in ONE place, so every
-- caller (get_my_streak, get_my_challenge_progress,
-- get_my_challenge_tier_history, get_challenge_leaderboard) applies
-- the identical definition rather than four independently-maintained
-- copies of the same predicate:
--
--   trek_checkin_feature_cutoff() — the fixed calendar date
--   (2026-07-25) migration trek_checkin_verify.sql (Phase QR-2) went
--   live — the earliest possible date checked_in_at could ever be
--   non-null. IMMUTABLE: it's a hardcoded literal, never derived from
--   system time — safe to mark IMMUTABLE, unlike the function below.
--
--   trek_registration_is_attended(trek_date, payment_status,
--   checked_in_at) — the actual rule, used identically by every
--   caller:
--     - A cancelled registration NEVER counts, regardless of
--       checked_in_at — a registration an admin voided isn't a real
--       attendance, even in the edge case where the member scanned in
--       before being cancelled.
--     - trek_date before the cutoff: old approximation (date passed).
--     - trek_date on/after the cutoff: checked_in_at IS NOT NULL, full
--       stop — a registration for a past, post-cutoff trek with no
--       scan does NOT count, even though it would have under the old
--       rule.
--   STABLE, not IMMUTABLE: it reads CURRENT_DATE, whose value can
--   differ between separate calls even though it can't change
--   mid-query — marking this IMMUTABLE would be incorrect.
--
-- Downstream logic in all four functions — streak run-length math,
-- tier-threshold math, leaderboard ranking — is completely untouched;
-- only what feeds INTO "was this trek attended" changes. The
-- daily_activity CTEs (steps/distance/calories, synced from Health
-- Connect) in get_my_challenge_progress/get_my_challenge_tier_history
-- are entirely separate from attended_treks and are not touched here.
-- ============================================================

CREATE OR REPLACE FUNCTION public.trek_checkin_feature_cutoff()
RETURNS date
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT DATE '2026-07-25';
$$;

CREATE OR REPLACE FUNCTION public.trek_registration_is_attended(
  p_trek_date date,
  p_payment_status payment_status,
  p_checked_in_at timestamptz
)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT
    p_trek_date IS NOT NULL
    AND p_payment_status <> 'cancelled'
    AND (
      (p_trek_date < public.trek_checkin_feature_cutoff() AND p_trek_date < CURRENT_DATE)
      OR (p_trek_date >= public.trek_checkin_feature_cutoff() AND p_checked_in_at IS NOT NULL)
    );
$$;

-- ── get_my_streak() (0024_streaks.sql) ───────────────────────────
CREATE OR REPLACE FUNCTION public.get_my_streak()
 RETURNS TABLE(current_streak_months integer, longest_streak_months integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
      AND public.trek_registration_is_attended(t.trek_date, r.payment_status, r.checked_in_at)
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
           (date_trunc('month', CURRENT_DATE) - interval '1 month')::date
        THEN (SELECT lr.run_length FROM latest_run lr)::INTEGER
      ELSE 0
    END AS current_streak_months,
    COALESCE((SELECT MAX(r.run_length) FROM runs r), 0)::INTEGER AS longest_streak_months;
END;
$function$;

-- ── get_my_challenge_progress() (0028_fitness_challenge_engine.sql) ─
CREATE OR REPLACE FUNCTION public.get_my_challenge_progress()
 RETURNS TABLE(challenge_id uuid, current_value numeric, current_tier challenge_tier)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH attended_treks AS (
    SELECT t.distance_km, t.trek_date AS activity_date
    FROM public.registrations r
    JOIN public.treks t ON t.id = r.trek_id
    WHERE r.user_id = v_user_id
      AND public.trek_registration_is_attended(t.trek_date, r.payment_status, r.checked_in_at)
  ),
  daily_activity AS (
    SELECT das.date AS activity_date, das.steps, das.distance_km, das.calories
    FROM public.daily_activity_summary das
    WHERE das.user_id = v_user_id
  ),
  daily_streak AS (
    SELECT COALESCE((
      WITH active_days AS (
        SELECT DISTINCT das.date AS d
        FROM public.daily_activity_summary das
        WHERE das.user_id = v_user_id AND das.steps > 0
      ),
      numbered AS (
        SELECT ad.d, ROW_NUMBER() OVER (ORDER BY ad.d) AS rn
        FROM active_days ad
      ),
      grouped AS (
        SELECT n.d, (n.d - (n.rn || ' days')::interval)::date AS island_key
        FROM numbered n
      ),
      runs AS (
        SELECT MAX(g.d) AS run_end, COUNT(*) AS run_length
        FROM grouped g
        GROUP BY g.island_key
      ),
      latest_run AS (
        SELECT r.run_length, r.run_end
        FROM runs r
        ORDER BY r.run_end DESC
        LIMIT 1
      )
      SELECT
        CASE
          WHEN NOT EXISTS (SELECT 1 FROM latest_run) THEN 0
          WHEN (SELECT lr.run_end FROM latest_run lr) >= (CURRENT_DATE - interval '1 day')::date
            THEN (SELECT lr.run_length FROM latest_run lr)
          ELSE 0
        END
    ), 0)::NUMERIC AS streak_value
  ),
  challenge_values AS (
    SELECT
      c.id AS challenge_id,
      CASE c.metric
        WHEN 'trek_count' THEN COUNT(at.activity_date)::NUMERIC
        WHEN 'total_distance_km' THEN COALESCE(SUM(at.distance_km), 0)
        WHEN 'daily_steps' THEN COALESCE(SUM(da.steps), 0)::NUMERIC
        WHEN 'weekly_steps' THEN COALESCE(SUM(da.steps), 0)::NUMERIC
        WHEN 'monthly_steps' THEN COALESCE(SUM(da.steps), 0)::NUMERIC
        WHEN 'daily_distance_km' THEN COALESCE(SUM(da.distance_km), 0)
        WHEN 'calories_burned' THEN COALESCE(SUM(da.calories), 0)
        WHEN 'active_streak_days' THEN (SELECT ds.streak_value FROM daily_streak ds)
      END AS current_value
    FROM public.challenges c
    LEFT JOIN attended_treks at ON
      c.metric IN ('trek_count', 'total_distance_km')
      AND (
        (c.time_window = 'all_time'
          AND (c.start_date IS NULL OR at.activity_date >= c.start_date)
          AND (c.end_date IS NULL OR at.activity_date <= c.end_date))
        OR (c.time_window = 'monthly'
          AND at.activity_date >= date_trunc('month', CURRENT_DATE)::date
          AND at.activity_date < (date_trunc('month', CURRENT_DATE) + interval '1 month')::date
          AND (c.start_date IS NULL OR at.activity_date >= c.start_date))
        OR (c.time_window = 'weekly'
          AND at.activity_date >= date_trunc('week', CURRENT_DATE)::date
          AND at.activity_date < (date_trunc('week', CURRENT_DATE) + interval '1 week')::date
          AND (c.start_date IS NULL OR at.activity_date >= c.start_date))
        OR (c.time_window = 'daily' AND at.activity_date = CURRENT_DATE)
        OR (c.time_window = 'custom_range'
          AND at.activity_date >= c.start_date
          AND at.activity_date <= c.end_date)
      )
    LEFT JOIN daily_activity da ON
      c.metric IN ('daily_steps', 'weekly_steps', 'monthly_steps', 'daily_distance_km', 'calories_burned')
      AND (
        (c.time_window = 'all_time'
          AND (c.start_date IS NULL OR da.activity_date >= c.start_date)
          AND (c.end_date IS NULL OR da.activity_date <= c.end_date))
        OR (c.time_window = 'monthly'
          AND da.activity_date >= date_trunc('month', CURRENT_DATE)::date
          AND da.activity_date < (date_trunc('month', CURRENT_DATE) + interval '1 month')::date
          AND (c.start_date IS NULL OR da.activity_date >= c.start_date))
        OR (c.time_window = 'weekly'
          AND da.activity_date >= date_trunc('week', CURRENT_DATE)::date
          AND da.activity_date < (date_trunc('week', CURRENT_DATE) + interval '1 week')::date
          AND (c.start_date IS NULL OR da.activity_date >= c.start_date))
        OR (c.time_window = 'daily' AND da.activity_date = CURRENT_DATE)
        OR (c.time_window = 'custom_range'
          AND da.activity_date >= c.start_date
          AND da.activity_date <= c.end_date)
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
$function$;

-- ── get_my_challenge_tier_history() (0028_fitness_challenge_engine.sql) ─
CREATE OR REPLACE FUNCTION public.get_my_challenge_tier_history()
 RETURNS TABLE(challenge_id uuid, tier challenge_tier, achieved_at date)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH attended_treks AS (
    SELECT t.distance_km, t.trek_date AS activity_date
    FROM public.registrations r
    JOIN public.treks t ON t.id = r.trek_id
    WHERE r.user_id = v_user_id
      AND public.trek_registration_is_attended(t.trek_date, r.payment_status, r.checked_in_at)
  ),
  daily_activity AS (
    SELECT das.date AS activity_date, das.steps, das.distance_km, das.calories
    FROM public.daily_activity_summary das
    WHERE das.user_id = v_user_id
  ),
  windowed AS (
    SELECT
      c.id AS challenge_id,
      at.activity_date,
      CASE c.metric
        WHEN 'trek_count' THEN 1
        WHEN 'total_distance_km' THEN at.distance_km
      END AS numeric_value
    FROM public.challenges c
    JOIN attended_treks at ON
      c.metric IN ('trek_count', 'total_distance_km')
      AND (
        (c.time_window = 'all_time'
          AND (c.start_date IS NULL OR at.activity_date >= c.start_date)
          AND (c.end_date IS NULL OR at.activity_date <= c.end_date))
        OR (c.time_window = 'monthly'
          AND at.activity_date >= date_trunc('month', CURRENT_DATE)::date
          AND at.activity_date < (date_trunc('month', CURRENT_DATE) + interval '1 month')::date
          AND (c.start_date IS NULL OR at.activity_date >= c.start_date))
        OR (c.time_window = 'weekly'
          AND at.activity_date >= date_trunc('week', CURRENT_DATE)::date
          AND at.activity_date < (date_trunc('week', CURRENT_DATE) + interval '1 week')::date
          AND (c.start_date IS NULL OR at.activity_date >= c.start_date))
        OR (c.time_window = 'daily' AND at.activity_date = CURRENT_DATE)
        OR (c.time_window = 'custom_range'
          AND at.activity_date >= c.start_date
          AND at.activity_date <= c.end_date)
      )
    WHERE c.is_active = TRUE

    UNION ALL

    SELECT
      c.id AS challenge_id,
      da.activity_date,
      CASE c.metric
        WHEN 'daily_steps' THEN da.steps
        WHEN 'weekly_steps' THEN da.steps
        WHEN 'monthly_steps' THEN da.steps
        WHEN 'daily_distance_km' THEN da.distance_km
        WHEN 'calories_burned' THEN da.calories
      END AS numeric_value
    FROM public.challenges c
    JOIN daily_activity da ON
      c.metric IN ('daily_steps', 'weekly_steps', 'monthly_steps', 'daily_distance_km', 'calories_burned')
      AND (
        (c.time_window = 'all_time'
          AND (c.start_date IS NULL OR da.activity_date >= c.start_date)
          AND (c.end_date IS NULL OR da.activity_date <= c.end_date))
        OR (c.time_window = 'monthly'
          AND da.activity_date >= date_trunc('month', CURRENT_DATE)::date
          AND da.activity_date < (date_trunc('month', CURRENT_DATE) + interval '1 month')::date
          AND (c.start_date IS NULL OR da.activity_date >= c.start_date))
        OR (c.time_window = 'weekly'
          AND da.activity_date >= date_trunc('week', CURRENT_DATE)::date
          AND da.activity_date < (date_trunc('week', CURRENT_DATE) + interval '1 week')::date
          AND (c.start_date IS NULL OR da.activity_date >= c.start_date))
        OR (c.time_window = 'daily' AND da.activity_date = CURRENT_DATE)
        OR (c.time_window = 'custom_range'
          AND da.activity_date >= c.start_date
          AND da.activity_date <= c.end_date)
      )
    WHERE c.is_active = TRUE
  ),
  running AS (
    SELECT
      w.challenge_id,
      w.activity_date,
      SUM(w.numeric_value) OVER (
        PARTITION BY w.challenge_id ORDER BY w.activity_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
      ) AS running_value
    FROM windowed w
  ),
  cumulative_tier_history AS (
    SELECT
      ct.challenge_id,
      ct.tier,
      MIN(r.activity_date) AS achieved_at
    FROM public.challenge_tiers ct
    JOIN running r
      ON r.challenge_id = ct.challenge_id
      AND r.running_value >= ct.threshold_value
    GROUP BY ct.challenge_id, ct.tier
  ),
  streak_active_days AS (
    SELECT DISTINCT das.date AS d
    FROM public.daily_activity_summary das
    WHERE das.user_id = v_user_id AND das.steps > 0
  ),
  streak_numbered AS (
    SELECT sad.d, ROW_NUMBER() OVER (ORDER BY sad.d) AS rn
    FROM streak_active_days sad
  ),
  streak_grouped AS (
    SELECT sn.d, (sn.d - (sn.rn || ' days')::interval)::date AS island_key
    FROM streak_numbered sn
  ),
  streak_length_by_day AS (
    SELECT
      sg.d,
      ROW_NUMBER() OVER (PARTITION BY sg.island_key ORDER BY sg.d) AS streak_length_here
    FROM streak_grouped sg
  ),
  streak_tier_history AS (
    SELECT
      ct.challenge_id,
      ct.tier,
      MIN(sl.d) AS achieved_at
    FROM public.challenge_tiers ct
    JOIN public.challenges c ON c.id = ct.challenge_id AND c.metric = 'active_streak_days' AND c.is_active = TRUE
    JOIN streak_length_by_day sl ON sl.streak_length_here >= ct.threshold_value
    GROUP BY ct.challenge_id, ct.tier
  )
  SELECT cth.challenge_id, cth.tier, cth.achieved_at FROM cumulative_tier_history cth
  UNION ALL
  SELECT sth.challenge_id, sth.tier, sth.achieved_at FROM streak_tier_history sth;
END;
$function$;

-- ── get_challenge_leaderboard() (0025_leaderboard.sql) ────────────
CREATE OR REPLACE FUNCTION public.get_challenge_leaderboard(p_challenge_id uuid)
 RETURNS TABLE(display_name text, rank bigint, score numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  WITH target_challenge AS (
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
    SELECT r.user_id, t.distance_km, t.trek_date AS activity_date
    FROM public.registrations r
    JOIN public.treks t ON t.id = r.trek_id
    JOIN eligible_users eu ON eu.id = r.user_id
    WHERE public.trek_registration_is_attended(t.trek_date, r.payment_status, r.checked_in_at)
  ),
  daily_activity AS (
    SELECT das.user_id, das.date AS activity_date, das.steps, das.distance_km, das.calories
    FROM public.daily_activity_summary das
    JOIN eligible_users eu ON eu.id = das.user_id
  ),
  windowed AS (
    SELECT
      a.user_id,
      CASE (SELECT tc.metric FROM target_challenge tc)
        WHEN 'trek_count' THEN 1
        WHEN 'total_distance_km' THEN a.distance_km
      END AS numeric_value
    FROM attended a
    WHERE (SELECT tc.metric FROM target_challenge tc) IN ('trek_count', 'total_distance_km')
      AND EXISTS (
        SELECT 1 FROM target_challenge tc
        WHERE
          (tc.time_window = 'all_time'
            AND (tc.start_date IS NULL OR a.activity_date >= tc.start_date)
            AND (tc.end_date IS NULL OR a.activity_date <= tc.end_date))
          OR (tc.time_window = 'monthly'
            AND a.activity_date >= date_trunc('month', CURRENT_DATE)::date
            AND a.activity_date < (date_trunc('month', CURRENT_DATE) + interval '1 month')::date
            AND (tc.start_date IS NULL OR a.activity_date >= tc.start_date))
          OR (tc.time_window = 'weekly'
            AND a.activity_date >= date_trunc('week', CURRENT_DATE)::date
            AND a.activity_date < (date_trunc('week', CURRENT_DATE) + interval '1 week')::date
            AND (tc.start_date IS NULL OR a.activity_date >= tc.start_date))
          OR (tc.time_window = 'daily' AND a.activity_date = CURRENT_DATE)
          OR (tc.time_window = 'custom_range'
            AND a.activity_date >= tc.start_date
            AND a.activity_date <= tc.end_date)
      )

    UNION ALL

    SELECT
      da.user_id,
      CASE (SELECT tc.metric FROM target_challenge tc)
        WHEN 'daily_steps' THEN da.steps
        WHEN 'weekly_steps' THEN da.steps
        WHEN 'monthly_steps' THEN da.steps
        WHEN 'daily_distance_km' THEN da.distance_km
        WHEN 'calories_burned' THEN da.calories
      END AS numeric_value
    FROM daily_activity da
    WHERE (SELECT tc.metric FROM target_challenge tc)
        IN ('daily_steps', 'weekly_steps', 'monthly_steps', 'daily_distance_km', 'calories_burned')
      AND EXISTS (
        SELECT 1 FROM target_challenge tc
        WHERE
          (tc.time_window = 'all_time'
            AND (tc.start_date IS NULL OR da.activity_date >= tc.start_date)
            AND (tc.end_date IS NULL OR da.activity_date <= tc.end_date))
          OR (tc.time_window = 'monthly'
            AND da.activity_date >= date_trunc('month', CURRENT_DATE)::date
            AND da.activity_date < (date_trunc('month', CURRENT_DATE) + interval '1 month')::date
            AND (tc.start_date IS NULL OR da.activity_date >= tc.start_date))
          OR (tc.time_window = 'weekly'
            AND da.activity_date >= date_trunc('week', CURRENT_DATE)::date
            AND da.activity_date < (date_trunc('week', CURRENT_DATE) + interval '1 week')::date
            AND (tc.start_date IS NULL OR da.activity_date >= tc.start_date))
          OR (tc.time_window = 'daily' AND da.activity_date = CURRENT_DATE)
          OR (tc.time_window = 'custom_range'
            AND da.activity_date >= tc.start_date
            AND da.activity_date <= tc.end_date)
      )
  ),
  cumulative_scores AS (
    SELECT eu.id AS user_id, eu.name, COALESCE(SUM(w.numeric_value), 0) AS score
    FROM eligible_users eu
    LEFT JOIN windowed w ON w.user_id = eu.id
    GROUP BY eu.id, eu.name
  ),
  streak_active_days AS (
    SELECT das.user_id, das.date AS d
    FROM public.daily_activity_summary das
    JOIN eligible_users eu ON eu.id = das.user_id
    WHERE das.steps > 0
  ),
  streak_numbered AS (
    SELECT sad.user_id, sad.d, ROW_NUMBER() OVER (PARTITION BY sad.user_id ORDER BY sad.d) AS rn
    FROM streak_active_days sad
  ),
  streak_grouped AS (
    SELECT sn.user_id, sn.d, (sn.d - (sn.rn || ' days')::interval)::date AS island_key
    FROM streak_numbered sn
  ),
  streak_runs AS (
    SELECT sg.user_id, sg.island_key, MAX(sg.d) AS run_end, COUNT(*) AS run_length
    FROM streak_grouped sg
    GROUP BY sg.user_id, sg.island_key
  ),
  streak_latest_run AS (
    SELECT DISTINCT ON (sr.user_id) sr.user_id, sr.run_length, sr.run_end
    FROM streak_runs sr
    ORDER BY sr.user_id, sr.run_end DESC
  ),
  streak_scores AS (
    SELECT
      eu.id AS user_id,
      eu.name,
      COALESCE((
        SELECT CASE WHEN slr.run_end >= (CURRENT_DATE - interval '1 day')::date THEN slr.run_length ELSE 0 END
        FROM streak_latest_run slr
        WHERE slr.user_id = eu.id
      ), 0)::NUMERIC AS score
    FROM eligible_users eu
  ),
  combined AS (
    SELECT cs.name, cs.score
    FROM cumulative_scores cs
    WHERE (SELECT tc.metric FROM target_challenge tc)
      IN ('trek_count', 'total_distance_km', 'daily_steps', 'weekly_steps', 'monthly_steps', 'daily_distance_km', 'calories_burned')

    UNION ALL

    SELECT ss.name, ss.score
    FROM streak_scores ss
    WHERE (SELECT tc.metric FROM target_challenge tc) = 'active_streak_days'
  )
  SELECT co.name, RANK() OVER (ORDER BY co.score DESC) AS rank, co.score
  FROM combined co
  WHERE co.score > 0
  ORDER BY rank, co.name
  LIMIT 50;
END;
$function$;
