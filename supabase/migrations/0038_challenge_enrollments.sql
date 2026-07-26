-- ============================================================
-- DoonWalkers — Redesign 2.0, Phase 21: Challenge Enrollments
-- Migration: 0038_challenge_enrollments.sql
-- ============================================================
-- Adds:
--   1. point_value column on challenges table
--   2. challenge_enrollments table + RLS
--   3. enroll_in_challenge(p_challenge_id) RPC
--   4. unenroll_from_challenge(p_challenge_id) RPC
--   5. get_challenge_participant_count(p_challenge_id) RPC
--   6. get_challenge_top_participants(p_challenge_id, p_limit) RPC
-- ============================================================


-- ── 1. POINT VALUE ON CHALLENGES ──────────────────────────────────────────
-- Adds a point reward value to each challenge. Defaults to 50 for all
-- existing challenges. Admin form will allow editing per challenge.
ALTER TABLE public.challenges
  ADD COLUMN IF NOT EXISTS point_value INTEGER NOT NULL DEFAULT 50
    CHECK (point_value >= 0);


-- ── 2. CHALLENGE ENROLLMENTS TABLE ────────────────────────────────────────
-- Tracks which users have explicitly enrolled in which challenges.
-- Prior to this phase, all active challenges applied to everyone;
-- enrollment is now the opt-in gate for points awards and the
-- Join/Leave UI.
CREATE TABLE IF NOT EXISTS public.challenge_enrollments (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id  UUID NOT NULL REFERENCES public.challenges(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  enrolled_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (challenge_id, user_id)
);

ALTER TABLE public.challenge_enrollments ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read ALL enrollment rows (needed for counts)
DO $$ BEGIN
  CREATE POLICY "challenge_enrollments_select_auth" ON public.challenge_enrollments
    FOR SELECT USING (auth.role() = 'authenticated');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Users can only insert their own enrollment rows
DO $$ BEGIN
  CREATE POLICY "challenge_enrollments_insert_own" ON public.challenge_enrollments
    FOR INSERT WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Users can delete only their own enrollment rows
DO $$ BEGIN
  CREATE POLICY "challenge_enrollments_delete_own" ON public.challenge_enrollments
    FOR DELETE USING (auth.uid() = user_id OR public.is_admin());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Admin has full access
DO $$ BEGIN
  CREATE POLICY "challenge_enrollments_admin_all" ON public.challenge_enrollments
    FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Index for efficient per-challenge count lookups
CREATE INDEX IF NOT EXISTS challenge_enrollments_challenge_id_idx
  ON public.challenge_enrollments (challenge_id);

-- Index for efficient per-user enrollment lookups
CREATE INDEX IF NOT EXISTS challenge_enrollments_user_id_idx
  ON public.challenge_enrollments (user_id);


-- ── 3. enroll_in_challenge RPC ─────────────────────────────────────────────
-- Inserts an enrollment row for the calling user and awards a 10-point
-- welcome bonus via award_points(). Returns the new enrollment row.
-- Safe to call multiple times (ON CONFLICT DO NOTHING for idempotency).
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

  -- Award 10-point welcome bonus (fire-and-forget — failure here should
  -- not roll back the enrollment, so we trap exceptions)
  BEGIN
    PERFORM public.award_points(v_user_id, 10, 'challenge_enrolled', p_challenge_id);
  EXCEPTION WHEN OTHERS THEN
    -- Log but do not propagate — enrollment itself succeeded
    RAISE WARNING 'enroll_in_challenge: award_points failed for user % on challenge %: %',
      v_user_id, p_challenge_id, SQLERRM;
  END;

  RETURN v_enrollment;
END;
$$;


-- ── 4. unenroll_from_challenge RPC ─────────────────────────────────────────
-- Deletes the calling user's enrollment row. Points earned for enrollment
-- are NOT reversed (enrollment bonus is kept as earned). Returns the
-- deleted row's id, or NULL if the user was not enrolled.
CREATE OR REPLACE FUNCTION public.unenroll_from_challenge(
  p_challenge_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_deleted_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  DELETE FROM public.challenge_enrollments
  WHERE challenge_id = p_challenge_id AND user_id = v_user_id
  RETURNING id INTO v_deleted_id;

  RETURN v_deleted_id;
END;
$$;


-- ── 5. get_challenge_participant_count RPC ─────────────────────────────────
-- Returns the total count of enrolled users for a given challenge.
-- Safe to call as a guest (read-only count, no PII returned).
CREATE OR REPLACE FUNCTION public.get_challenge_participant_count(
  p_challenge_id UUID
)
RETURNS BIGINT
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT COUNT(*)
  FROM public.challenge_enrollments
  WHERE challenge_id = p_challenge_id;
$$;


-- ── 6. get_challenge_top_participants RPC ──────────────────────────────────
-- Returns the top N enrolled users for a challenge, ordered by their
-- live challenge progress score descending, with their total_points from
-- the user_points table for the level display.
--
-- Score source: joins challenge_enrollments with the live progress
-- computation from get_my_challenge_progress() logic — specifically,
-- reads from the same view/function used by get_challenge_leaderboard()
-- but restricted to enrolled users only.
--
-- Each row: user_id, display_name, avatar_url, score, total_points, level
CREATE OR REPLACE FUNCTION public.get_challenge_top_participants(
  p_challenge_id UUID,
  p_limit INT DEFAULT 10
)
RETURNS TABLE (
  user_id       UUID,
  display_name  TEXT,
  avatar_url    TEXT,
  score         DOUBLE PRECISION,
  total_points  INTEGER,
  level         INTEGER
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
  -- Use the existing get_challenge_leaderboard logic restricted to
  -- enrolled users. get_challenge_leaderboard returns (display_name, rank, score)
  -- so we re-derive the score here by joining challenge_enrollments with
  -- the users table and the existing leaderboard RPC output.
  RETURN QUERY
  SELECT
    u.id AS user_id,
    COALESCE(u.name, 'Walker') AS display_name,
    u.avatar_url,
    COALESCE(lb.score, 0.0) AS score,
    COALESCE(up.total_points, 0) AS total_points,
    COALESCE(up.level, 1) AS level
  FROM public.challenge_enrollments ce
  JOIN public.users u ON u.id = ce.user_id
  LEFT JOIN public.user_points up ON up.user_id = ce.user_id
  -- Correlated subquery to get this user's score from the leaderboard
  LEFT JOIN LATERAL (
    SELECT lb_inner.score
    FROM get_challenge_leaderboard(p_challenge_id) lb_inner
    WHERE lb_inner.display_name = COALESCE(u.name, 'Walker')
    LIMIT 1
  ) lb ON true
  WHERE ce.challenge_id = p_challenge_id
  ORDER BY lb.score DESC NULLS LAST, up.total_points DESC NULLS LAST
  LIMIT p_limit;
END;
$$;
