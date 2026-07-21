-- ============================================================
-- DoonWalkers — Phase 7 Part C: Fee-Based Registration + Payment Verification
-- Migration: 0011_payment_verification.sql
--
-- Three additions:
--   1. registration_fee / payment_qr_code on public.treks.
--   2. payment_screenshot_url on public.registrations — where the
--      member's uploaded payment proof lives, for admin to review
--      before marking payment_status = 'paid'.
--   3. A NEW, PRIVATE storage bucket `payment-proofs` — the first
--      genuinely private bucket in this project. trek-covers and
--      trek-gallery are both public=true by design; a payment
--      screenshot is personal financial evidence and must never be
--      readable by anyone except its owner and admins.
--
-- payment_qr_code does NOT get a new bucket — it reuses the existing
-- public trek-covers bucket (admin-write, public-read), same as
-- cover_image, since a QR code is meant to be publicly visible to
-- anyone paying. Only the member's screenshot needs to be private.
--
-- ── Object path / ownership design ──────────────────────────────────
-- Objects are stored at `{registration_id}/{filename}`, NOT
-- `{user_id}/{filename}`. This lets both SELECT and INSERT policies
-- join back to public.registrations and check genuine row ownership
-- (r.user_id = auth.uid()), rather than only checking "this uploader
-- owns this folder" independent of any real registration existing.
-- Requires the app to create the registration row FIRST, THEN upload
-- the screenshot, THEN UPDATE payment_screenshot_url — mirroring the
-- existing createTrek-then-uploadCoverImage-then-update pattern in
-- trek_repository_impl.dart.
--
-- Verified live against the running project (not just on paper) via
-- MCP role-impersonation before this file was written:
--   - bucket public flag is false, not just RLS-gated.
--   - owning user can INSERT/SELECT their own proof.
--   - a non-owning authenticated user is REJECTED on INSERT and sees
--     zero rows on SELECT (confirmed via row count, not an empty-table
--     coincidence — same query as the owner returns 1 row).
--   - admin can SELECT any proof (needed for the review screen).
-- ============================================================

-- ── public.treks additions ──────────────────────────────────────────
ALTER TABLE public.treks
  ADD COLUMN registration_fee numeric NOT NULL DEFAULT 0,
  ADD COLUMN payment_qr_code text;

COMMENT ON COLUMN public.treks.registration_fee IS
  'Amount a member must pay to register. 0 = free trek, no payment UI shown at all.';
COMMENT ON COLUMN public.treks.payment_qr_code IS
  'Public URL of the admin-uploaded QR code image, stored in the existing public trek-covers bucket. Null when registration_fee = 0.';

-- ── public.registrations addition ───────────────────────────────────
ALTER TABLE public.registrations
  ADD COLUMN payment_screenshot_url text;

COMMENT ON COLUMN public.registrations.payment_screenshot_url IS
  'Path of the member''s uploaded payment-proof screenshot in the private payment-proofs bucket. Null for free-trek registrations and briefly during paid-trek registration (row created before the upload completes).';

-- ── Storage bucket: payment-proofs (PRIVATE) ────────────────────────
-- public = false is the point of this bucket — do not flip this.
-- There is no anonymous /storage/v1/object/public/... URL for this
-- bucket at all; every read goes through the SELECT policy below.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'payment-proofs',
  'payment-proofs',
  FALSE,
  5242880, -- 5 MiB — a screenshot, not a video
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ── Policies on storage.objects, scoped to this bucket ──────────────
-- No "ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY" — 0007's
-- migration already established why: storage.objects is owned by
-- supabase_storage_admin, re-running ENABLE RLS on it errors ("must be
-- owner of table objects"). RLS is already ON by default for
-- storage.objects on every Supabase project.

-- SELECT: the registration's owning user, or admin. Deliberately NOT
-- "any authenticated user" — that would leak one member's payment
-- proof to every other signed-in member.
DROP POLICY IF EXISTS "payment_proofs_select" ON storage.objects;
CREATE POLICY "payment_proofs_select" ON storage.objects
  FOR SELECT
  USING (
    bucket_id = 'payment-proofs'
    AND (
      public.is_admin()
      OR EXISTS (
        SELECT 1 FROM public.registrations r
        WHERE r.id::text = (storage.foldername(name))[1]
          AND r.user_id = auth.uid()
      )
    )
  );

-- INSERT: same ownership check via the registrations join — the
-- uploader must own the registration the path's folder segment names.
DROP POLICY IF EXISTS "payment_proofs_insert" ON storage.objects;
CREATE POLICY "payment_proofs_insert" ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'payment-proofs'
    AND (
      public.is_admin()
      OR EXISTS (
        SELECT 1 FROM public.registrations r
        WHERE r.id::text = (storage.foldername(name))[1]
          AND r.user_id = auth.uid()
      )
    )
  );

-- DELETE: same ownership shape — supports cleanup on registration
-- cancellation, mirroring the best-effort storage cleanup already done
-- for trek covers / gallery media on delete.
DROP POLICY IF EXISTS "payment_proofs_delete" ON storage.objects;
CREATE POLICY "payment_proofs_delete" ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'payment-proofs'
    AND (
      public.is_admin()
      OR EXISTS (
        SELECT 1 FROM public.registrations r
        WHERE r.id::text = (storage.foldername(name))[1]
          AND r.user_id = auth.uid()
      )
    )
  );

-- No UPDATE policy: a screenshot is uploaded once per registration and
-- never replaced in place — a user who uploaded the wrong file
-- cancels (DELETE) and re-registers rather than overwriting evidence
-- admin may already be reviewing.
