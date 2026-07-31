-- ── Migration 0047: Production Data Reset ──────────────────────────
--
-- One-time cleanup before real testers get access. Removes every
-- test/demo account and everything it owns, while preserving the
-- admin account (auth + profile + role + its own data), all app
-- configuration/master data (treks, challenges, achievement
-- definitions, merchandise catalog, settings, comment blocklist), and
-- the schema itself. This migration is DML only — no DDL.
--
-- Scope decision: the brief's requirement to preserve the admin's
-- Supabase Auth account (specifically) only makes sense as a carve-out
-- if other accounts' Auth records are otherwise being removed — so
-- this deletes the 6 non-admin accounts from auth.users itself, not
-- just their public.users profile rows.
--
-- Targets a fixed, reviewed list of user ids rather than a role-based
-- condition (`role <> 'admin'`) deliberately: a role-based WHERE
-- clause would also catch any real tester who signs up between this
-- migration being written and applied. Pinning to specific ids makes
-- this migration inert for anyone created after it was reviewed.
--
-- Idempotent: every statement is a DELETE keyed on a fixed id list —
-- running this again once the rows are gone simply deletes 0 rows.
--
-- Cascade note: public.users.id -> auth.users(id) is ON DELETE CASCADE,
-- and every other user-owned table cascades either from public.users
-- or directly from auth.users, EXCEPT public.notification_reads,
-- whose FK is ON DELETE NO ACTION — that table is emptied explicitly
-- below, before touching auth.users, or the whole statement would fail
-- with a foreign-key violation.

DO $$
DECLARE
  -- Admin account — never included in the list below. Verified via
  -- `SELECT id, email, role FROM public.users` before writing this
  -- migration: role = 'admin', the only admin row in the table.
  v_admin_id CONSTANT uuid := '90247be4-039e-4868-a6f8-23bdc2b912e4';

  -- The 6 non-admin test/demo accounts identified at review time.
  v_test_user_ids CONSTANT uuid[] := ARRAY[
    'd0abbade-89df-4976-8820-dde5ece21aa9', -- manjusaini8273@gmail.com
    '4c5a1948-cc71-4044-a87a-b0f19c9a4d4e', -- sunilsaini96340@gmail.com
    'bbd58bb8-e331-4397-8298-429f51c1b3b0', -- pranjalpundeer40@gmail.com
    'fc1d5d08-24ac-4a00-8793-20914ca0e85e', -- dograshubham333@gmail.com
    '5f5b4e14-7dc2-440a-8c88-5ee3b998c388', -- chaurasiaom671@gmail.com
    '22d7e564-10bd-4a3f-90e5-74f0fb09803b'  -- vanskumarsaini@gmail.com
  ];

BEGIN
  -- Safety guard: refuse to proceed if the admin id somehow ended up
  -- in the deletion list, or if the admin id no longer resolves to an
  -- admin (e.g. this migration were mistakenly reused on a different
  -- environment). Aborts the whole migration rather than deleting
  -- anything.
  IF v_admin_id = ANY (v_test_user_ids) THEN
    RAISE EXCEPTION 'Refusing to proceed: admin id is present in the deletion list';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.users WHERE id = v_admin_id AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Refusing to proceed: % is not an admin in this database', v_admin_id;
  END IF;

  -- 1. Payment-proof screenshots are NOT cleaned up here. Supabase
  --    enforces storage.protect_delete() on storage.objects, which
  --    rejects any raw SQL DELETE against it and requires going
  --    through the Storage API instead — a deliberate platform
  --    safety rail against orphaning the underlying blobs, and not
  --    something this migration should try to bypass. The 3 objects
  --    identified at review time (1 tied to a departing user's
  --    registration, 2 already-orphaned) need a follow-up cleanup via
  --    the Storage API/dashboard — see this migration's PR/summary.

  -- 2. notification_reads — ON DELETE NO ACTION, must go before
  --    auth.users or the cascade below fails.
  DELETE FROM public.notification_reads
  WHERE user_id = ANY (v_test_user_ids);

  -- 3. Deleting the Auth accounts cascades to public.users and, from
  --    there or directly, to every remaining user-owned table:
  --    registrations, comments, daily_activity_summary, device_tokens,
  --    merch_inquiries, user_wishlist, user_goals, user_points,
  --    points_ledger, user_achievements, challenge_enrollments,
  --    community_posts (+ post_likes/post_comments/post_bookmarks/
  --    post_media), and the Auth-internal tables (identities,
  --    sessions, refresh tokens, mfa factors, etc.).
  DELETE FROM auth.users
  WHERE id = ANY (v_test_user_ids);
END $$;
