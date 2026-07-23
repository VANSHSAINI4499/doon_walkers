-- ============================================================
-- DoonWalkers — Version 2, Challenges Module Pivot: Fitness Activity
-- Migration: 0027_daily_activity_summary.sql
--
-- See 0026's doc for the full pivot rationale. This table is what
-- ActivitySyncService upserts into after reading from whichever
-- ActivityProvider is active (Health Connect first, others later) —
-- the challenge engine (0028's RPCs) only ever reads THIS table, never
-- talks to a provider directly.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.daily_activity_summary (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  date          DATE NOT NULL,
  steps         INTEGER NOT NULL DEFAULT 0 CHECK (steps >= 0),
  distance_km   NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (distance_km >= 0),
  calories      NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (calories >= 0),
  synced_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- One row per user per calendar day — a re-sync of an already-synced
  -- day is always an UPDATE (upsert on this constraint), never a
  -- duplicate insert.
  UNIQUE (user_id, date)
);

ALTER TABLE public.daily_activity_summary ENABLE ROW LEVEL SECURITY;

-- Strictly own-row, no admin override — raw personal health data, same
-- "nobody else's business" posture as user_wishlist
-- (0019_user_wishlist.sql), arguably more warranted here. The
-- leaderboard/progress RPCs (SECURITY DEFINER) still read across every
-- user's rows for ranking purposes — that's a deliberate, narrow
-- exception baked into those functions' own bodies, not a hole in this
-- policy.
CREATE POLICY "daily_activity_summary_select_own" ON public.daily_activity_summary
  FOR SELECT
  USING (auth.uid() = user_id);

-- Needed even though every real write is an upsert: ON CONFLICT DO
-- UPDATE requires a SELECT policy to exist for the planner even when
-- no conflict occurs — the exact bug class found and fixed in
-- 0015_device_tokens_select_own.sql. Adding the SELECT policy above
-- FIRST avoids re-discovering that the hard way here.
CREATE POLICY "daily_activity_summary_insert_own" ON public.daily_activity_summary
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "daily_activity_summary_update_own" ON public.daily_activity_summary
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- No DELETE policy: sync only ever upserts (a day's totals only ever
-- grow within a day as more activity is read, and past days don't get
-- retroactively removed) — nothing in this project's flow ever needs
-- to delete a row here.
