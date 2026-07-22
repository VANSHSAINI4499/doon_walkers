-- ============================================================
-- DoonWalkers — Phase 8: Push Notification Device Tokens
-- Migration: 0015_device_tokens_select_own.sql
--
-- Fixes every device-token upsert failing with 42501 ("new row
-- violates row-level security policy for table device_tokens").
--
-- Root cause: 0014_device_tokens.sql deliberately shipped with NO
-- SELECT policy, reasoning that raw FCM tokens are credential-shaped
-- and no client should ever read another user's token. True as far
-- as it goes — but Postgres's RLS requires a SELECT policy to exist
-- for `INSERT ... ON CONFLICT (...) DO UPDATE` to be plannable at
-- all, even when the conflict branch is never actually taken. The
-- Flutter client's upsertToken() uses exactly that
-- (`.upsert(..., onConflict: 'fcm_token')`), so with zero SELECT
-- policy every single insert — first row or not — was rejected before
-- Postgres ever got to evaluate the (correct) INSERT policy's
-- WITH CHECK. Verified live via role-impersonation: the plain INSERT
-- passes, the identical statement with ON CONFLICT DO UPDATE fails,
-- and adding this SELECT policy fixes it — confirming this is a
-- generic Postgres/RLS/upsert interaction, not anything specific to
-- this table's name (0014's migration note theorized an "MCP safety
-- guardrail" based on the table name; that was a misdiagnosis of this
-- same underlying mechanism).
--
-- Scoped to own rows only (auth.uid() = user_id), so the original
-- security intent — no client can ever read another user's token —
-- is unchanged. A user selecting their own token leaks nothing: the
-- device already holds that exact token locally from
-- FirebaseMessaging.instance.getToken().
-- ============================================================

CREATE POLICY "device_tokens_select_own" ON public.device_tokens
  FOR SELECT
  USING (auth.uid() = user_id);
