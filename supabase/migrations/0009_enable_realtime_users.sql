-- ============================================================
-- DoonWalkers — Bugfix: RealtimeSubscribeException on public.users
-- Migration: 0009_enable_realtime_users.sql
--
-- currentUserProvider (core/providers/supabase_provider.dart) streams
-- public.users so isAdminProvider reflects a role change (promote/
-- revoke admin) immediately rather than only on next app launch —
-- this matters because it gates a hard permission boundary (AGENTS.md:
-- admin-only write access). The table was never added to the
-- supabase_realtime publication, so every .stream() subscription
-- against it failed with RealtimeSubscribeException(channelError),
-- crashing Profile and the Admin Panel.
--
-- treks/gallery/settings had the same gap but are being converted off
-- .stream() onto one-shot fetch + manual refresh instead of also being
-- added here — see Phase report for the real-time-vs-one-shot call.
-- ============================================================

ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
