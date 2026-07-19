-- ============================================================
-- DoonWalkers — Phase 3: About Page Content Seed
-- Migration: 0004_about_content.sql
--
-- Extends public.settings (created in 0001_baseline_schema.sql) with
-- the long-form content rows the About screen needs. Same table, same
-- RLS (public SELECT, admin-only INSERT/UPDATE/DELETE, from
-- 0002_role_policies.sql) — no schema change, no new policies required.
--
-- Values are placeholder copy. Real copy gets entered through the
-- admin settings editor once it exists (Phase 9); until then, edit
-- these rows directly via the Supabase dashboard Table Editor.
-- ============================================================

INSERT INTO public.settings (key, value, description)
VALUES
  ('community_story',
   'Add your community''s story here — how Doon Walkers started and what it has grown into.',
   'About page: Our Story section'),
  ('founder_message',
   'Add a personal message from the founder(s) here.',
   'About page: Founder''s message'),
  ('vision',
   'Add your community''s vision statement here.',
   'About page: Vision'),
  ('mission',
   'Add your community''s mission statement here.',
   'About page: Mission'),
  ('community_rules',
   'Add trek and community rules / code of conduct here.',
   'About page: Community rules'),
  ('why_join',
   'Add reasons trekkers should join Doon Walkers here.',
   'About page: Why join us')
ON CONFLICT (key) DO NOTHING;
