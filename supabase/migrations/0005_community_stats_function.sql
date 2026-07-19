-- ============================================================
-- DoonWalkers — Phase 3: Community Statistics Function
-- Migration: 0005_community_stats_function.sql
--
-- Home's "Community Statistics" section needs aggregate counts (member
-- count, published trek count, registration count) visible to guests
-- too. public.users' RLS is deliberately locked to own-row-or-admin
-- (0002_role_policies.sql) to protect email/phone PII, so a guest or
-- regular user cannot COUNT(*) it directly through PostgREST — RLS
-- filters every row out first, so the aggregate silently comes back as
-- 0 instead of erroring. Same applies to registrations (own-row-only).
--
-- get_community_stats() is SECURITY DEFINER so it reads the real
-- tables directly (bypassing RLS internally — same pattern as
-- public.is_admin() in 0002), but only ever returns pre-aggregated
-- numbers: no individual rows, no email/phone/medical_notes, no way to
-- single out a specific user or registration.
--
-- Note: current schema (0001) has no trek "completed" concept — treks
-- have no date/status field distinguishing past from upcoming — so
-- this deliberately does NOT expose a "treks completed" stat as named
-- in the original brief. published_trek_count (treks currently live)
-- is used instead. Add a proper schedule/status column to `treks` in
-- the Phase 4 trek-library migration if a real "completed" count is
-- wanted later.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_community_stats()
RETURNS TABLE (
  member_count          BIGINT,
  published_trek_count  BIGINT,
  registration_count    BIGINT
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT
    (SELECT COUNT(*) FROM public.users)                           AS member_count,
    (SELECT COUNT(*) FROM public.treks WHERE is_published = TRUE) AS published_trek_count,
    (SELECT COUNT(*) FROM public.registrations)                   AS registration_count;
$$;

-- Belt-and-suspenders: explicitly control who can call this via PostgREST
-- RPC rather than relying on Postgres's default PUBLIC execute grant.
-- Every other SECURITY DEFINER helper so far (is_admin(), etc.) is only
-- ever invoked indirectly as part of RLS policy evaluation; this one is
-- called directly from the client, so its grants are made explicit.
REVOKE ALL ON FUNCTION public.get_community_stats() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_community_stats() TO anon, authenticated;
