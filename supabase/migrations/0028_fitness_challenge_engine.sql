-- ============================================================
-- DoonWalkers — Version 2, Challenges Module Pivot: Fitness Activity
-- Migration: 0028_fitness_challenge_engine.sql
--
-- Replaces get_my_challenge_progress(), get_my_challenge_tier_history()
-- and get_challenge_leaderboard() to compute over BOTH the original
-- trek-attendance metrics (kept, unused for now but not removed — see
-- 0026's doc) and the new daily_activity_summary-sourced fitness
-- metrics, with a genuinely new computation shape for
-- active_streak_days (day-granular consecutive-active-days, not a
-- windowed sum).
--
-- Every bare column reference below is qualified to a CTE/table alias
-- — the earlier tier-history RPC (0023) hit a real bug (ERROR 42702)
-- from an unqualified reference colliding with this function's own
-- RETURNS TABLE parameter names; every query here was written qualified
-- from the start for exactly that reason.
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- get_my_challenge_progress()
-- ────────────────────────────────────────────────────────────
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
    RETURN;
  END IF;

  RETURN QUERY
  WITH attended_treks AS (
    SELECT t.distance_km, t.trek_date AS activity_date
    FROM public.registrations r
    JOIN public.treks t ON t.id = r.trek_id
    WHERE r.user_id = v_user_id
      AND r.payment_status <> 'cancelled'
      AND t.trek_date IS NOT NULL
      AND t.trek_date < CURRENT_DATE
  ),
  daily_activity AS (
    SELECT das.date AS activity_date, das.steps, das.distance_km, das.calories
    FROM public.daily_activity_summary das
    WHERE das.user_id = v_user_id
  ),
  -- Current running consecutive-active-days streak, computed ONCE
  -- (not per challenge) — identical gaps-and-islands shape to
  -- get_my_streak() (0024_streaks.sql), day-granular instead of
  -- month-granular, with the same one-unit grace period ("yesterday
  -- still counts, today isn't over yet").
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
$$;


-- ────────────────────────────────────────────────────────────
-- get_my_challenge_tier_history()
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_my_challenge_tier_history()
RETURNS TABLE (
  challenge_id  UUID,
  tier          challenge_tier,
  achieved_at   DATE
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
  WITH attended_treks AS (
    SELECT t.distance_km, t.trek_date AS activity_date
    FROM public.registrations r
    JOIN public.treks t ON t.id = r.trek_id
    WHERE r.user_id = v_user_id
      AND r.payment_status <> 'cancelled'
      AND t.trek_date IS NOT NULL
      AND t.trek_date < CURRENT_DATE
  ),
  daily_activity AS (
    SELECT das.date AS activity_date, das.steps, das.distance_km, das.calories
    FROM public.daily_activity_summary das
    WHERE das.user_id = v_user_id
  ),
  -- Every cumulative-sum metric (trek + fitness) unified into one row
  -- shape: challenge_id / activity_date / a single numeric_value that
  -- already encodes what "counts" for that metric (1 per row for
  -- trek_count so SUM acts like COUNT, the real number otherwise) —
  -- this is what lets ONE running-sum window function below serve
  -- every cumulative metric generically.
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
  -- active_streak_days is NOT a cumulative sum — "achieved tier N"
  -- means "the first day the user's running consecutive-active-days
  -- count (as of that day, not necessarily the CURRENT running streak)
  -- reached N". streak_length_here below is that per-day count, via
  -- the same island-grouping technique, then MIN(date) per tier
  -- mirrors cumulative_tier_history's own MIN(date)-past-threshold
  -- shape exactly.
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
$$;


-- ────────────────────────────────────────────────────────────
-- get_challenge_leaderboard(p_challenge_id UUID)
-- ────────────────────────────────────────────────────────────
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
    WHERE r.payment_status <> 'cancelled'
      AND t.trek_date IS NOT NULL
      AND t.trek_date < CURRENT_DATE
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
  -- Per-user version of the same day-granular streak computation used
  -- in the progress/tier-history RPCs above, just partitioned by user
  -- instead of scoped to a single caller — this RPC ranks OTHER users,
  -- not just the caller.
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
$$;
