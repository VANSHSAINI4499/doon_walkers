-- ============================================================
-- DoonWalkers — Phase QR-2: Trek Check-in Verification
-- Migration: 0030_trek_checkin_verify.sql
--
-- Two additions, both approved by design review before being applied:
--
--   1. A guard trigger, prevent_checked_in_at_self_edit, on
--      registrations.checked_in_at (added in 0029_trek_checkin_qr.sql).
--      registrations_update RLS (own row or admin) already permits a
--      member to update their OWN registration row — that's correct
--      for emergency_contact/medical_notes, but wrong for
--      checked_in_at: a member could otherwise PATCH their own row
--      directly and set it, skipping the token check, the window
--      check, and the already-checked-in check entirely. Same problem
--      class prevent_payment_status_self_edit/
--      prevent_visibility_self_edit already solve for their columns.
--
--      Unlike those two, the trusted writer here isn't "an admin" —
--      it's one specific RPC, called by an ordinary member. The
--      existing is_admin()-only guard shape doesn't fit, so this
--      trigger adds a second escape hatch: a transaction-local GUC
--      (`doonwalkers.checkin_verified`) that ONLY
--      verify_trek_checkin() ever sets, immediately before its own
--      UPDATE, via `set_config(..., true)` (true = local to the
--      current transaction). This is airtight, not just obscure:
--        - `is_local := true` means the flag evaporates at the end of
--          the transaction. PostgREST runs every individual HTTP
--          request in its own transaction, so a flag set inside one
--          request can never be "carried over" into a separate
--          direct-UPDATE request.
--        - set_config() itself isn't reachable by a client at all —
--          PostgREST only exposes functions from the `public` schema
--          (Supabase's configured API schema); set_config lives in
--          pg_catalog, which is never exposed as /rest/v1/rpc/....
--      So the only code that can ever make this flag true is our own
--      plpgsql running server-side inside verify_trek_checkin.
--
--   2. verify_trek_checkin(p_trek_id uuid, p_token text) — the
--      SECURITY DEFINER RPC the check-in scanner screen calls. Reads
--      auth.uid() internally; never accepts a user id from the
--      client. Checks, in order, each with its own custom SQLSTATE
--      (mirroring check_comment_blocklist's DWB01 pattern from
--      0012_comments_moderation.sql, matched client-side in
--      registration_repository_impl.dart the same way
--      comment_repository_impl.dart already matches DWB01):
--        DWC01 — caller has no registration for this trek
--        DWC02 — p_token doesn't match this trek's real token in
--                trek_checkin_tokens (or isn't a valid UUID at all —
--                a stranger's unrelated QR code must fail the same
--                way, not crash the call)
--        DWC03 — trek has no trek_date/trek_start_time set at all
--        DWC04 — now() is before the window opens
--        DWC05 — now() is after the window closes
--        DWC06 — checked_in_at is already set
--      p_trek_id is trusted app-supplied context (the screen is
--      always opened from a specific Trek Detail page) — only
--      p_token is the untrusted, user-scanned value. Comparing it
--      against trek_checkin_tokens scoped to THIS p_trek_id is what
--      makes a QR from a different trek fail (DWC02), not just an
--      unscoped "is this token valid for anything" check.
--
--      trek_checkin_tokens is admin-only-readable
--      (trek_checkin_tokens_select_admin), so reading the real token
--      to compare requires SECURITY DEFINER — same as the UPDATE
--      needing the GUC escape hatch above. The real token value is
--      never returned to the client in any response, on success or
--      failure — only a match/no-match outcome — so QR-1's
--      confidentiality guarantee for the token itself is unchanged.
--
--      Timezone handling: trek_date/trek_start_time are bare local
--      wall-clock values with no stored timezone (0010_trek_
--      scheduling.sql's rationale). now() is an unambiguous UTC
--      instant. This app is single-organization and India-only
--      (AGENTS.md; AppConstants.orgCity/orgState), so "local" always
--      means Asia/Kolkata (IST) — the window is computed by
--      explicitly anchoring the trek's wall-clock time to that zone
--      before comparing against now(), which is what makes this
--      match what QR-1's admin screen computes client-side (naive
--      DateTime math on a device whose local zone is IST). Getting
--      this wrong would silently shift the real window by 5.5 hours
--      from what the app displays.
-- ============================================================

-- ── Guard trigger: registrations.checked_in_at ───────────────────
CREATE OR REPLACE FUNCTION public.prevent_checked_in_at_self_edit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.checked_in_at IS DISTINCT FROM OLD.checked_in_at
     AND NOT public.is_admin()
     AND current_setting('doonwalkers.checkin_verified', true) IS DISTINCT FROM 'true'
  THEN
    RAISE EXCEPTION 'Permission denied: checked_in_at can only be set by the check-in verification RPC.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_registration_update_check_checked_in_at ON public.registrations;
CREATE TRIGGER on_registration_update_check_checked_in_at
  BEFORE UPDATE ON public.registrations
  FOR EACH ROW EXECUTE FUNCTION public.prevent_checked_in_at_self_edit();

-- ── Verification RPC ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.verify_trek_checkin(p_trek_id uuid, p_token text)
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_registration_id uuid;
  v_already_checked_in timestamptz;
  v_scanned_token uuid;
  v_actual_token uuid;
  v_trek_date date;
  v_trek_start_time time;
  v_window_start timestamptz;
  v_window_end timestamptz;
  v_now timestamptz := now();
  v_checked_in_at timestamptz;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'You need to be signed in to do that.';
  END IF;

  -- 1. Registered for this trek at all?
  SELECT id, checked_in_at INTO v_registration_id, v_already_checked_in
  FROM public.registrations
  WHERE trek_id = p_trek_id AND user_id = v_user_id;

  IF v_registration_id IS NULL THEN
    RAISE EXCEPTION 'You are not registered for this trek.' USING ERRCODE = 'DWC01';
  END IF;

  -- 2. Does the scanned value match THIS trek's real token? A
  -- malformed/unrelated scan must fail the same way as a genuinely
  -- wrong token, not raise a raw cast error.
  BEGIN
    v_scanned_token := p_token::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    RAISE EXCEPTION 'This QR code is not valid for this trek.' USING ERRCODE = 'DWC02';
  END;

  SELECT token INTO v_actual_token
  FROM public.trek_checkin_tokens
  WHERE trek_id = p_trek_id;

  IF v_actual_token IS NULL OR v_actual_token IS DISTINCT FROM v_scanned_token THEN
    RAISE EXCEPTION 'This QR code is not valid for this trek.' USING ERRCODE = 'DWC02';
  END IF;

  -- 3/4. Is now() inside the ±3 hour window around the scheduled start?
  SELECT trek_date, trek_start_time INTO v_trek_date, v_trek_start_time
  FROM public.treks
  WHERE id = p_trek_id;

  IF v_trek_date IS NULL OR v_trek_start_time IS NULL THEN
    RAISE EXCEPTION 'Check-in is not available for this trek.' USING ERRCODE = 'DWC03';
  END IF;

  v_window_start := ((v_trek_date + v_trek_start_time) AT TIME ZONE 'Asia/Kolkata') - interval '3 hours';
  v_window_end := ((v_trek_date + v_trek_start_time) AT TIME ZONE 'Asia/Kolkata') + interval '3 hours';

  IF v_now < v_window_start THEN
    RAISE EXCEPTION 'Check-in has not opened yet.' USING ERRCODE = 'DWC04';
  END IF;
  IF v_now > v_window_end THEN
    RAISE EXCEPTION 'Check-in window has closed.' USING ERRCODE = 'DWC05';
  END IF;

  -- 5. Not already checked in.
  IF v_already_checked_in IS NOT NULL THEN
    RAISE EXCEPTION 'You are already checked in.' USING ERRCODE = 'DWC06';
  END IF;

  -- All checks passed — the only place doonwalkers.checkin_verified
  -- is ever set to 'true' (see this migration's top doc for why that
  -- makes the guard trigger above airtight).
  v_checked_in_at := v_now;
  PERFORM set_config('doonwalkers.checkin_verified', 'true', true);
  UPDATE public.registrations SET checked_in_at = v_checked_in_at WHERE id = v_registration_id;

  RETURN v_checked_in_at;
END;
$$;
