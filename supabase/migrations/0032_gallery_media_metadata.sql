-- ============================================================
-- DoonWalkers — Trek Media Gallery Rebuild
-- Migration: 0032_gallery_media_metadata.sql
--
-- Adds thumbnail_url (populated for videos only — a client-generated
-- JPEG frame; NULL for photos, which use media_url itself at a
-- downsized decode instead) and width/height (the media's, or for
-- video its thumbnail frame's, pixel dimensions — decoded client-side
-- at upload time) to public.gallery. Drives the new masonry gallery's
-- real per-tile aspect ratio instead of a uniform square grid.
--
-- No RLS changes needed: gallery_select / gallery_insert_admin /
-- gallery_update_admin / gallery_delete_admin (0002_role_policies.sql)
-- already cover every column on this table, new ones included.
--
-- Existing rows get NULL for all three — GalleryMedia.aspectRatio
-- falls back to 1.0 (square) for those client-side, so old rows keep
-- rendering rather than erroring.
-- ============================================================

ALTER TABLE public.gallery
  ADD COLUMN IF NOT EXISTS thumbnail_url TEXT,
  ADD COLUMN IF NOT EXISTS width  INTEGER,
  ADD COLUMN IF NOT EXISTS height INTEGER;
