-- ── Migration 0048: Delete Trek Master Data ─────────────────────────
--
-- Follow-up to 0047_production_data_reset: the 7 existing treks were
-- themselves test/demo content ("Test 1", "Test 2", "treck 35",
-- "test qr", "ruppes", "om babu", "doon walkers" — not real listings),
-- so they're being cleared too, ahead of real trek data being entered
-- for testers. This migration is DML only — no DDL; the treks table,
-- its columns, RLS policies, and RPCs are untouched, only its rows.
--
-- Idempotent: DELETE FROM public.treks with no WHERE clause simply
-- deletes 0 rows once the table is already empty.
--
-- Cascade note: registrations.trek_id -> treks(id) is ON DELETE
-- RESTRICT, which would normally block this — but 0047 already
-- emptied public.registrations, so that's moot here. Everything else
-- referencing treks(id) cascades cleanly:
--   comments        ON DELETE CASCADE
--   gallery          ON DELETE CASCADE
--   trek_checkin_tokens ON DELETE CASCADE
--   community_posts.trek_id ON DELETE SET NULL (0 rows currently)
--
-- Not handled here (same platform limitation as 0047): the actual
-- image/video files in the trek-covers and trek-gallery storage
-- buckets are NOT deleted — Supabase's storage.protect_delete()
-- trigger rejects raw SQL DELETE against storage.objects and requires
-- the Storage API instead. Every object in both buckets is trek-
-- scoped (folder = trek id), and every trek is being removed here, so
-- all of it becomes orphaned and needs a follow-up Storage API/
-- dashboard cleanup: trek-covers (12 objects), trek-gallery (25
-- objects).

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.registrations LIMIT 1) THEN
    RAISE EXCEPTION 'Refusing to proceed: public.registrations is not empty — trek_id has an ON DELETE RESTRICT constraint that would fail, and any remaining registration likely belongs to a real user this migration should not touch.';
  END IF;

  DELETE FROM public.treks;
END $$;
