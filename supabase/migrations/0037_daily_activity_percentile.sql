-- ============================================================
-- DoonWalkers — Redesign 2.0, Phase 20: Daily Activity Percentile RPC
-- Migration: 0037_daily_activity_percentile.sql
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_daily_activity_percentile(
  p_date DATE DEFAULT CURRENT_DATE
)
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_caller_id UUID;
  v_caller_steps INTEGER;
  v_total_users INTEGER;
  v_users_beaten INTEGER;
BEGIN
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT steps INTO v_caller_steps
  FROM public.daily_activity_summary
  WHERE user_id = v_caller_id AND date = p_date;

  IF v_caller_steps IS NULL OR v_caller_steps = 0 THEN
    RETURN NULL;
  END IF;

  SELECT COUNT(*) INTO v_total_users
  FROM public.daily_activity_summary
  WHERE date = p_date AND steps > 0;

  IF v_total_users < 5 THEN
    RETURN NULL;
  END IF;

  SELECT COUNT(*) INTO v_users_beaten
  FROM public.daily_activity_summary
  WHERE date = p_date AND steps > 0 AND steps < v_caller_steps;

  RETURN ROUND((v_users_beaten::NUMERIC / v_total_users::NUMERIC) * 100.0)::INTEGER;
END;
$$;
