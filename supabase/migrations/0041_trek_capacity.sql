-- ============================================================
-- DoonWalkers — Redesign 2.0, Phase 26: Capacity & Cancellation
-- Migration: 0041_trek_capacity.sql
-- ============================================================

-- ── 1. SCHEMA CHANGES TO REGISTRATIONS ───────────────────────────────────
-- Add cancellation_reason and cancelled_at columns to table public.registrations
ALTER TABLE public.registrations 
  ADD COLUMN IF NOT EXISTS cancellation_reason TEXT,
  ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;

-- ── 2. RPC: get_trek_spots_left ──────────────────────────────────────────
-- Returns the remaining spots for a trek. Null when max_participants is null.
CREATE OR REPLACE FUNCTION public.get_trek_spots_left(p_trek_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
  RETURN public.get_spots_remaining(p_trek_id);
END;
$$;

-- ── 3. UPDATE trigger prevent_payment_status_self_edit ──────────────────
-- Modifies prevent_payment_status_self_edit() trigger function to allow a
-- regular user to change payment_status to 'cancelled' if done through the
-- cancel_trek_registration RPC which sets app.cancelling_registration to 'true'.
CREATE OR REPLACE FUNCTION public.prevent_payment_status_self_edit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.payment_status <> OLD.payment_status AND NOT public.is_admin() THEN
    IF NEW.payment_status = 'cancelled' AND current_setting('app.cancelling_registration', true) = 'true' THEN
      RETURN NEW;
    END IF;
    RAISE EXCEPTION 'Permission denied: Only administrators can change payment_status.';
  END IF;
  RETURN NEW;
END;
$$;

-- ── 4. RPC: cancel_trek_registration ─────────────────────────────────────
-- Updates payment_status to 'cancelled', records reason and cancelled_at.
-- Verifies the caller is the owner of the registration or an admin.
CREATE OR REPLACE FUNCTION public.cancel_trek_registration(
  p_registration_id UUID,
  p_reason TEXT
)
RETURNS public.registrations
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_registration public.registrations;
BEGIN
  -- Verify ownership or admin
  IF NOT EXISTS (
    SELECT 1 FROM public.registrations 
    WHERE id = p_registration_id 
      AND (user_id = auth.uid() OR public.is_admin())
  ) THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
  END IF;

  -- Set session configuration parameter to bypass trigger
  PERFORM set_config('app.cancelling_registration', 'true', true);

  UPDATE public.registrations
  SET payment_status = 'cancelled',
      cancellation_reason = p_reason,
      cancelled_at = NOW()
  WHERE id = p_registration_id
  RETURNING * INTO v_registration;

  RETURN v_registration;
END;
$$;
