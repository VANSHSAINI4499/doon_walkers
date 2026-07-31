-- ── Migration 0049: Automatic Payment for Free Treks ────────────────
--
-- Problem: registrations.payment_status defaults to 'pending' at INSERT
-- regardless of the trek's fee (RegistrationModel.toInsertJson never
-- sets it — see that file's own doc for why: the column is admin-
-- writable only). For a free trek (treks.registration_fee = 0) there is
-- no payment to verify, so every registration sat at 'pending' until an
-- admin manually flipped it to 'paid' — busywork with no real decision
-- behind it.
--
-- Fix: a BEFORE INSERT/UPDATE trigger on public.registrations that
-- coerces payment_status from 'pending' to 'paid' whenever the row's
-- trek is free. Enforced in the database, not the client, so the
-- invariant holds no matter which code path creates or touches the
-- row (the app's own insert, a future admin tool, a direct SQL fix) —
-- "consistently handled throughout," per the brief.
--
-- Deliberately narrow: only ever coerces 'pending' -> 'paid'. Admin-set
-- 'cancelled' (cancel_trek_registration RPC) and 'refunded' pass
-- through completely untouched, so cancelling a free-trek registration
-- keeps working exactly as it does today — this is not a "free treks
-- can only ever be paid" lock, just "never sits at pending."
--
-- Does not affect any counting logic: every RPC that reads
-- payment_status (challenge progress, streaks, leaderboard, attendance,
-- capacity) already only excludes 'cancelled' — none of them
-- special-case 'pending' vs 'paid' — so this migration only changes
-- the stored value and the admin workflow around it, never eligibility.
--
-- Idempotent: CREATE OR REPLACE + DROP TRIGGER IF EXISTS for the
-- trigger itself; the backfill UPDATE only ever touches rows still at
-- 'pending', so re-running this migration is a no-op the second time.

-- ── 1. Trigger function ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.enforce_free_trek_paid_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.payment_status = 'pending' THEN
    IF EXISTS (
      SELECT 1 FROM public.treks
      WHERE id = NEW.trek_id AND registration_fee = 0
    ) THEN
      NEW.payment_status := 'paid';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_registration_insert_free_trek_paid ON public.registrations;
CREATE TRIGGER on_registration_insert_free_trek_paid
  BEFORE INSERT ON public.registrations
  FOR EACH ROW EXECUTE PROCEDURE public.enforce_free_trek_paid_status();

DROP TRIGGER IF EXISTS on_registration_update_free_trek_paid ON public.registrations;
CREATE TRIGGER on_registration_update_free_trek_paid
  BEFORE UPDATE ON public.registrations
  FOR EACH ROW EXECUTE PROCEDURE public.enforce_free_trek_paid_status();

-- ── 2. Backfill existing rows ────────────────────────────────────────
-- Requirement 6: convert existing free-trek registrations sitting at
-- 'pending' to 'paid'. This UPDATE goes through
-- on_registration_update_check_payment_status
-- (0003_field_level_guards.sql / redefined in 0041_trek_capacity.sql),
-- which rejects any payment_status change from a caller that isn't
-- is_admin() — and a migration runs with no authenticated session at
-- all, so auth.uid() is null and is_admin() is false. Disabling that
-- one trigger for the duration of this single statement is the same
-- bypass technique cancel_trek_registration already relies on (via
-- app.cancelling_registration) for its own legitimate system write.
ALTER TABLE public.registrations DISABLE TRIGGER on_registration_update_check_payment_status;

UPDATE public.registrations r
SET payment_status = 'paid'
FROM public.treks t
WHERE r.trek_id = t.id
  AND t.registration_fee = 0
  AND r.payment_status = 'pending';

ALTER TABLE public.registrations ENABLE TRIGGER on_registration_update_check_payment_status;
