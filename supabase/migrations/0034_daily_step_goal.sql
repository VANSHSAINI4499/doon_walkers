-- ============================================================
-- DoonWalkers — Redesign 2.0, Phase 11: Activity dashboard
-- Migration: 0034_daily_step_goal.sql
--
-- The Activity tab's Day/Week/Month views all measure progress against
-- a goal, and no goal concept existed. Stored as a column on
-- public.users rather than a new user_settings table for the same
-- reason show_on_leaderboard was (0025_leaderboard.sql): the users row
-- is already fetched on launch by currentUserProvider, so the goal
-- costs no extra query, and the EXISTING users_update_own_or_admin
-- policy already makes it self-editable — no new RLS needed.
--
-- ONE stored goal, deliberately. Weekly and monthly targets are derived
-- in the client (goal x 7, goal x days-in-month) rather than stored
-- separately: three columns would drift apart and need three edit
-- affordances for what is one user intention.
--
-- 6,500 is the default: a moderate, achievable daily walking target for
-- a community walking group, not the folk-wisdom 10,000 (which is a
-- 1960s Japanese pedometer marketing figure, and demoralising as a
-- default for someone starting out).
-- ============================================================

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS daily_step_goal INTEGER NOT NULL DEFAULT 6500;

-- Guard against a nonsense goal reaching the progress maths, where it
-- would produce a divide-by-zero or an absurd percentage. Added
-- separately from the column so re-running this migration on a table
-- that already has the column still installs the constraint.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'users_daily_step_goal_sane'
  ) THEN
    ALTER TABLE public.users
      ADD CONSTRAINT users_daily_step_goal_sane
      CHECK (daily_step_goal BETWEEN 500 AND 100000);
  END IF;
END $$;
