-- ============================================================
-- DoonWalkers — Phase 5: Gallery Media Storage
-- Migration: 0007_gallery_storage.sql
--
-- public.gallery itself (table + RLS) already exists and is already
-- correct — see 0001_baseline_schema.sql (table) and
-- 0002_role_policies.sql (gallery_select / gallery_insert_admin /
-- gallery_update_admin / gallery_delete_admin: public read, admin
-- full write). Audited live against the running project before writing
-- this file; nothing to change there. This migration only adds the
-- Storage bucket gallery media actually lives in.
--
-- Same admin-write/public-read shape as 0006_trek_covers_storage.sql,
-- with two deliberate differences:
--
--   1. NO "ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY" here.
--      0006 included that line as a "defensive no-op" and it caused a
--      real failure last phase ("must be owner of table objects") —
--      storage.objects is owned by Supabase's internal `supabase_storage_admin`
--      role, not the role migrations run as, so re-running ENABLE RLS
--      on it is a permissions error, not a safe no-op. RLS is already
--      ON for storage.objects by default on every Supabase project;
--      the policies below are sufficient on their own.
--
--   2. This bucket carries video as well as photos, so the file size
--      limit is much larger (50 MiB vs 5 MiB for trek-covers) and
--      allowed_mime_types includes common video containers alongside
--      the existing image types.
--
-- Reuses public.is_admin() (0002_role_policies.sql) — same admin check,
-- different bucket.
-- ============================================================

-- ── Bucket ──────────────────────────────────────────────────────────
-- file_size_limit is in bytes (50 MiB). allowed_mime_types is enforced
-- server-side by Storage itself, independent of RLS — a second layer
-- against a compromised/misbehaving client uploading something that
-- isn't actually an image or video.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'trek-gallery',
  'trek-gallery',
  TRUE,
  52428800,
  ARRAY[
    'image/jpeg', 'image/png', 'image/webp',
    'video/mp4', 'video/quicktime', 'video/webm'
  ]
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ── Policies on storage.objects, scoped to this bucket ─────────────
-- Deliberately does NOT touch the trek-covers policies from Phase 4 —
-- these are scoped to bucket_id = 'trek-gallery' only.
DROP POLICY IF EXISTS "trek_gallery_select" ON storage.objects;
CREATE POLICY "trek_gallery_select" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'trek-gallery');

DROP POLICY IF EXISTS "trek_gallery_insert_admin" ON storage.objects;
CREATE POLICY "trek_gallery_insert_admin" ON storage.objects
  FOR INSERT
  WITH CHECK (bucket_id = 'trek-gallery' AND public.is_admin());

DROP POLICY IF EXISTS "trek_gallery_update_admin" ON storage.objects;
CREATE POLICY "trek_gallery_update_admin" ON storage.objects
  FOR UPDATE
  USING (bucket_id = 'trek-gallery' AND public.is_admin())
  WITH CHECK (bucket_id = 'trek-gallery' AND public.is_admin());

DROP POLICY IF EXISTS "trek_gallery_delete_admin" ON storage.objects;
CREATE POLICY "trek_gallery_delete_admin" ON storage.objects
  FOR DELETE
  USING (bucket_id = 'trek-gallery' AND public.is_admin());
