-- ============================================================
-- DoonWalkers — Phase 5 follow-up: Gallery Publish Gate
-- Migration: 0008_gallery_select_publish_gate.sql
--
-- Closes a pre-existing RLS gap flagged during the Phase 5 audit:
-- gallery_select (0002_role_policies.sql) was USING (TRUE) — anyone
-- querying public.gallery directly could read media attached to an
-- unpublished draft trek, even though the trek's own detail page is
-- correctly hidden from non-admins by treks_select.
--
-- Replaces it with the same is_published-or-admin shape treks_select
-- already uses, joined through trek_id — so a draft trek's media is
-- now exactly as hidden as the trek itself.
-- ============================================================

DROP POLICY IF EXISTS "gallery_select" ON public.gallery;

CREATE POLICY "gallery_select" ON public.gallery
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.treks t
      WHERE t.id = gallery.trek_id
      AND (t.is_published = TRUE OR public.is_admin())
    )
  );
