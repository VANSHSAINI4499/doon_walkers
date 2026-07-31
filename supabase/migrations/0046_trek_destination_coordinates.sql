-- ── Migration 0046: Trek Destination Coordinates ──────────────────
--
-- Adds destination geo-coordinates to treks so the Trip Tracking
-- feature (background arrival-detection) has something to navigate
-- to. Previously treks only carried a free-text `google_map_link`
-- URL, opened externally — no in-app tracking was possible against it.
--
-- All three columns are nullable: existing treks (and any admin who
-- doesn't set them) simply don't get a "Start Navigation" button on
-- Trek Detail — this is purely additive, no backfill required.

ALTER TABLE public.treks
  ADD COLUMN IF NOT EXISTS destination_name TEXT,
  ADD COLUMN IF NOT EXISTS destination_lat DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS destination_lng DOUBLE PRECISION;

-- Sanity bounds — guards against obviously-wrong data entry (e.g. a
-- swapped lat/lng pair) without being a real geo validation. Both
-- columns are set together in practice (admin form), so no CHECK
-- ties them to each other's nullness.
ALTER TABLE public.treks
  ADD CONSTRAINT treks_destination_lat_range
    CHECK (destination_lat IS NULL OR destination_lat BETWEEN -90 AND 90),
  ADD CONSTRAINT treks_destination_lng_range
    CHECK (destination_lng IS NULL OR destination_lng BETWEEN -180 AND 180);
