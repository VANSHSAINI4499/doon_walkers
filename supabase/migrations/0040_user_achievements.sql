-- ============================================================
-- DoonWalkers — Redesign 2.0, Phase 25: Achievements Integration
-- Migration: 0040_user_achievements.sql
-- ============================================================

-- ── 1. SCHEMA CHANGES TO USER_ACHIEVEMENTS ────────────────────────────────
-- Alter the user_achievements table to add support for achievements that are
-- not linked to achievement_definitions (milestone levels and challenge platinums).
-- Rename unlocked_at to achieved_at to align with the new RPC return fields.

ALTER TABLE public.user_achievements 
  ADD COLUMN IF NOT EXISTS achievement_type TEXT NOT NULL DEFAULT 'badge';

ALTER TABLE public.user_achievements
  ADD COLUMN IF NOT EXISTS reference_id UUID DEFAULT NULL;

ALTER TABLE public.user_achievements
  ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT NULL;

-- Rename unlocked_at to achieved_at if unlocked_at exists
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'user_achievements' AND column_name = 'unlocked_at'
  ) THEN
    ALTER TABLE public.user_achievements RENAME COLUMN unlocked_at TO achieved_at;
  END IF;
END $$;

-- Make achievement_id nullable, since milestone levels and platinums do not use it
ALTER TABLE public.user_achievements 
  ALTER COLUMN achievement_id DROP NOT NULL;

-- ── 2. UNIQUE INDEX CONSTRAINTS ───────────────────────────────────────────
-- Ensure we prevent duplicate entries for milestones (one per level) and
-- platinums (one per challenge) for any user.

CREATE UNIQUE INDEX IF NOT EXISTS user_achievements_level_milestone_idx
  ON public.user_achievements (user_id, (metadata->>'level'))
  WHERE achievement_type = 'level_milestone';

CREATE UNIQUE INDEX IF NOT EXISTS user_achievements_challenge_platinum_idx
  ON public.user_achievements (user_id, reference_id)
  WHERE achievement_type = 'challenge_platinum';

-- ── 3. UPDATE award_points RPC FUNCTION ──────────────────────────────────
-- Centralized points/level update location: automatically logs milestone
-- levels and challenge platinum achievements inside this RPC.

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
  v_old_level INTEGER;
BEGIN
  -- Get previous level
  SELECT level INTO v_old_level
  FROM public.user_points
  WHERE user_id = p_user_id;

  IF v_old_level IS NULL THEN
    v_old_level := 1;
  END IF;

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

  -- ── Phase 25: Achievements Integration ──
  
  -- 1. Level Milestones (Levels 5 and 8 are the milestones in our ladder)
  IF v_new_level >= 5 AND COALESCE(v_old_level, 1) < 5 THEN
    INSERT INTO public.user_achievements (user_id, achievement_type, metadata, achieved_at)
    VALUES (p_user_id, 'level_milestone', '{"level": 5}'::jsonb, NOW())
    ON CONFLICT (user_id, (metadata->>'level')) WHERE achievement_type = 'level_milestone' DO NOTHING;
  END IF;

  IF v_new_level >= 8 AND COALESCE(v_old_level, 1) < 8 THEN
    INSERT INTO public.user_achievements (user_id, achievement_type, metadata, achieved_at)
    VALUES (p_user_id, 'level_milestone', '{"level": 8}'::jsonb, NOW())
    ON CONFLICT (user_id, (metadata->>'level')) WHERE achievement_type = 'level_milestone' DO NOTHING;
  END IF;

  -- 2. Challenge Platinum Completion
  IF p_reason = 'challenge_completed' AND p_reference_id IS NOT NULL THEN
    INSERT INTO public.user_achievements (user_id, achievement_type, reference_id, achieved_at)
    VALUES (p_user_id, 'challenge_platinum', p_reference_id, NOW())
    ON CONFLICT (user_id, reference_id) WHERE achievement_type = 'challenge_platinum' DO NOTHING;
  END IF;

  RETURN v_user_points;
END;
$$;

-- ── 4. RPC: get_my_achievements ──────────────────────────────────────────
-- Returns the caller's own achievements (milestones, platinums, and standard badges)
-- ordered by achieved_at desc, joining dynamically with definitions where possible.

CREATE OR REPLACE FUNCTION public.get_my_achievements(
  p_limit INT DEFAULT 20,
  p_offset INT DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  achievement_id UUID,
  achievement_type TEXT,
  reference_id UUID,
  metadata JSONB,
  achieved_at TIMESTAMPTZ,
  key TEXT,
  title TEXT,
  description TEXT,
  icon_asset TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  RETURN QUERY
  SELECT 
    ua.id,
    ua.user_id,
    ua.achievement_id,
    ua.achievement_type,
    ua.reference_id,
    ua.metadata,
    ua.achieved_at,
    COALESCE(ad.key, 
      CASE ua.achievement_type 
        WHEN 'level_milestone' THEN 'level_milestone_' || (ua.metadata->>'level')
        WHEN 'challenge_platinum' THEN 'challenge_platinum_' || ua.reference_id::text
        ELSE 'achievement_' || ua.id::text
      END
    ) AS key,
    COALESCE(ad.title, 
      CASE ua.achievement_type 
        WHEN 'level_milestone' THEN 'Level ' || (ua.metadata->>'level') || ' Milestone'
        WHEN 'challenge_platinum' THEN 'Challenge Completed'
        ELSE 'Achievement Unlocked'
      END
    ) AS title,
    COALESCE(ad.description,
      CASE ua.achievement_type
        WHEN 'level_milestone' THEN 'Reached the level ' || (ua.metadata->>'level') || ' milestone!'
        WHEN 'challenge_platinum' THEN 'Mastered a fitness challenge by reaching the Platinum tier!'
        ELSE 'Congratulations on your achievement!'
      END
    ) AS description,
    COALESCE(ad.icon_asset,
      CASE ua.achievement_type
        WHEN 'level_milestone' THEN 'assets/icons/badges/level_' || (ua.metadata->>'level') || '.png'
        WHEN 'challenge_platinum' THEN 'assets/icons/badges/platinum_challenge.png'
        ELSE 'assets/icons/badges/default.png'
      END
    ) AS icon_asset
  FROM public.user_achievements ua
  LEFT JOIN public.achievement_definitions ad ON ad.id = ua.achievement_id
  WHERE ua.user_id = v_user_id
  ORDER BY ua.achieved_at DESC, ua.id DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;
