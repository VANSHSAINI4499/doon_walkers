-- ============================================================
-- DoonWalkers — Redesign 2.0, Phase 19: Database Schema Foundations
-- Migration: 0036_phase19_schema_foundations.sql
-- ============================================================

-- ── 1. PERSONAL GOALS ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_goals (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  goal_type     TEXT NOT NULL CHECK (goal_type IN ('daily_steps', 'monthly_steps')),
  target_value  INTEGER NOT NULL CHECK (target_value > 0),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (user_id, goal_type)
);

ALTER TABLE public.user_goals ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "user_goals_select_own" ON public.user_goals
    FOR SELECT USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "user_goals_insert_own" ON public.user_goals
    FOR INSERT WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "user_goals_update_own" ON public.user_goals
    FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "user_goals_delete_own" ON public.user_goals
    FOR DELETE USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "user_goals_admin_all" ON public.user_goals
    FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE OR REPLACE FUNCTION public.get_or_create_user_goal(
  p_user_id UUID,
  p_goal_type TEXT
)
RETURNS public.user_goals
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_goal public.user_goals;
  v_default_target INTEGER;
BEGIN
  SELECT * INTO v_goal
  FROM public.user_goals
  WHERE user_id = p_user_id AND goal_type = p_goal_type;

  IF FOUND THEN
    RETURN v_goal;
  END IF;

  IF p_goal_type = 'daily_steps' THEN
    v_default_target := 6500;
  ELSIF p_goal_type = 'monthly_steps' THEN
    v_default_target := 200000;
  ELSE
    RAISE EXCEPTION 'Invalid goal_type: %', p_goal_type;
  END IF;

  INSERT INTO public.user_goals (user_id, goal_type, target_value)
  VALUES (p_user_id, p_goal_type, v_default_target)
  ON CONFLICT (user_id, goal_type) DO UPDATE SET updated_at = NOW()
  RETURNING * INTO v_goal;

  RETURN v_goal;
END;
$$;


-- ── 2. ACTIVE TIME ─────────────────────────────────────────────────
ALTER TABLE public.daily_activity_summary
  ADD COLUMN IF NOT EXISTS active_minutes INTEGER NOT NULL DEFAULT 0 CHECK (active_minutes >= 0);


