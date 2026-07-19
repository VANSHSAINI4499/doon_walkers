-- ============================================================
-- DoonWalkers — Phase 1 Baseline Schema
-- Migration: 0001_baseline_schema.sql
--
-- Run this in the Supabase SQL Editor or via:
--   supabase db push
--
-- RLS is ON for every table.
-- Phase 1 policies are MINIMAL (read-only public + own-row).
-- Real role-based policies (admin / user / guest) land in Phase 2.
-- ============================================================

-- ── Extensions ───────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── Enum: user role ───────────────────────────────────────────────
-- Kept as a Postgres enum so invalid roles are impossible at DB level.
DO $$ BEGIN
  CREATE TYPE user_role AS ENUM ('guest', 'user', 'admin');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── Enum: trek difficulty ─────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE trek_difficulty AS ENUM ('easy', 'moderate', 'hard', 'extreme');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── Enum: media type ─────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE media_type AS ENUM ('photo', 'video');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── Enum: payment status ─────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE payment_status AS ENUM ('pending', 'paid', 'refunded', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── Enum: gender ─────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE gender_type AS ENUM ('male', 'female', 'other', 'prefer_not_to_say');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;


-- ════════════════════════════════════════════════════════════════
-- TABLE: users
-- Maps 1-to-1 with auth.users; populated via a trigger on signup.
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.users (
  id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name            TEXT NOT NULL DEFAULT '',
  email           TEXT NOT NULL,
  phone           TEXT,
  role            user_role NOT NULL DEFAULT 'user',
  profile_image   TEXT,          -- Supabase Storage URL
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Phase 1 placeholder policies (minimal, safe defaults)
-- Users can only read/update their own row.
-- Admins get full access — real admin check lands in Phase 2.
CREATE POLICY "users_select_own" ON public.users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "users_update_own" ON public.users
  FOR UPDATE USING (auth.uid() = id);

-- Service-role insert (used by the signup trigger — bypasses RLS).
-- No direct INSERT policy for anon/authenticated in Phase 1.


-- ════════════════════════════════════════════════════════════════
-- TABLE: treks
-- Trek content managed exclusively by admins (enforced in Phase 2).
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.treks (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title           TEXT NOT NULL,
  description     TEXT NOT NULL DEFAULT '',
  difficulty      trek_difficulty NOT NULL DEFAULT 'moderate',
  distance_km     NUMERIC(6, 2),          -- kilometres
  duration_days   INTEGER,
  altitude_m      INTEGER,                -- max altitude in metres
  best_season     TEXT,                   -- e.g. "Oct – Feb"
  things_to_carry TEXT,                   -- markdown / plain text
  google_map_link TEXT,
  cover_image     TEXT,                   -- Supabase Storage URL
  is_published    BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.treks ENABLE ROW LEVEL SECURITY;

-- Public read of published treks — guests and authenticated users.
CREATE POLICY "treks_select_published" ON public.treks
  FOR SELECT USING (is_published = TRUE);

-- Phase 1: no INSERT/UPDATE/DELETE for anyone (Phase 2 adds admin policy).


-- ════════════════════════════════════════════════════════════════
-- TABLE: gallery
-- Media associated with a trek. Upload restricted to admin (Phase 2).
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.gallery (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trek_id     UUID NOT NULL REFERENCES public.treks(id) ON DELETE CASCADE,
  media_url   TEXT NOT NULL,       -- Supabase Storage URL
  media_type  media_type NOT NULL DEFAULT 'photo',
  caption     TEXT,
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.gallery ENABLE ROW LEVEL SECURITY;

-- Public read — gallery is visible to everyone.
CREATE POLICY "gallery_select_all" ON public.gallery
  FOR SELECT USING (TRUE);

-- Phase 1: no INSERT/UPDATE/DELETE.


-- ════════════════════════════════════════════════════════════════
-- TABLE: comments
-- Users comment on treks. Admins can moderate (Phase 2).
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.comments (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trek_id     UUID NOT NULL REFERENCES public.treks(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  comment     TEXT NOT NULL,
  is_visible  BOOLEAN NOT NULL DEFAULT TRUE, -- moderation flag
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;

-- Public read of visible comments.
CREATE POLICY "comments_select_visible" ON public.comments
  FOR SELECT USING (is_visible = TRUE);

-- Phase 1: no INSERT/UPDATE/DELETE (Phase 2 adds user insert + admin moderation).


-- ════════════════════════════════════════════════════════════════
-- TABLE: registrations
-- Trek registrations by authenticated users.
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.registrations (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trek_id           UUID NOT NULL REFERENCES public.treks(id) ON DELETE RESTRICT,
  user_id           UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  emergency_contact TEXT,
  age               INTEGER CHECK (age > 0 AND age < 120),
  gender            gender_type,
  medical_notes     TEXT,
  payment_status    payment_status NOT NULL DEFAULT 'pending',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (trek_id, user_id)       -- one registration per user per trek
);

ALTER TABLE public.registrations ENABLE ROW LEVEL SECURITY;

-- Users can only see their own registrations.
CREATE POLICY "registrations_select_own" ON public.registrations
  FOR SELECT USING (auth.uid() = user_id);

-- Phase 1: no INSERT/UPDATE/DELETE (Phase 2 adds user insert + admin read-all).


-- ════════════════════════════════════════════════════════════════
-- TABLE: notifications
-- Broadcast notifications sent by admins.
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.notifications (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title       TEXT NOT NULL,
  body        TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Public read — all authenticated users can read notifications.
CREATE POLICY "notifications_select_all" ON public.notifications
  FOR SELECT USING (TRUE);

-- Phase 1: no INSERT/UPDATE/DELETE (Phase 2 adds admin-only write).


-- ════════════════════════════════════════════════════════════════
-- TABLE: settings
-- Community-level configuration: org info, contact, social links.
-- Designed for a single-org V1 but portable to multi-org later.
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.settings (
  key         TEXT PRIMARY KEY,   -- e.g. 'org_name', 'contact_email'
  value       TEXT NOT NULL,
  description TEXT,               -- human-readable label for admin UI
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;

-- Everyone can read settings (community info is public).
CREATE POLICY "settings_select_all" ON public.settings
  FOR SELECT USING (TRUE);

-- Phase 1: no INSERT/UPDATE/DELETE (Phase 2 adds admin-only write).


-- ════════════════════════════════════════════════════════════════
-- SEED: default settings rows
-- Portable — edit values in the admin UI once auth is in place.
-- ════════════════════════════════════════════════════════════════
INSERT INTO public.settings (key, value, description)
VALUES
  ('org_name',        'Doon Walkers',            'Organisation display name'),
  ('org_tagline',     'Explore the Himalayas with us', 'Tagline shown on home screen'),
  ('org_city',        'Dehradun',                'City'),
  ('org_state',       'Uttarakhand',             'State'),
  ('contact_email',   '',                        'Public contact email'),
  ('contact_phone',   '',                        'Public contact phone'),
  ('instagram_url',   '',                        'Instagram profile URL'),
  ('whatsapp_url',    '',                        'WhatsApp group invite link'),
  ('google_form_url', '',                        'Legacy Google Form URL (kept for redirect)')
ON CONFLICT (key) DO NOTHING;


-- ════════════════════════════════════════════════════════════════
-- TRIGGER: auto-create users row on auth signup
-- Runs as SECURITY DEFINER so it can bypass RLS on public.users.
-- ════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, email, name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', '')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Drop and recreate to be idempotent.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
