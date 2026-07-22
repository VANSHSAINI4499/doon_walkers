-- ============================================================
-- DoonWalkers — Version 2, Phase M1: Merchandise Image Storage
-- Migration: 0017_merch_images_storage.sql
--
-- A NEW bucket ('merch-images'), not a reuse of 'trek-covers' or
-- 'trek-gallery' — separate feature, separate bucket, same admin-
-- write/public-read shape as 0006_trek_covers_storage.sql.
--
-- Deliberately does NOT include "ALTER TABLE storage.objects ENABLE
-- ROW LEVEL SECURITY" — 0007_gallery_storage.sql's doc already
-- flagged why: that line caused a real "must be owner of table
-- objects" failure once before, since storage.objects is owned by
-- Supabase's internal supabase_storage_admin role, not the role
-- migrations run as. RLS is already ON for storage.objects by default
-- on every Supabase project; the policies below are sufficient alone.
--
-- Reuses public.is_admin() (0002_role_policies.sql) — same admin
-- check, different bucket.
-- ============================================================

-- ── Bucket ──────────────────────────────────────────────────────────
-- file_size_limit is in bytes (5 MiB, same as trek-covers — product
-- photos, no video). allowed_mime_types is enforced server-side by
-- Storage itself, independent of RLS.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'merch-images',
  'merch-images',
  TRUE,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ── Policies on storage.objects, scoped to this bucket ─────────────
DROP POLICY IF EXISTS "merch_images_select" ON storage.objects;
CREATE POLICY "merch_images_select" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'merch-images');

DROP POLICY IF EXISTS "merch_images_insert_admin" ON storage.objects;
CREATE POLICY "merch_images_insert_admin" ON storage.objects
  FOR INSERT
  WITH CHECK (bucket_id = 'merch-images' AND public.is_admin());

DROP POLICY IF EXISTS "merch_images_update_admin" ON storage.objects;
CREATE POLICY "merch_images_update_admin" ON storage.objects
  FOR UPDATE
  USING (bucket_id = 'merch-images' AND public.is_admin())
  WITH CHECK (bucket_id = 'merch-images' AND public.is_admin());

DROP POLICY IF EXISTS "merch_images_delete_admin" ON storage.objects;
CREATE POLICY "merch_images_delete_admin" ON storage.objects
  FOR DELETE
  USING (bucket_id = 'merch-images' AND public.is_admin());