-- ── 3. POINTS / LEVELS ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_points (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  total_points  INTEGER NOT NULL DEFAULT 0 CHECK (total_points >= 0),
  level         INTEGER NOT NULL DEFAULT 1 CHECK (level >= 1),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.user_points ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "user_points_select_own" ON public.user_points
    FOR SELECT USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "user_points_admin_all" ON public.user_points
    FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.points_ledger (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  points        INTEGER NOT NULL,
  reason        TEXT NOT NULL,
  reference_id  UUID,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.points_ledger ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "points_ledger_select_own" ON public.points_ledger
    FOR SELECT USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "points_ledger_admin_all" ON public.points_ledger
    FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

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
  -- Insert into ledger
  INSERT INTO public.points_ledger (user_id, points, reason, reference_id)
  VALUES (p_user_id, p_points, p_reason, p_reference_id);

  -- Upsert into user_points
  INSERT INTO public.user_points (user_id, total_points, level, updated_at)
  VALUES (p_user_id, GREATEST(0, p_points), 1, NOW())
  ON CONFLICT (user_id) DO UPDATE
  SET total_points = GREATEST(0, public.user_points.total_points + p_points),
      updated_at = NOW()
  RETURNING total_points INTO v_new_total;

  -- Determine level based on thresholds
  IF v_new_total >= 15000 THEN v_new_level := 8;
  ELSIF v_new_total >= 10000 THEN v_new_level := 7;
  ELSIF v_new_total >= 7500 THEN v_new_level := 6;
  ELSIF v_new_total >= 5000 THEN v_new_level := 5;
  ELSIF v_new_total >= 3000 THEN v_new_level := 4;
  ELSIF v_new_total >= 1500 THEN v_new_level := 3;
  ELSIF v_new_total >= 500 THEN v_new_level := 2;
  ELSE v_new_level := 1;
  END IF;

  UPDATE public.user_points
  SET level = v_new_level
  WHERE user_id = p_user_id
  RETURNING * INTO v_user_points;

  RETURN v_user_points;
END;
$$;


-- ── 4. COMMUNITY INFRASTRUCTURE ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.community_posts (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  body          TEXT NOT NULL,
  trek_id       UUID REFERENCES public.treks(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.community_posts ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "community_posts_select_authenticated" ON public.community_posts
    FOR SELECT USING (auth.role() = 'authenticated');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "community_posts_insert_own" ON public.community_posts
    FOR INSERT WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "community_posts_update_own" ON public.community_posts
    FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "community_posts_delete_own" ON public.community_posts
    FOR DELETE USING (auth.uid() = user_id OR public.is_admin());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "community_posts_admin_all" ON public.community_posts
    FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.post_media (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id       UUID NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
  media_url     TEXT NOT NULL,
  media_type    TEXT NOT NULL CHECK (media_type IN ('image', 'video')),
  sort_order    INTEGER NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.post_media ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "post_media_select_authenticated" ON public.post_media
    FOR SELECT USING (auth.role() = 'authenticated');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "post_media_insert_own" ON public.post_media
    FOR INSERT WITH CHECK (
      EXISTS (
        SELECT 1 FROM public.community_posts
        WHERE id = post_id AND user_id = auth.uid()
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "post_media_update_own" ON public.post_media
    FOR UPDATE USING (
      EXISTS (
        SELECT 1 FROM public.community_posts
        WHERE id = post_id AND user_id = auth.uid()
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "post_media_delete_own" ON public.post_media
    FOR DELETE USING (
      EXISTS (
        SELECT 1 FROM public.community_posts
        WHERE id = post_id AND user_id = auth.uid()
      )
      OR public.is_admin()
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "post_media_admin_all" ON public.post_media
    FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.post_likes (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id       UUID NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (post_id, user_id)
);

ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "post_likes_select_authenticated" ON public.post_likes
    FOR SELECT USING (auth.role() = 'authenticated');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "post_likes_insert_own" ON public.post_likes
    FOR INSERT WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "post_likes_delete_own" ON public.post_likes
    FOR DELETE USING (auth.uid() = user_id OR public.is_admin());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "post_likes_admin_all" ON public.post_likes
    FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.post_comments (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id       UUID NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  body          TEXT NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "post_comments_select_authenticated" ON public.post_comments
    FOR SELECT USING (auth.role() = 'authenticated');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "post_comments_insert_own" ON public.post_comments
    FOR INSERT WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "post_comments_delete_own" ON public.post_comments
    FOR DELETE USING (auth.uid() = user_id OR public.is_admin());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "post_comments_admin_all" ON public.post_comments
    FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.post_bookmarks (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id       UUID NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (post_id, user_id)
);

ALTER TABLE public.post_bookmarks ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "post_bookmarks_select_own" ON public.post_bookmarks
    FOR SELECT USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "post_bookmarks_insert_own" ON public.post_bookmarks
    FOR INSERT WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "post_bookmarks_delete_own" ON public.post_bookmarks
    FOR DELETE USING (auth.uid() = user_id OR public.is_admin());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "post_bookmarks_admin_all" ON public.post_bookmarks
    FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Storage Bucket: community-media
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'community-media',
  'community-media',
  true,
  52428800,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'video/mp4', 'video/quicktime', 'video/webm']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 52428800;

DO $$ BEGIN
  CREATE POLICY "community_media_public_select" ON storage.objects
    FOR SELECT USING (bucket_id = 'community-media');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "community_media_auth_insert" ON storage.objects
    FOR INSERT WITH CHECK (
      bucket_id = 'community-media'
      AND auth.role() = 'authenticated'
      AND (storage.foldername(name))[1] = auth.uid()::text
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "community_media_auth_delete" ON storage.objects
    FOR DELETE USING (
      bucket_id = 'community-media'
      AND (
        (storage.foldername(name))[1] = auth.uid()::text
        OR public.is_admin()
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- RPC: get_feed_posts
CREATE OR REPLACE FUNCTION public.get_feed_posts(
  p_limit INT DEFAULT 20,
  p_offset INT DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  user_name TEXT,
  avatar_url TEXT,
  body TEXT,
  trek_id UUID,
  trek_title TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  like_count BIGINT,
  comment_count BIGINT,
  is_liked_by_me BOOLEAN,
  is_bookmarked_by_me BOOLEAN,
  media JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.user_id,
    COALESCE(u.name, 'Walker') AS user_name,
    u.avatar_url,
    p.body,
    p.trek_id,
    t.title AS trek_title,
    p.created_at,
    p.updated_at,
    COUNT(DISTINCT l.id) AS like_count,
    COUNT(DISTINCT c.id) AS comment_count,
    EXISTS (
      SELECT 1 FROM public.post_likes pl
      WHERE pl.post_id = p.id AND pl.user_id = auth.uid()
    ) AS is_liked_by_me,
    EXISTS (
      SELECT 1 FROM public.post_bookmarks pb
      WHERE pb.post_id = p.id AND pb.user_id = auth.uid()
    ) AS is_bookmarked_by_me,
    COALESCE(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'id', pm.id,
            'media_url', pm.media_url,
            'media_type', pm.media_type,
            'sort_order', pm.sort_order
          ) ORDER BY pm.sort_order ASC
        )
        FROM public.post_media pm
        WHERE pm.post_id = p.id
      ),
      '[]'::jsonb
    ) AS media
  FROM public.community_posts p
  LEFT JOIN public.users u ON u.id = p.user_id
  LEFT JOIN public.treks t ON t.id = p.trek_id
  LEFT JOIN public.post_likes l ON l.post_id = p.id
  LEFT JOIN public.post_comments c ON c.post_id = p.id
  GROUP BY p.id, u.name, u.avatar_url, t.title
  ORDER BY p.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

-- RPC: get_trending_topics
CREATE OR REPLACE FUNCTION public.get_trending_topics(
  p_limit INT DEFAULT 5
)
RETURNS TABLE (
  trek_id UUID,
  trek_title TEXT,
  post_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.trek_id,
    t.title AS trek_title,
    COUNT(p.id) AS post_count
  FROM public.community_posts p
  JOIN public.treks t ON t.id = p.trek_id
  WHERE p.trek_id IS NOT NULL
    AND p.created_at >= NOW() - INTERVAL '7 days'
  GROUP BY p.trek_id, t.title
  ORDER BY post_count DESC
  LIMIT p_limit;
END;
$$;


-- ── 5. ACHIEVEMENTS / BADGES ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.achievement_definitions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key             TEXT NOT NULL UNIQUE,
  title           TEXT NOT NULL,
  description     TEXT NOT NULL,
  icon_asset      TEXT NOT NULL,
  unlock_metric   TEXT NOT NULL,
  unlock_value    INTEGER NOT NULL CHECK (unlock_value > 0),
  points_reward   INTEGER NOT NULL DEFAULT 0 CHECK (points_reward >= 0)
);

ALTER TABLE public.achievement_definitions ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "achievement_definitions_select_all" ON public.achievement_definitions
    FOR SELECT USING (auth.role() = 'authenticated');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "achievement_definitions_admin_all" ON public.achievement_definitions
    FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.user_achievements (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  achievement_id  UUID NOT NULL REFERENCES public.achievement_definitions(id) ON DELETE CASCADE,
  unlocked_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (user_id, achievement_id)
);

ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "user_achievements_select_own" ON public.user_achievements
    FOR SELECT USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "user_achievements_admin_all" ON public.user_achievements
    FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Seed 4 initial achievements
INSERT INTO public.achievement_definitions (key, title, description, icon_asset, unlock_metric, unlock_value, points_reward)
VALUES
  ('step_master', 'Step Master', '10,000 steps in a day', 'assets/icons/badges/step_master.png', 'daily_steps', 10000, 50),
  ('calorie_crusher', 'Calorie Crusher', '2,000+ calories burned in a day', 'assets/icons/badges/calorie_crusher.png', 'daily_calories', 2000, 50),
  ('distance_pro', 'Distance Pro', 'Walked 100+ km this month', 'assets/icons/badges/distance_pro.png', 'monthly_km', 100, 100),
  ('mountain_explorer', 'Mountain Explorer', 'Completed 5 treks', 'assets/icons/badges/mountain_explorer.png', 'trek_count', 5, 100)
ON CONFLICT (key) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  icon_asset = EXCLUDED.icon_asset,
  unlock_metric = EXCLUDED.unlock_metric,
  unlock_value = EXCLUDED.unlock_value,
  points_reward = EXCLUDED.points_reward;


-- ── 6. TREK CAPACITY ───────────────────────────────────────────────
ALTER TABLE public.treks
  ADD COLUMN IF NOT EXISTS max_participants INTEGER CHECK (max_participants IS NULL OR max_participants > 0);

CREATE OR REPLACE FUNCTION public.get_spots_remaining(p_trek_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_max INTEGER;
  v_taken INTEGER;
BEGIN
  SELECT max_participants INTO v_max
  FROM public.treks
  WHERE id = p_trek_id;

  IF v_max IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_taken
  FROM public.registrations
  WHERE trek_id = p_trek_id
    AND payment_status IN ('paid', 'confirmed', 'pending');

  RETURN GREATEST(0, v_max - v_taken);
END;
$$;


-- ── 7. PROFILE PHOTO ───────────────────────────────────────────────
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS avatar_url TEXT;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 5242880;

DO $$ BEGIN
  CREATE POLICY "avatars_public_select" ON storage.objects
    FOR SELECT USING (bucket_id = 'avatars');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "avatars_auth_insert" ON storage.objects
    FOR INSERT WITH CHECK (
      bucket_id = 'avatars'
      AND auth.role() = 'authenticated'
      AND (storage.foldername(name))[1] = auth.uid()::text
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "avatars_auth_update" ON storage.objects
    FOR UPDATE USING (
      bucket_id = 'avatars'
      AND auth.role() = 'authenticated'
      AND (storage.foldername(name))[1] = auth.uid()::text
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "avatars_auth_delete" ON storage.objects
    FOR DELETE USING (
      bucket_id = 'avatars'
      AND (
        (storage.foldername(name))[1] = auth.uid()::text
        OR public.is_admin()
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;


-- ── 8. CANCELLATION REASON ─────────────────────────────────────────
ALTER TABLE public.treks
  ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;
