-- ============================================================
-- DoonWalkers — Version 2, Phase M2: Buy Now Inquiry Flow
-- Migration: 0018_merch_inquiries.sql
--
-- "Buy Now" is an inquiry-to-admin flow, not real checkout (that's a
-- later phase) — a member submits interest (product, optional size,
-- quantity, optional note) and an admin follows up manually. Mirrors
-- the registrations table's shape: a user-owned row an admin manages.
--
-- variant_id is nullable (a product with no sizes has nothing to
-- reference) and ON DELETE SET NULL rather than CASCADE — deleting a
-- size later shouldn't delete the historical inquiry that mentioned
-- it, just drop the now-dangling size reference.
--
-- RLS shape:
--   - select: own row OR admin (mirrors registrations_select).
--   - insert: own row AND is_registered_user_or_admin() (mirrors
--     registrations_insert exactly — same "must actually be a
--     registered user, not just any authenticated session" guard).
--   - update: ADMIN ONLY, not "own row OR admin" — this is the
--     deliberate difference from registrations/comments. Those tables
--     give the owning user a broad UPDATE policy (so they can edit
--     their own legitimate fields) and then need a field-level BEFORE
--     UPDATE trigger to carve out ONE admin-only column
--     (payment_status / is_visible) from that otherwise-broad grant.
--     Here, a regular user has NO update path onto their own row at
--     all — there is nothing for them to legitimately self-edit after
--     submitting (no "edit my note" flow in this phase), so the
--     policy itself is admin-only across every column. No same-row/
--     different-field bypass exists to guard against, so no
--     equivalent field-level trigger is needed — plain RLS already
--     closes it completely.
--   - delete: admin only (cleanup/spam removal). Note: this phase does
--     NOT give a user their own DELETE/cancel path on an inquiry they
--     submitted (unlike registrations, which supports self-cancel by
--     deleting the row) — out of the explicit scope for this phase.
-- ============================================================

DO $$ BEGIN
  CREATE TYPE merch_inquiry_status AS ENUM (
    'pending', 'contacted', 'fulfilled', 'cancelled'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.merch_inquiries (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  product_id  UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  variant_id  UUID REFERENCES public.product_variants(id) ON DELETE SET NULL,
  quantity    INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
  note        TEXT,
  status      merch_inquiry_status NOT NULL DEFAULT 'pending',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.merch_inquiries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "merch_inquiries_select" ON public.merch_inquiries
  FOR SELECT
  USING (auth.uid() = user_id OR public.is_admin());

CREATE POLICY "merch_inquiries_insert" ON public.merch_inquiries
  FOR INSERT
  WITH CHECK (auth.uid() = user_id AND public.is_registered_user_or_admin());

CREATE POLICY "merch_inquiries_update_admin" ON public.merch_inquiries
  FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "merch_inquiries_delete_admin" ON public.merch_inquiries
  FOR DELETE
  USING (public.is_admin());
