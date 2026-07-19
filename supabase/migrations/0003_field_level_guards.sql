-- ============================================================
-- DoonWalkers — Phase 2 Follow-up: Field-Level Write Guards
-- Migration: 0003_field_level_guards.sql
--
-- 0002's RLS policies grant UPDATE on a user's own row for
-- `registrations`, `comments`, and `users` — but "own row" isn't the
-- same as "every column of my own row." Three columns must stay
-- admin-only even on a row its owner is otherwise allowed to update:
--   - registrations.payment_status — admin verifies payment, not the payer
--   - comments.is_visible          — admin moderation flag
--   - users.email                  — mirrors auth.users.email, which only
--                                     Supabase Auth's own update flow changes
--
-- Follows the same BEFORE UPDATE trigger pattern as
-- public.prevent_role_escalation() in 0002 (0001_baseline_schema.sql /
-- 0002_role_policies.sql lines 47-64): reject the change unless the
-- caller is_admin(), otherwise let the update proceed unchanged.
-- ============================================================

-- ── registrations.payment_status ───────────────────────────────────
CREATE OR REPLACE FUNCTION public.prevent_payment_status_self_edit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.payment_status <> OLD.payment_status AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Permission denied: Only administrators can change payment_status.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_registration_update_check_payment_status ON public.registrations;
CREATE TRIGGER on_registration_update_check_payment_status
  BEFORE UPDATE ON public.registrations
  FOR EACH ROW EXECUTE PROCEDURE public.prevent_payment_status_self_edit();


-- ── comments.is_visible ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.prevent_visibility_self_edit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.is_visible <> OLD.is_visible AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Permission denied: Only administrators can moderate comments (is_visible).';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_comment_update_check_visibility ON public.comments;
CREATE TRIGGER on_comment_update_check_visibility
  BEFORE UPDATE ON public.comments
  FOR EACH ROW EXECUTE PROCEDURE public.prevent_visibility_self_edit();


-- ── users.email ──────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.prevent_email_self_edit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.email <> OLD.email AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Permission denied: email is managed by Supabase Auth, not directly editable.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_user_update_check_email ON public.users;
CREATE TRIGGER on_user_update_check_email
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE PROCEDURE public.prevent_email_self_edit();
