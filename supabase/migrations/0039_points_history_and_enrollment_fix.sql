-- ============================================================
-- DoonWalkers — Redesign 2.0, Phase 22: Profile & Points/Levels
-- Migration: 0039_points_history_and_enrollment_fix.sql
-- ============================================================
-- Adds:
--   1. level_for_points(points) / points_for_level(level) — the Phase 19
--      level ladder extracted out of award_points() into its own pure
--      functions, so it has exactly one source of truth.
--   2. award_points() rewritten to call level_for_points() instead of
--      its old inline IF/ELSIF chain — same thresholds, same behavior,
--      now shared instead of duplicated.
--   3. get_my_points_summary() RPC — total_points, level, and points
--      needed for the next level, for Profile's points summary card.
--   4. enroll_in_challenge() rewritten to close the Phase 21 re-enroll
--      exploit: the 10-point welcome bonus is now checked against
--      points_ledger (not challenge_enrollments), so leaving and
--      rejoining a challenge no longer re-awards it.
-- ============================================================


-- ── 1. level_for_points / points_for_level ────────────────────────────────
-- The level ladder itself, extracted verbatim from the inline IF/ELSIF
-- chain award_points() has carried since 0036_phase19_schema_foundations.
-- Thresholds are UNCHANGED — this is a refactor, not a re-tune.
CREATE OR REPLACE FUNCTION public.level_for_points(p_points INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF p_points >= 15000 THEN RETURN 8;
  ELSIF p_points >= 10000 THEN RETURN 7;
  ELSIF p_points >= 7500 THEN RETURN 6;
  ELSIF p_points >= 5000 THEN RETURN 5;
  ELSIF p_points >= 3000 THEN RETURN 4;
  ELSIF p_points >= 1500 THEN RETURN 3;
  ELSIF p_points >= 500 THEN RETURN 2;
  ELSE RETURN 1;
  END IF;
END;
$$;

-- Inverse of level_for_points: the total_points value at which p_level
-- is first reached. NULL for anything past the top of the ladder (8),
-- which get_my_points_summary() reads as "already at max level".
CREATE OR REPLACE FUNCTION public.points_for_level(p_level INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN CASE p_level
    WHEN 1 THEN 0
    WHEN 2 THEN 500
    WHEN 3 THEN 1500
    WHEN 4 THEN 3000
    WHEN 5 THEN 5000
    WHEN 6 THEN 7500
    WHEN 7 THEN 10000
    WHEN 8 THEN 15000
    ELSE NULL
  END;
END;
$$;


-- ── 2. award_points — now reuses level_for_points ─────────────────────────
CREATE OR REPLACE FUNCTION public.award_points(
  p_user_id UUID,
  p_points INTEGER,
  p_reason TEXT,
  p_reference_id UUID DEFAULT NULL
)
RETURNS public.user_points
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_new_total INTEGER;
  v_new_level INTEGER;
  v_user_points public.user_points;
BEGIN
  INSERT INTO public.points_ledger (user_id, points, reason, reference_id)
  VALUES (p_user_id, p_points, p_reason, p_reference_id);

  INSERT INTO public.user_points (user_id, total_points, level, updated_at)
  VALUES (p_user_id, GREATEST(0, p_points), 1, NOW())
  ON CONFLICT (user_id) DO UPDATE
  SET total_points = GREATEST(0, public.user_points.total_points + p_points),
      updated_at = NOW()
  RETURNING total_points INTO v_new_total;

  v_new_level := public.level_for_points(v_new_total);

  UPDATE public.user_points SET level = v_new_level WHERE user_id = p_user_id
  RETURNING * INTO v_user_points;

  RETURN v_user_points;
END;
$$;


-- ── 3. get_my_points_summary RPC ──────────────────────────────────────────
-- Profile's points summary card reads this instead of hardcoding the
-- ladder client-side. Returns 0/level 1 for a signed-in user with no
-- points row yet (mirrors award_points' own first-row defaults).
-- `current_level_floor` is the points_for_level() value for the level the
-- caller is ALREADY at — the client needs it to normalize the progress
-- bar to "how far through this level", not just "total vs next threshold".
CREATE OR REPLACE FUNCTION public.get_my_points_summary()
RETURNS TABLE (
  total_points INTEGER,
  level INTEGER,
  current_level_floor INTEGER,
  next_level INTEGER,
  points_to_next_level INTEGER,
  is_max_level BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_total INTEGER;
  v_level INTEGER;
  v_next_level INTEGER;
  v_next_threshold INTEGER;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  SELECT up.total_points, up.level INTO v_total, v_level
  FROM public.user_points up
  WHERE up.user_id = v_user_id;

  IF v_total IS NULL THEN
    v_total := 0;
    v_level := 1;
  END IF;

  v_next_level := v_level + 1;
  v_next_threshold := public.points_for_level(v_next_level);

  RETURN QUERY SELECT
    v_total,
    v_level,
    public.points_for_level(v_level),
    CASE WHEN v_next_threshold IS NULL THEN NULL ELSE v_next_level END,
    CASE WHEN v_next_threshold IS NULL THEN NULL ELSE v_next_threshold - v_total END,
    v_next_threshold IS NULL;
END;
$$;


-- ── 4. enroll_in_challenge — close the re-enroll points exploit ──────────
-- Phase 21's version gated the welcome bonus on challenge_enrollments
-- (the enrollment row), which unenroll_from_challenge deletes. That let
-- a user enroll -> unenroll -> re-enroll repeatedly and farm 10 points
-- per cycle. The bonus is meant to be one-time per (user, challenge),
-- so the gate now checks points_ledger itself — an append-only table
-- unenroll never touches — keyed on reason='challenge_enrolled' AND
-- reference_id=p_challenge_id, which is exactly how award_points wrote
-- the original entry.
CREATE OR REPLACE FUNCTION public.enroll_in_challenge(
  p_challenge_id UUID
)
RETURNS public.challenge_enrollments
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_enrollment public.challenge_enrollments;
  v_already_exists BOOLEAN;
  v_already_awarded BOOLEAN;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  -- Check if enrollment already exists (idempotent)
  SELECT EXISTS (
    SELECT 1 FROM public.challenge_enrollments
    WHERE challenge_id = p_challenge_id AND user_id = v_user_id
  ) INTO v_already_exists;

  IF v_already_exists THEN
    -- Return existing row without awarding points again
    SELECT * INTO v_enrollment
    FROM public.challenge_enrollments
    WHERE challenge_id = p_challenge_id AND user_id = v_user_id;
    RETURN v_enrollment;
  END IF;

  -- Insert new enrollment
  INSERT INTO public.challenge_enrollments (challenge_id, user_id)
  VALUES (p_challenge_id, v_user_id)
  RETURNING * INTO v_enrollment;

  -- Award the 10-point welcome bonus only if this user has never been
  -- awarded it for this challenge before (see doc above).
  SELECT EXISTS (
    SELECT 1 FROM public.points_ledger
    WHERE user_id = v_user_id
      AND reason = 'challenge_enrolled'
      AND reference_id = p_challenge_id
  ) INTO v_already_awarded;

  IF NOT v_already_awarded THEN
    BEGIN
      PERFORM public.award_points(v_user_id, 10, 'challenge_enrolled', p_challenge_id);
    EXCEPTION WHEN OTHERS THEN
      -- Log but do not propagate — enrollment itself succeeded
      RAISE WARNING 'enroll_in_challenge: award_points failed for user % on challenge %: %',
        v_user_id, p_challenge_id, SQLERRM;
    END;
  END IF;

  RETURN v_enrollment;
END;
$$;
