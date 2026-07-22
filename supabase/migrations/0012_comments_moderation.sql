-- ============================================================
-- DoonWalkers — Phase 7: Comments & Basic Content Filtering
-- Migration: 0012_comments_moderation.sql
--
-- public.comments (table + RLS + denormalized user_name/user_avatar)
-- already exists and is already correct — see 0001_baseline_schema.sql
-- (table), 0002_role_policies.sql (comments_select/insert/update/delete),
-- 0003_field_level_guards.sql (is_visible admin-only trigger). Nothing
-- there changes in this migration.
--
-- This migration adds ONLY the content-filter blocklist:
--   1. public.comment_blocklist — admin-editable list of blocked terms,
--      a dedicated table rather than a public.settings row. settings
--      stores one value per key (org_name, contact_email, ...) — a
--      growing list of terms doesn't fit that shape, and cramming it
--      into a single comma-separated value means every add/remove
--      requires parsing/reserializing the whole string both to query
--      it in the trigger and to edit it via the dashboard. A dedicated
--      table makes each term its own row: trivial to query, and
--      admin-editable with zero code deploy by adding/removing rows in
--      the Table Editor, per the brief.
--   2. A BEFORE INSERT trigger on public.comments — the real
--      enforcement layer, same pattern as prevent_role_escalation
--      (0002) / prevent_payment_status_self_edit (0003).
--
-- WORD-BOUNDARY matching (Postgres `\m`/`\M` regex anchors), not naive
-- substring — a plain `comment ILIKE '%term%'` would false-positive on
-- any innocent word that merely CONTAINS a blocked term (blocking
-- "ass" would also catch "class", "assess", "assignment" — the classic
-- profanity-filter false-positive class). Word-boundary matching avoids
-- that specific failure mode. It does NOT solve every evasion: spacing
-- ("a s s"), misspelling, leetspeak, or non-English terms all still get
-- through — this is explicitly one layer, not a complete solution;
-- admin moderation (the hide/show control + moderation queue built in
-- the app layer) is the real backstop for everything this misses.
--
-- Scope note: the brief asked for a BEFORE INSERT trigger specifically.
-- This migration also adds an equivalent BEFORE UPDATE OF comment
-- trigger, which the brief didn't ask for — flagging the extension
-- rather than silently going beyond scope. Reasoning: comments_update
-- (0002) allows a user to update their own row's `comment` column (no
-- edit-comment UI exists yet, but RLS doesn't know that — a direct API
-- call could rewrite comment text post-insert and bypass an
-- INSERT-only filter entirely). Same function, one more trigger
-- registration, closes an obvious gap for free. Both triggers exempt
-- admin (same shape as every other admin-bypass check in this
-- project) — admin already has full moderation power over comments
-- regardless, so the filter would only ever get in their way.
-- ============================================================

-- ── Blocklist table ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.comment_blocklist (
  term        TEXT PRIMARY KEY,
  added_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.comment_blocklist ENABLE ROW LEVEL SECURITY;

-- Same public-read / admin-write shape as public.settings
-- (0002_role_policies.sql) — the client needs to read this list for
-- the pre-submit UX check (see comment_providers.dart), so it can't be
-- admin-only SELECT.
DROP POLICY IF EXISTS "comment_blocklist_select" ON public.comment_blocklist;
CREATE POLICY "comment_blocklist_select" ON public.comment_blocklist
  FOR SELECT
  USING (TRUE);

DROP POLICY IF EXISTS "comment_blocklist_insert_admin" ON public.comment_blocklist;
CREATE POLICY "comment_blocklist_insert_admin" ON public.comment_blocklist
  FOR INSERT
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "comment_blocklist_update_admin" ON public.comment_blocklist;
CREATE POLICY "comment_blocklist_update_admin" ON public.comment_blocklist
  FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "comment_blocklist_delete_admin" ON public.comment_blocklist;
CREATE POLICY "comment_blocklist_delete_admin" ON public.comment_blocklist
  FOR DELETE
  USING (public.is_admin());

-- Small starter list — general mild-to-moderate profanity, no slurs
-- targeting protected groups (those would need a different, more
-- careful treatment than a simple word filter). Expand via the
-- dashboard Table Editor — no deploy required.
INSERT INTO public.comment_blocklist (term) VALUES
  ('fuck'),
  ('shit'),
  ('bitch'),
  ('asshole'),
  ('bastard'),
  ('cunt')
ON CONFLICT (term) DO NOTHING;


-- ── Enforcement trigger ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.check_comment_blocklist()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF public.is_admin() THEN
    RETURN NEW;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.comment_blocklist
    WHERE NEW.comment ~* ('\m' || term || '\M')
  ) THEN
    -- Custom SQLSTATE (not the bare-RAISE default P0001, which several
    -- other triggers on this project also use) so the Dart client can
    -- match on error.code unambiguously rather than parsing message
    -- text — see CommentBlocklistException in comment.dart.
    RAISE EXCEPTION 'This comment contains inappropriate language and cannot be posted.'
      USING ERRCODE = 'DWB01';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_comment_insert_check_blocklist ON public.comments;
CREATE TRIGGER on_comment_insert_check_blocklist
  BEFORE INSERT ON public.comments
  FOR EACH ROW EXECUTE PROCEDURE public.check_comment_blocklist();

DROP TRIGGER IF EXISTS on_comment_update_check_blocklist ON public.comments;
CREATE TRIGGER on_comment_update_check_blocklist
  BEFORE UPDATE OF comment ON public.comments
  FOR EACH ROW EXECUTE PROCEDURE public.check_comment_blocklist();
