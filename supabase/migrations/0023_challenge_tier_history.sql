-- ============================================================
-- DoonWalkers — Version 2, Phase C2: Challenges Tab UI
-- Migration: 0023_challenge_tier_history.sql
--
-- Adds get_my_challenge_tier_history(): for the calling user, every
-- (challenge, tier) they have actually reached, with the real DATE it
-- was reached — computed live, same "no maintained table" philosophy
-- as get_my_challenge_progress() (0022_challenges.sql), for the same
-- reason: nothing to keep in sync via triggers, and at this project's
-- real scale a live window-function query is trivial.
--
-- ── Why this is knowable without a stored achievement table:
--    both metrics are cumulative over a user's attended treks ordered
--    by date, so "when was tier X reached" is just "the date of the
--    attended trek whose running cumulative value first met tier X's
--    threshold" — a window function over the same attended_treks CTE
--    get_my_challenge_progress() already uses, not new tracked state.
--    This is also why it stays genuinely generic: it works for any
--    challenge/metric/time_window with zero challenge-specific code,
--    same guarantee as the progress RPC.
--
-- ── This does NOT track "has the user been shown a celebration for
--    this tier yet" — that's a purely client-side, per-device concern
--    (see ChallengeCelebrationTracker in the Dart layer), deliberately
--    not server state: it's about what this device has displayed, not
--    a fact about the challenge itself.
-- ============================================================

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
  -- Every attended trek that counts toward each active challenge,
  -- given that challenge's own time-window rule — identical filtering
  -- logic to get_my_challenge_progress()'s challenge_values CTE, just
  -- not pre-aggregated yet (the running total below needs each row).
  windowed AS (
    SELECT
      c.id AS challenge_id,
      c.metric,
      at.trek_date,
      at.distance_km
    FROM public.challenges c
    JOIN attended_treks at ON (
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
  ),
  -- Running cumulative value per challenge, ordered by trek_date — the
  -- value "as of" each attended trek. SUM()/COUNT() as window
  -- functions ignore NULL distance_km rows on their own, same as the
  -- progress RPC's COALESCE(SUM(...), 0) achieves for the aggregate
  -- case.
  -- Every column reference below is explicitly qualified (w.xxx),
  -- including inside PARTITION BY/ORDER BY — a bare `challenge_id` or
  -- `trek_date` here is ambiguous against this function's own
  -- RETURNS TABLE output-parameter names, which PL/pgSQL brings into
  -- scope as implicit variables for the whole function body. Caught
  -- live via a real invocation (ERROR 42702) before this ever shipped
  -- to a real caller; get_my_challenge_progress() never hit this only
  -- because every column it reads happens to already be qualified.
  running AS (
    SELECT
      w.challenge_id,
      w.trek_date,
      CASE w.metric
        WHEN 'trek_count' THEN
          COUNT(*) OVER (
            PARTITION BY w.challenge_id ORDER BY w.trek_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
          )::NUMERIC
        WHEN 'total_distance_km' THEN
          SUM(w.distance_km) OVER (
            PARTITION BY w.challenge_id ORDER BY w.trek_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
          )
      END AS running_value
    FROM windowed w
  )
  -- The earliest date each tier's threshold was actually met. Ties on
  -- the same trek_date (two treks attended the same day) still resolve
  -- correctly: MIN(trek_date) just returns that shared day, regardless
  -- of which same-day row the window function ordered first.
  SELECT
    ct.challenge_id,
    ct.tier,
    MIN(r.trek_date) AS achieved_at
  FROM public.challenge_tiers ct
  JOIN running r
    ON r.challenge_id = ct.challenge_id
    AND r.running_value >= ct.threshold_value
  GROUP BY ct.challenge_id, ct.tier;
END;
$$;
