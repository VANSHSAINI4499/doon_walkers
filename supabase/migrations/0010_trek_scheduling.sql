-- ============================================================
-- DoonWalkers — Phase 7 Part A: Trek Scheduling Field
-- Migration: 0010_trek_scheduling.sql
--
-- Adds the trek date this batch's "upcoming" (Part E's sort/badge) and
-- "completed"/"attended" (Part D's profile stats) logic is computed
-- from everywhere else. Nullable and no default — existing treks have
-- no scheduled date until an admin sets one via the trek form; nothing
-- downstream should assume it's always present.
--
-- DATE rather than TIMESTAMPTZ: a trek is scheduled by calendar day
-- (paired with the existing duration_days for multi-day treks), not a
-- specific time of day, so there's no timezone-of-day ambiguity to
-- carry around.
-- ============================================================

ALTER TABLE public.treks
  ADD COLUMN trek_date date;

COMMENT ON COLUMN public.treks.trek_date IS
  'Scheduled start date of the trek. Nullable — unset for treks created before this column existed, until an admin edits them. "Upcoming" = trek_date >= current_date; "completed" = trek_date < current_date.';
