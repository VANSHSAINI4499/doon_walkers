-- ============================================================
-- DoonWalkers — Version 2, Phase M2: Wishlist
-- Migration: 0019_user_wishlist.sql
--
-- Purely personal preference data, not business-critical — per the
-- brief, deliberately NO admin visibility at all (not even an
-- `is_admin()` OR-clause), unlike almost every other table in this
-- project. A user's wishlist is theirs alone; nothing here is a
-- moderation/fulfilment surface an admin needs to see.
--
-- Synthetic `id` PK + `UNIQUE (user_id, product_id)` rather than a
-- composite PK — mirrors `registrations`' `UNIQUE (trek_id, user_id)`
-- shape exactly. No UPDATE policy at all: a wishlist row has nothing
-- to edit in place — toggling is add (INSERT) or remove (DELETE),
-- never a change to an existing row's fields.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.user_wishlist (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  product_id  UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, product_id)
);

ALTER TABLE public.user_wishlist ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_wishlist_select_own" ON public.user_wishlist
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "user_wishlist_insert_own" ON public.user_wishlist
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_wishlist_delete_own" ON public.user_wishlist
  FOR DELETE
  USING (auth.uid() = user_id);
