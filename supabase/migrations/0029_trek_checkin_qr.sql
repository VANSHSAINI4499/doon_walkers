-- ============================================================
-- DoonWalkers — Phase QR-1: Trek Check-in QR — Schema & Admin Display
-- Migration: 0029_trek_checkin_qr.sql
--
-- Three additions, laying the schema groundwork for QR-based trek
-- attendance check-in. This migration is schema + admin-display ONLY —
-- the member-facing scan flow and the verification RPC that actually
-- writes `checked_in_at` are Phase QR-2; "attended" computation
-- (wherever it's read today) is untouched — that's Phase QR-3.
--
--   1. treks.trek_start_time — the scheduled time of day (paired with
--      the existing trek_date) an admin sets so the app can tell
--      whether "now" falls inside the check-in window.
--
--   2. A NEW table, trek_checkin_tokens, NOT a new column on treks —
--      this is deliberate. treks_select (0002_role_policies.sql) is
--      `is_published = TRUE OR is_admin()`, i.e. any guest can SELECT
--      any published trek row. RLS is ROW-level only — it cannot hide
--      one column while allowing the rest of a row through. A
--      `checkin_token` column added directly to treks would therefore
--      leak to every guest and member via the exact same `select *`
--      the public Trek Library/Detail screens already run, regardless
--      of any policy written for it. Splitting the token into its own
--      table, with its own RLS and NO select policy for anything but
--      is_admin(), makes that leak structurally impossible rather than
--      relying on remembering to exclude a column from something.
--      One row per trek (trek_id is both PK and FK), auto-populated by
--      a trigger on trek insert — there is no admin-facing "generate a
--      token" action in this phase, and deliberately no UPDATE/DELETE
--      policy either (token rotation is out of scope here).
--
--   3. registrations.checked_in_at — where Phase QR-2's verification
--      RPC will eventually write. Left ungoverned by any extra
--      trigger/policy in THIS migration on purpose: the existing
--      registrations_update policy (own-or-admin) already covers it
--      exactly like every other column on the row, and the right
--      write-side guard (self-service scan vs. admin-operated scan)
--      depends on a design decision — whose device actually performs
--      the scan — that Phase QR-2 makes, not this one. Guessing that
--      shape now risks building the wrong guard and redoing it.
--      Nothing in the app reads or writes this column yet.
--
-- Verified live against the running project (not just on paper) via
-- MCP role-impersonation after this file was applied:
--   - checkin_token is unreachable through any `select` on treks —
--     it was never a column there to begin with.
--   - trek_checkin_tokens returns zero rows to an impersonated
--     non-admin member (same query returns the row for an admin).
-- ============================================================

-- ── public.treks addition ────────────────────────────────────────
ALTER TABLE public.treks
  ADD COLUMN trek_start_time time;

COMMENT ON COLUMN public.treks.trek_start_time IS
  'Scheduled start time of day, paired with trek_date. Nullable — unset until an admin sets it via the trek form. Combined with trek_date, drives the check-in QR''s open/closed window (Phase QR-1, Flutter-side: trek_checkin_qr_screen.dart) and, from Phase QR-2 on, the verification RPC''s own window check.';

-- ── public.registrations addition ────────────────────────────────
ALTER TABLE public.registrations
  ADD COLUMN checked_in_at timestamptz;

COMMENT ON COLUMN public.registrations.checked_in_at IS
  'Set by the Phase QR-2 verification RPC when a member''s check-in QR scan is accepted. NULL = not checked in. No write guard added in Phase QR-1 (see this migration''s top doc) — governed by the existing registrations_update policy (own-or-admin) until QR-2 defines the real write path.';

-- ── NEW table: trek_checkin_tokens ───────────────────────────────
-- One row per trek, auto-created on trek insert. See top doc for why
-- this is a separate table rather than a column on treks.
CREATE TABLE IF NOT EXISTS public.trek_checkin_tokens (
  trek_id     UUID PRIMARY KEY REFERENCES public.treks(id) ON DELETE CASCADE,
  token       UUID NOT NULL UNIQUE DEFAULT uuid_generate_v4(),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.trek_checkin_tokens ENABLE ROW LEVEL SECURITY;

-- Admin-only read — this IS the "displayed to admin" access path (the
-- Check-in QR screen selects straight from this table). No policy at
-- all for INSERT/UPDATE/DELETE: rows are only ever written by the
-- SECURITY DEFINER trigger below, which (as the table owner) bypasses
-- RLS entirely, so no client-facing write policy is needed or wanted.
CREATE POLICY "trek_checkin_tokens_select_admin" ON public.trek_checkin_tokens
  FOR SELECT
  USING (public.is_admin());

-- Auto-generates a token the moment a trek is created. SECURITY
-- DEFINER so the INSERT it performs runs as the function owner
-- (bypasses this table's own default-deny RLS) — the same pattern
-- public.handle_new_user() already uses to insert into public.users
-- from an auth.users trigger, with no INSERT policy needed there either.
CREATE OR REPLACE FUNCTION public.generate_trek_checkin_token()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.trek_checkin_tokens (trek_id) VALUES (NEW.id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_trek_insert_generate_checkin_token ON public.treks;
CREATE TRIGGER on_trek_insert_generate_checkin_token
  AFTER INSERT ON public.treks
  FOR EACH ROW EXECUTE FUNCTION public.generate_trek_checkin_token();

-- Backfill: every trek that already existed before this migration gets
-- a token too, so the admin display screen works for pre-existing
-- treks and not just ones created from here on.
INSERT INTO public.trek_checkin_tokens (trek_id)
SELECT id FROM public.treks
ON CONFLICT (trek_id) DO NOTHING;
