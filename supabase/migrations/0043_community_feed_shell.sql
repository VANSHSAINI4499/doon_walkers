-- ── Migration 0043: Community Leaderboard & Member Directory RPCs ──────

-- 1. RPC: get_community_leaderboard
CREATE OR REPLACE FUNCTION public.get_community_leaderboard(
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0
)
RETURNS TABLE (
  user_id UUID,
  display_name TEXT,
  avatar_url TEXT,
  total_points INT,
  level INT,
  rank BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH ranked_users AS (
    SELECT
      u.id AS user_id,
      u.name AS display_name,
      u.avatar_url AS avatar_url,
      COALESCE(up.total_points, 0) AS total_points,
      COALESCE(up.level, 1) AS level,
      ROW_NUMBER() OVER (ORDER BY COALESCE(up.total_points, 0) DESC, u.created_at ASC) AS rank
    FROM public.users u
    LEFT JOIN public.user_points up ON up.user_id = u.id
    WHERE u.show_on_leaderboard = TRUE OR u.id = auth.uid()
  )
  SELECT
    r.user_id,
    r.display_name,
    r.avatar_url,
    r.total_points,
    r.level,
    r.rank
  FROM ranked_users r
  ORDER BY r.rank ASC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

-- 2. RPC: get_my_community_rank
CREATE OR REPLACE FUNCTION public.get_my_community_rank()
RETURNS TABLE (
  user_id UUID,
  display_name TEXT,
  avatar_url TEXT,
  total_points INT,
  level INT,
  rank BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH ranked_users AS (
    SELECT
      u.id AS user_id,
      u.name AS display_name,
      u.avatar_url AS avatar_url,
      COALESCE(up.total_points, 0) AS total_points,
      COALESCE(up.level, 1) AS level,
      ROW_NUMBER() OVER (ORDER BY COALESCE(up.total_points, 0) DESC, u.created_at ASC) AS rank
    FROM public.users u
    LEFT JOIN public.user_points up ON up.user_id = u.id
  )
  SELECT
    r.user_id,
    r.display_name,
    r.avatar_url,
    r.total_points,
    r.level,
    r.rank
  FROM ranked_users r
  WHERE r.user_id = auth.uid();
END;
$$;

-- 3. RPC: get_member_directory
CREATE OR REPLACE FUNCTION public.get_member_directory(
  p_limit INT DEFAULT 30,
  p_offset INT DEFAULT 0,
  p_search TEXT DEFAULT NULL
)
RETURNS TABLE (
  user_id UUID,
  display_name TEXT,
  avatar_url TEXT,
  total_points INT,
  level INT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    u.id AS user_id,
    u.name AS display_name,
    u.avatar_url AS avatar_url,
    COALESCE(up.total_points, 0) AS total_points,
    COALESCE(up.level, 1) AS level,
    u.created_at
  FROM public.users u
  LEFT JOIN public.user_points up ON up.user_id = u.id
  WHERE (auth.uid() IS NULL OR u.id <> auth.uid())
    AND (p_search IS NULL OR TRIM(p_search) = '' OR u.name ILIKE '%' || TRIM(p_search) || '%')
  ORDER BY u.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;
