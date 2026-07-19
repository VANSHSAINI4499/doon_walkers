-- ============================================================
-- DoonWalkers — Phase 2: Role Policies & Denormalization
-- Migration: 0002_role_policies.sql
--
-- Enforces strict role-based access control per AGENTS.md rules:
--   - Admin: full CRUD on all tables.
--   - Registered User: read public content, write own registrations,
--     comments, and profile only. CANNOT self-escalate role.
--   - Guest: read-only public content. No writes or profile queries.
--
-- Also denormalizes display_name/avatar into `comments` so public queries
-- never need SELECT access to `public.users` (protecting email & phone PII).
-- ============================================================

-- ── 1. Helper Functions (SECURITY DEFINER to avoid recursion) ─────────────

-- Checks if active user is an admin by checking `role` in `public.users`.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

-- Checks if active user is a registered user or admin (can comment/register).
CREATE OR REPLACE FUNCTION public.is_registered_user_or_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND role IN ('user', 'admin')
  );
$$;

-- ── 2. Role Escalation Prevention Trigger ─────────────────────────────────
-- Prevents non-admins from altering their own `role` column via SQL or REST.
CREATE OR REPLACE FUNCTION public.prevent_role_escalation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.role <> OLD.role AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Permission denied: Only administrators can modify user roles.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_user_update_check_role ON public.users;
CREATE TRIGGER on_user_update_check_role
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE PROCEDURE public.prevent_role_escalation();


-- ── 3. Denormalize Commenter Display Info ──────────────────────────────────
-- Adds display fields directly to `comments` so we don't leak `users` PII.
ALTER TABLE public.comments ADD COLUMN IF NOT EXISTS user_name TEXT NOT NULL DEFAULT '';
ALTER TABLE public.comments ADD COLUMN IF NOT EXISTS user_avatar TEXT;

CREATE OR REPLACE FUNCTION public.populate_comment_user_info()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  SELECT name, profile_image INTO NEW.user_name, NEW.user_avatar
  FROM public.users
  WHERE id = NEW.user_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_comment_insert_populate_user ON public.comments;
CREATE TRIGGER on_comment_insert_populate_user
  BEFORE INSERT OR UPDATE OF user_id ON public.comments
  FOR EACH ROW EXECUTE PROCEDURE public.populate_comment_user_info();


-- ── 4. RLS Policies per Table ──────────────────────────────────────────────

-- ════════════════════════════════════════════════════════════════
-- TABLE: users
-- SELECT restricted to own row or admin to protect PII (email, phone).
-- ════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "users_select_own" ON public.users;
DROP POLICY IF EXISTS "users_update_own" ON public.users;

CREATE POLICY "users_select_own_or_admin" ON public.users
  FOR SELECT
  USING (auth.uid() = id OR public.is_admin());

CREATE POLICY "users_update_own_or_admin" ON public.users
  FOR UPDATE
  USING (auth.uid() = id OR public.is_admin())
  WITH CHECK (auth.uid() = id OR public.is_admin());

CREATE POLICY "users_delete_admin" ON public.users
  FOR DELETE
  USING (public.is_admin());


-- ════════════════════════════════════════════════════════════════
-- TABLE: treks
-- Admin full CRUD; public sees published treks only.
-- ════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "treks_select_published" ON public.treks;

CREATE POLICY "treks_select" ON public.treks
  FOR SELECT
  USING (is_published = TRUE OR public.is_admin());

CREATE POLICY "treks_insert_admin" ON public.treks
  FOR INSERT
  WITH CHECK (public.is_admin());

CREATE POLICY "treks_update_admin" ON public.treks
  FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "treks_delete_admin" ON public.treks
  FOR DELETE
  USING (public.is_admin());


-- ════════════════════════════════════════════════════════════════
-- TABLE: gallery
-- Admin full CRUD; everyone can read gallery.
-- ════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "gallery_select_all" ON public.gallery;

CREATE POLICY "gallery_select" ON public.gallery
  FOR SELECT
  USING (TRUE);

CREATE POLICY "gallery_insert_admin" ON public.gallery
  FOR INSERT
  WITH CHECK (public.is_admin());

CREATE POLICY "gallery_update_admin" ON public.gallery
  FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "gallery_delete_admin" ON public.gallery
  FOR DELETE
  USING (public.is_admin());


-- ════════════════════════════════════════════════════════════════
-- TABLE: comments
-- Public reads visible comments; registered/admins insert; own/admin update/delete.
-- ════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "comments_select_visible" ON public.comments;

CREATE POLICY "comments_select" ON public.comments
  FOR SELECT
  USING (is_visible = TRUE OR public.is_admin());

CREATE POLICY "comments_insert" ON public.comments
  FOR INSERT
  WITH CHECK (auth.uid() = user_id AND public.is_registered_user_or_admin());

CREATE POLICY "comments_update" ON public.comments
  FOR UPDATE
  USING (auth.uid() = user_id OR public.is_admin())
  WITH CHECK (auth.uid() = user_id OR public.is_admin());

CREATE POLICY "comments_delete" ON public.comments
  FOR DELETE
  USING (auth.uid() = user_id OR public.is_admin());


-- ════════════════════════════════════════════════════════════════
-- TABLE: registrations
-- Own row or admin read/write; registered users insert own registration.
-- ════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "registrations_select_own" ON public.registrations;

CREATE POLICY "registrations_select" ON public.registrations
  FOR SELECT
  USING (auth.uid() = user_id OR public.is_admin());

CREATE POLICY "registrations_insert" ON public.registrations
  FOR INSERT
  WITH CHECK (auth.uid() = user_id AND public.is_registered_user_or_admin());

CREATE POLICY "registrations_update" ON public.registrations
  FOR UPDATE
  USING (auth.uid() = user_id OR public.is_admin())
  WITH CHECK (auth.uid() = user_id OR public.is_admin());

CREATE POLICY "registrations_delete" ON public.registrations
  FOR DELETE
  USING (auth.uid() = user_id OR public.is_admin());


-- ════════════════════════════════════════════════════════════════
-- TABLE: notifications
-- Authenticated users read; admin writes.
-- ════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "notifications_select_all" ON public.notifications;

CREATE POLICY "notifications_select" ON public.notifications
  FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "notifications_insert_admin" ON public.notifications
  FOR INSERT
  WITH CHECK (public.is_admin());

CREATE POLICY "notifications_update_admin" ON public.notifications
  FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "notifications_delete_admin" ON public.notifications
  FOR DELETE
  USING (public.is_admin());


-- ════════════════════════════════════════════════════════════════
-- TABLE: settings
-- Everyone reads community info; admin writes.
-- ════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "settings_select_all" ON public.settings;

CREATE POLICY "settings_select" ON public.settings
  FOR SELECT
  USING (TRUE);

CREATE POLICY "settings_insert_admin" ON public.settings
  FOR INSERT
  WITH CHECK (public.is_admin());

CREATE POLICY "settings_update_admin" ON public.settings
  FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "settings_delete_admin" ON public.settings
  FOR DELETE
  USING (public.is_admin());
