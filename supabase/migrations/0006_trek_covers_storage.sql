-- ============================================================
-- DoonWalkers — Phase 4: Trek Cover Image Storage
-- Migration: 0006_trek_covers_storage.sql
--
-- Cover images are the one thing in Phase 4 that isn't just a Postgres
-- row — they live in Supabase Storage. Storage access control is a
-- DIFFERENT mechanism from ordinary table RLS:
--   - Objects live in storage.objects, one row per uploaded file, with
--     a bucket_id and a name (the object path/key).
--   - RLS is already enabled on storage.objects globally by every
--     Supabase project by default; policies here just add rules scoped
--     to this bucket via `bucket_id = 'trek-covers'`.
--   - A bucket's own `public` flag (set at bucket creation) is what
--     makes the *anonymous* `/storage/v1/object/public/...` URL work
--     without an Authorization header — that's the path the app's
--     Image.network(coverImage) calls actually use. The SELECT policy
--     below additionally covers the *authenticated* Storage API
--     surface (.list()/.download() through the SDK), which goes
--     through RLS regardless of the bucket's public flag.
--   - Upload/replace/delete (.uploadBinary()/.remove()) always go
--     through the authenticated API and are gated by the INSERT/
--     UPDATE/DELETE policies below — this is what actually stops a
--     non-admin from writing to the bucket, not just the app hiding
--     the upload button.
--
-- Reuses public.is_admin() (0002_role_policies.sql) rather than
-- duplicating the admin check — same semantics, different table.
-- ============================================================

-- ── Bucket ──────────────────────────────────────────────────────────
-- file_size_limit is in bytes (5 MiB). allowed_mime_types is enforced
-- server-side by Storage itself, independent of RLS — a second layer
-- against a compromised/misbehaving client uploading something that
-- isn't actually an image.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'trek-covers',
  'trek-covers',
  TRUE,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Defensive — RLS is on by default for storage.objects on every
-- Supabase project, but this is a no-op if already enabled, so it
-- costs nothing to make the migration self-contained.
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- ── Policies on storage.objects, scoped to this bucket ─────────────
DROP POLICY IF EXISTS "trek_covers_select" ON storage.objects;
CREATE POLICY "trek_covers_select" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'trek-covers');

DROP POLICY IF EXISTS "trek_covers_insert_admin" ON storage.objects;
CREATE POLICY "trek_covers_insert_admin" ON storage.objects
  FOR INSERT
  WITH CHECK (bucket_id = 'trek-covers' AND public.is_admin());

DROP POLICY IF EXISTS "trek_covers_update_admin" ON storage.objects;
CREATE POLICY "trek_covers_update_admin" ON storage.objects
  FOR UPDATE
  USING (bucket_id = 'trek-covers' AND public.is_admin())
  WITH CHECK (bucket_id = 'trek-covers' AND public.is_admin());

DROP POLICY IF EXISTS "trek_covers_delete_admin" ON storage.objects;
CREATE POLICY "trek_covers_delete_admin" ON storage.objects
  FOR DELETE
  USING (bucket_id = 'trek-covers' AND public.is_admin());
