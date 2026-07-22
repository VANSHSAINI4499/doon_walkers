-- ============================================================
-- DoonWalkers — Version 2, Phase M1: Merchandise Catalog
-- Migration: 0016_merchandise_catalog.sql
--
-- Three new tables:
--   products         — the catalog item itself.
--   product_variants — OPTIONAL per-size stock (e.g. T-shirt S/M/L/XL).
--                      A product with zero variant rows is a
--                      "one-size" item and uses products.stock_quantity
--                      directly; a product with one or more variant
--                      rows is treated as size-tracked, and
--                      products.stock_quantity is simply ignored for
--                      it (see Product.isInStock in the Dart entity).
--                      A separate table rather than a `sizes JSONB`
--                      column on products — mirrors the
--                      registrations/gallery one-to-many pattern
--                      already established in this project, and lets
--                      RLS/constraints (UNIQUE per size, stock >= 0)
--                      apply per-row instead of inside opaque JSON.
--   product_images   — one-to-many, mirrors public.gallery exactly
--                      (id, product_id, image_url, uploaded_at). NO
--                      separate "cover_image" column on products like
--                      treks has — merch product photography routinely
--                      needs multiple angles (front/back/logo
--                      close-up), so unlike a trek's single hero image
--                      the FIRST-uploaded product_images row (oldest
--                      uploaded_at) simply IS the cover/thumbnail,
--                      avoiding two separate upload flows for what's
--                      conceptually the same thing.
--
-- RLS shape mirrors treks_select exactly: `is_active = TRUE OR
-- is_admin()` on products, so a guest/member only ever sees active
-- (published) products while an admin's catalog view also includes
-- inactive drafts. product_variants/product_images gate through their
-- parent product's is_active via the same EXISTS-join pattern
-- 0008_gallery_select_publish_gate.sql already uses for gallery ->
-- treks. Stock (in vs. out) is NOT an RLS concern — it's a display-only
-- computed property (see Product.isInStock) so an active-but-sold-out
-- product stays browsable with an "Out of Stock" badge, exactly like
-- real e-commerce sites; hiding it via RLS would make that badge
-- impossible for a non-admin to ever see.
--
-- Reuses public.is_admin() (0002_role_policies.sql) — same admin
-- check, different tables.
-- ============================================================

-- ── Enum: product category ────────────────────────────────────────
-- A starter set covering typical trekking-club merch. Adding a new
-- category later is a simple `ALTER TYPE product_category ADD VALUE`
-- migration — same tradeoff already accepted for trek_difficulty/
-- media_type/payment_status/gender_type, kept for consistency rather
-- than a free-text column.
DO $$ BEGIN
  CREATE TYPE product_category AS ENUM (
    'apparel', 'headwear', 'drinkware', 'accessories', 'stickers', 'other'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;


-- ════════════════════════════════════════════════════════════════
-- TABLE: products
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.products (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name            TEXT NOT NULL,
  description     TEXT NOT NULL DEFAULT '',
  price           NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
  category        product_category NOT NULL DEFAULT 'other',
  -- Meaningful only for a product with NO product_variants rows — see
  -- this file's top doc. NOT the source of truth once variants exist.
  stock_quantity  INTEGER NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
  -- Defaults FALSE, same "draft until explicitly published" contract
  -- as treks.is_published — a newly created product isn't visible to
  -- anyone but an admin until deliberately activated.
  is_active       BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "products_select" ON public.products
  FOR SELECT
  USING (is_active = TRUE OR public.is_admin());

CREATE POLICY "products_insert_admin" ON public.products
  FOR INSERT
  WITH CHECK (public.is_admin());

CREATE POLICY "products_update_admin" ON public.products
  FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "products_delete_admin" ON public.products
  FOR DELETE
  USING (public.is_admin());


-- ════════════════════════════════════════════════════════════════
-- TABLE: product_variants
-- Optional per-size stock. Zero rows for a product = no sizes (use
-- products.stock_quantity instead) — see this file's top doc.
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.product_variants (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id      UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  size            TEXT NOT NULL,
  stock_quantity  INTEGER NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
  UNIQUE (product_id, size)
);

ALTER TABLE public.product_variants ENABLE ROW LEVEL SECURITY;

-- Joined through the parent product's is_active, same shape as
-- gallery_select (0008_gallery_select_publish_gate.sql).
CREATE POLICY "product_variants_select" ON public.product_variants
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.products p
      WHERE p.id = product_variants.product_id
      AND (p.is_active = TRUE OR public.is_admin())
    )
  );

CREATE POLICY "product_variants_insert_admin" ON public.product_variants
  FOR INSERT
  WITH CHECK (public.is_admin());

CREATE POLICY "product_variants_update_admin" ON public.product_variants
  FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "product_variants_delete_admin" ON public.product_variants
  FOR DELETE
  USING (public.is_admin());


-- ════════════════════════════════════════════════════════════════
-- TABLE: product_images
-- One-to-many product photos — mirrors public.gallery's shape. The
-- oldest row (uploaded_at ascending) is treated as the cover/thumbnail
-- by the app; there is no separate cover_image column (see top doc).
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.product_images (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id    UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  image_url     TEXT NOT NULL,
  uploaded_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.product_images ENABLE ROW LEVEL SECURITY;

CREATE POLICY "product_images_select" ON public.product_images
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.products p
      WHERE p.id = product_images.product_id
      AND (p.is_active = TRUE OR public.is_admin())
    )
  );

CREATE POLICY "product_images_insert_admin" ON public.product_images
  FOR INSERT
  WITH CHECK (public.is_admin());

CREATE POLICY "product_images_update_admin" ON public.product_images
  FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "product_images_delete_admin" ON public.product_images
  FOR DELETE
  USING (public.is_admin());
