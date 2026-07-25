# DoonWalkers — Project Reference

> **This is a living reference document, not a spec.** It describes current reality as of the verification pass on 2026-07-25 — actual code inspected, actual live Supabase project queried (tables, RLS, functions, triggers, storage, Edge Functions). It is not a plan, not a backlog, and not guaranteed to stay accurate as the app evolves. Regenerate it periodically rather than hand-editing it to keep it in sync.

---

## Platform Scope

**This app is built for ANDROID ONLY, right now.** There is no iOS build, no iOS-specific health/fitness code, and no Apple Health integration — only Health Connect (Android).

Verified:
- `android/app/src/main/AndroidManifest.xml` declares Health Connect permissions (`READ_STEPS`, `READ_DISTANCE`, `READ_TOTAL_CALORIES_BURNED`), the `ACTION_SHOW_PERMISSIONS_RATIONALE` intent, and a `<queries>` visibility entry for `com.google.android.apps.healthdata` (the Health Connect app).
- `ios/` is a stock, unmodified Flutter template — no `NSHealthShareUsageDescription`, no HealthKit entitlements, no iOS-specific configuration of any kind.
- `lib/features/activity/presentation/providers/activity_providers.dart:18-21` always wires `HealthConnectProvider()`. A doc comment on that provider mentions a hypothetical future `Platform.isIOS ? AppleHealthProvider() : ...` split — **no `AppleHealthProvider` class exists anywhere in the repo** (zero matches on a full grep). It is a comment describing a possible future extension point, not real code, and should not be read as partial iOS support.

If you see anything elsewhere implying iOS readiness, it's aspirational commentary, not shipped capability.

---

## Tech Stack

| Layer | Technology | Notes |
|---|---|---|
| Frontend | Flutter | Feature-first, Clean-Architecture-ish (`data/domain/presentation` per feature) |
| State management | Riverpod (`flutter_riverpod`, `riverpod_generator`) | |
| Navigation | GoRouter | Central `redirect` callback in `lib/core/router/app_router.dart` enforces auth + role gating |
| Backend | Supabase — Postgres, Auth, Storage, Edge Functions | Live project `tbpebbfchqudtwqzfvxh` (ap-northeast-1, Postgres 17.6) |
| Push notifications | Firebase Cloud Messaging (`firebase_core`, `firebase_messaging`, `flutter_local_notifications`) | ✅ Confirmed live end-to-end (see Notifications below) |
| Fitness data | Health Connect (Android), via the `health` Flutter package | Android-only, see Platform Scope |
| Phone OTP | MSG91 OTP Widget SDK (`sendotp_flutter_sdk`) + a Supabase Edge Function for server-side verification | ✅ Confirmed live — all 4 live users have `phone_verified = true` |
| Auth (social) | Google Sign-In (`google_sign_in` v6, pinned) → Supabase `signInWithIdToken` | ✅ Confirmed live — 2 of 4 live users have a `google` identity |

---

## Feature Inventory

### Auth & Roles
- ✅ Email/password sign-up and sign-in — live (2 users via `email` provider in `auth.identities`).
- ✅ Google Sign-In (native picker → `signInWithIdToken`) — live (2 users via `google` identity).
- ✅ Phone/OTP verification — MSG91 widget drives send/resend/verify client-side; the `verify-phone-token` Edge Function is the **only** code path allowed to flip `phone_verified`, enforced server-side by the `on_user_update_check_phone_verified` DB trigger, not just app-side convention. Live: all 4 users verified.
- ✅ Forgot-password flow — email form → `resetPasswordForEmail` → confirmation state. No dead ends.
- ✅ Role-based route gating — `app_router.dart`'s `redirect` callback bounces guests to `/sign-in` off protected routes, and bounces non-admins off any admin route.
- ✅ RLS enforced as defense-in-depth behind the UI gating — `is_admin()` / `is_registered_user_or_admin()` SQL functions back the policies on every table (17/17 tables have RLS enabled).
- ⚠️ There is no standalone `/admin` dashboard route — admin screens are inlined onto their normal feature screens (e.g. trek edit lives at `/trek-library/:id/edit`). A few admin screens (registrations roster, comment moderation) are reachable only via direct/programmatic navigation, not linked from a central admin hub.
- ⚠️ Promoting a user to `admin` has no in-app UI anywhere — it's a direct-SQL/dashboard-only operation today.

### Home & Community
- ✅ Home screen (redesigned): hero header pulling tagline from `settings`, a `CommunityStatsSection` backed by the live `get_community_stats()` RPC, an About section sourced from `settings`, and a guest-only "Join Community" CTA.
- ⚠️ The `settings` table is live and wired (15 rows), but most of the About-page content is still placeholder text: `mission`, `vision`, `community_story`, `founder_message`, and `why_join` all literally contain "Add your community's ... here." `contact_email`, `contact_phone`, `instagram_url`, and `whatsapp_url` are all empty strings. Only `org_name` ("Doon Walkers"), `org_city` ("Dehradun"), `org_state` ("Uttarakhand"), and `org_tagline` are populated. This is a content gap, not a functionality gap.

### Trek Management
- ✅ Full CRUD via a single shared `AdminTrekFormScreen` (add/edit modes): title, description, difficulty, distance/duration/altitude, best season, things-to-carry, Google Maps link, cover-image upload, registration fee, and fee-conditional QR-code upload.
- ✅ Publish/draft (`is_published`) and scheduling (`trek_date`, with upcoming-vs-completed derived from it) are both live and wired.
- ✅ Built on the new design system's shared `core/widgets/admin_form.dart` — not legacy styling.

### Registration System
- ✅ Free-trek flow: age / gender / emergency contact / medical notes — no payment UI shown at all when `registration_fee = 0`.
- ✅ Fee-based flow: same form plus a required payment-screenshot upload to the private `payment-proofs` storage bucket.
- ✅ `payment_status` is admin-locked at the database level — the `prevent_payment_status_self_edit` trigger rejects any non-admin write to that column, so "only an admin can mark paid" is a hard DB rule, not just a UI convention.
- ✅ Self-cancellation is genuinely permitted: `registrations_delete` RLS policy is `auth.uid() = user_id OR is_admin()`, and the UI exposes it (`trek_register_button.dart`, `my_registrations_section.dart`).
- ✅ Admin verification screens exist: `admin_registrations_screen.dart`, `admin_registration_detail_screen.dart`, `admin_trek_registrations_screen.dart`, `admin_trek_picker_screen.dart`.

### Gallery & Media
- ✅ Per-trek photo/video gallery grid, embedded in the trek detail screen.
- ✅ Video playback genuinely wired via `video_player` + `chewie` (`video_player_screen.dart`) — a real Chewie controller against a network URL, not a stub.
- ✅ Admin upload (photo **and** video) via `gallery_upload_sheet.dart`, matching the live `trek-gallery` bucket's rules (public, 50 MB limit, jpeg/png/webp/mp4/mov/webm).
- ✅ Publish gating is live: the `gallery_select` RLS policy joins to `treks.is_published`, so an unpublished trek's media is exactly as hidden as the trek itself.
- ✅ Optional captions, stored and rendered.
- ⚠️ Styling: gallery screens are among the least migrated to the new design system (see UI/Design System below).

### Comments & Moderation
- ✅ Posting and display, wired to `comment_providers.dart`.
- ✅ Content blocklist is live and enforced at the database layer: `comment_blocklist` holds 403 seeded terms; a `BEFORE INSERT`/`BEFORE UPDATE OF comment` trigger regex-matches (word-boundary, case-insensitive) against it and **rejects the entire write** with a custom SQLSTATE (`DWB01`) — it does not silently censor. Admins are exempt. The app surfaces this rejection to the user as a specific error, not a generic failure.
- ✅ Two layers of moderation UI: inline hide/show/delete on each comment at the trek page, plus a dedicated `comment_moderation_screen.dart` that queues currently-hidden comments (there is no separate "flagged" concept).
- ✅ Blocklist term management has its own admin screen (`admin_blocklist_screen.dart`) — no SQL needed to add/remove banned terms.
- ⚠️ `comment_moderation_screen.dart` and `admin_blocklist_screen.dart` still use plain Material widgets, not yet migrated to the new design system.

### Notifications
- ✅ FCM device-token registration is live (`device_tokens`, 8 rows), upserted on conflict by token.
- ✅ **Push delivery is genuinely wired end-to-end**, verified against live database state: the `notifications_push_broadcast` trigger (`AFTER INSERT ON notifications`) calls `supabase_functions.http_request()` against the deployed `send-push-notification` Edge Function (v4, ACTIVE), which iterates `device_tokens` (filtered by `target_user_id` if set, else broadcast), calls the FCM HTTP v1 API per token with OAuth2 via a Firebase service account, and prunes tokens that come back `UNREGISTERED`/`INVALID_ARGUMENT`.
  - ⚠️ **Doc-drift note**: some in-repo code comments claim this pipeline is *not* deployed yet ("NOT YET CREATED", "has NOT been redeployed"). Those comments are stale — the live database and live Edge Function are ahead of what the comments say. Trust the live state described above, not those comments.
- ✅ Targeting is supported end-to-end (broadcast when `target_user_id IS NULL`, targeted when set).
- ⚠️ The admin UI (`admin_send_notification_screen.dart`) only exposes **broadcast** — it has no recipient picker, even though the DB/Edge Function layer fully supports targeted delivery. Targeting exists in the backend but isn't reachable from any admin screen yet.
- ✅ In-app notification list (`notifications_screen.dart`), newest-first, guests redirected to sign-in.
- ❌ No unread badge/count anywhere in the notifications UI.

### Merchandise
- ✅ Catalog with per-product variants (sizes) and multiple images, backed by `products` / `product_variants` / `product_images`.
- ✅ "Buy Now" is explicitly an **inquiry**, not a checkout — writes to `merch_inquiries` (product, variant, quantity, note, phone number pre-filled/editable). There is no payment processing anywhere in this flow; the code itself documents this as intentional.
- ✅ Wishlist toggle (`user_wishlist`), guarded for guests via `AuthGuard.requireAuth` with an auto-add-after-sign-in return flow.
- ✅ Admin CRUD: `admin_product_form_screen.dart` (product + variant rows in one form), `admin_merch_inquiries_screen.dart` (status roster: pending / contacted / fulfilled / cancelled).

### Challenges (fitness-activity based, via Health Connect)
- ✅ **Fully and cleanly pivoted off the old trek-attendance model.** Migration `0026_fitness_activity_schema` explicitly states the prior 4 trek-based challenges and their tier history "were deleted directly." No trek-attendance challenge UI or logic remains in the live code path.
- ✅ 3 live active challenges, all using the new fitness metrics: "5,000 Steps Today" (daily), "50km This Month" (monthly), "7-Day Activity Streak" (all-time).
- ✅ Health Connect permission flow (`activity_permission_banner.dart`) and daily sync (`activity_sync_service.dart`) into `daily_activity_summary`.
- ✅ Streak, leaderboard, and tier-history are all **computed live via SQL functions** (`get_my_streak()`, `get_challenge_leaderboard()`, `get_my_challenge_tier_history()`) over `daily_activity_summary` — not standalone stored tables, despite migration filenames (`0024_streaks.sql`, `0025_leaderboard.sql`, `0023_challenge_tier_history.sql`) that might suggest otherwise.
- ✅ Tier badges (bronze/silver/gold/platinum), a leaderboard screen, and streak display all exist and are surfaced on the Profile screen too (`streak_section.dart`, `loyalty_badge_section.dart`, `leaderboard_visibility_toggle.dart`).
- ⚠️ The old `trek_count` / `total_distance_km` metrics are deliberately **kept dormant** (not deleted) in both the SQL RPCs and the Dart `ChallengeMetric` enum — documented, intentional dead capability, not orphaned cruft. No UI surfaces them today.
- ❌ Elevation-gain-based challenges: explicitly and intentionally deferred (migration `0022_challenges.sql` comment: treks only track max altitude, not real elevation gain, "which isn't the same thing"). Not a bug, not forgotten — a scoped-out decision.

### Admin Tools
- ❌ There is no dedicated `admin` feature module — `lib/features/admin/{data,domain}` contain only placeholder `.gitkeep` files. All admin functionality lives inline inside each feature area instead.
- ✅ Dedicated admin screens: trek create/edit form, `admin_registrations_screen`, `admin_registration_detail_screen`, `admin_trek_registrations_screen`, `admin_trek_picker_screen`, `comment_moderation_screen`, `admin_blocklist_screen`, `admin_send_notification_screen`, `admin_product_form_screen`, `admin_merch_inquiries_screen`, `admin_challenge_form_screen`.
- ✅ Inline admin-only UI embedded in normal screens: `trek_admin_actions.dart`, `media_admin_overlay.dart` (gallery), `product_admin_actions.dart` / `product_image_admin_overlay.dart`, `challenge_admin_actions.dart`, `admin_send_notification_card.dart`, `admin_merch_inquiries_card.dart` — all sharing `core/widgets/admin_form.dart`.
- ⚠️ No screen anywhere lets an admin promote another user to admin — that's DB-only today.

### UI/Design System
A real design system exists: `lib/core/theme/` (colors, dimens, gradients, shadows, text styles), `lib/core/motion/`, and shared widgets `glass_card.dart`, `glass_states.dart`, `premium_button.dart`, `floating_nav_bar.dart`, all re-exported from the barrel file `lib/core/design_system.dart`. `main.dart` confirms the app is dark-theme-only (`AppTheme.dark`, `ThemeMode.dark` — labeled "Redesign Phase 1" in comments), with a `SplashGate` wrapper from "Redesign Phase 7." **The redesign was done in phases and is not finished everywhere:**

| Status | Areas |
|---|---|
| ✅ Largely redesigned | Home, Trek Library, Challenges, Auth, Profile, Merchandise, Onboarding |
| ⚠️ Partially redesigned | Notifications, Registrations, Comments |
| ❌ Still old/plain Material styling | Gallery, Settings, Activity |

The `main_*_demo.dart` files at the repo root (`design`, `shell`, `home`, `treks`, `challenges`, `merch`, `profile`, `splash` — 8 total) are confirmed dev-only isolated design-review harnesses: each skips Firebase/Supabase/routing bootstrap and runs against mock Riverpod overrides, launched individually via `flutter run -t lib/main_X_demo.dart`. `main.dart` is the sole real app entry point. One exception: the design-system component gallery (`DesignSystemDemoScreen`) is **also** routed inside the real app (`app_router.dart:256`) and reachable at runtime — it isn't purely a demo-only artifact.

---

## Database Schema Summary

Live project `tbpebbfchqudtwqzfvxh`. All 17 public tables have RLS **enabled** with explicit policies (verified via `pg_policies`, not assumed from migration files).

| Table | Purpose | RLS posture |
|---|---|---|
| `users` | Profile + role (`guest`/`user`/`admin`), linked 1:1 to `auth.users` | Self or admin can select/update; only admin can delete; role/email/phone-verified self-edits blocked by triggers |
| `treks` | Trek catalog: details, scheduling, fee, publish state | Public read; admin-only write |
| `gallery` | Per-trek photos/videos | Read gated to published treks only; admin-only write |
| `comments` | Trek comments | Public read; own insert (blocklist-checked); own/admin update; visibility self-edit blocked by trigger |
| `registrations` | Trek sign-ups + payment tracking | Own-or-admin read/update/delete; own insert; `payment_status` self-edit blocked by trigger |
| `notifications` | Broadcast or targeted announcements (`target_user_id` nullable) | Admin-only write; read policy present for all authenticated users |
| `settings` | Key/value community info & About-page content | Public read; admin-only write |
| `comment_blocklist` | 403 seeded moderation terms | Public read; admin-only write |
| `device_tokens` | FCM tokens per user/platform | Own-row-only CRUD |
| `products` | Merch catalog | Public read; admin-only write |
| `product_variants` | Size/stock per product | Public read; admin-only write |
| `product_images` | Images per product | Public read; admin-only write |
| `merch_inquiries` | "Buy Now" inquiries (not real orders) | Own-or-admin read; own insert; admin-only status update |
| `user_wishlist` | Saved products per user | Own-row-only |
| `challenges` | Fitness challenge definitions | Public read; admin-only write |
| `challenge_tiers` | Bronze/silver/gold/platinum thresholds per challenge | Public read; admin-only write |
| `daily_activity_summary` | Per-user daily steps/distance/calories synced from Health Connect | **Own-row-only, no admin override** |

**Notable live functions**: `is_admin()`, `is_registered_user_or_admin()` (RLS helpers) · `get_community_stats()`, `get_challenge_leaderboard()`, `get_my_challenge_progress()`, `get_my_challenge_tier_history()`, `get_my_streak()` (read RPCs) · `handle_new_user()`, `populate_comment_user_info()`, `check_comment_blocklist()`, `reset_phone_verification_on_change()`, `prevent_role_escalation()`, `prevent_email_self_edit()`, `prevent_phone_verified_self_edit()`, `prevent_payment_status_self_edit()`, `prevent_visibility_self_edit()` (write guards) · `rls_auto_enable()` (event trigger — auto-enables RLS on any newly created table, a real safety net).

**Storage buckets**: `trek-covers` (public, 5MB, images), `trek-gallery` (public, 50MB, images + video), `merch-images` (public, 5MB, images), `payment-proofs` (**private**, 5MB, images).

**Edge Functions** (both `ACTIVE` and `verify_jwt: true`): `send-push-notification` (v4), `verify-phone-token` (v1).

---

## Known Gaps / Deferred Work

Pulled from actual code comments, migration comments, and live-vs-repo verification — not speculation.

- **iOS**: no support at all. See Platform Scope.
- **Elevation-gain challenges**: explicitly deferred by design (migration `0022_challenges.sql`), not a bug.
- **About/Community content**: the `settings` table and UI are fully live, but most About-page copy (mission, vision, story, founder message, why-join, contact email/phone, social links) is still unfilled placeholder text.
- **No central admin dashboard**: admin capability is real but scattered across per-feature screens; some (registrations roster, comment moderation) have no linked entry point in the nav — reachable only by direct route.
- **User role promotion**: no in-app UI to make someone an admin; DB-only today.
- **Targeted push notifications**: fully built end-to-end in the database/Edge Function layer, but the admin UI only exposes broadcast — no recipient picker exists yet.
- **Unread notification badge/count**: not implemented anywhere.
- **Design system rollout incomplete**: Gallery, Settings, and Activity screens (plus parts of Notifications, Registrations, and Comments) still use the old plain Material styling rather than the new dark/glassmorphism system.
- **Dormant challenge metrics**: `trek_count`/`total_distance_km` challenge metrics are intentionally kept in the schema/enum but unused by any live challenge or UI — a deliberate compatibility decision, not dead-code rot.
- **Stale code comments around push notifications**: several comments in the notifications code claim the push pipeline isn't deployed; the live database and Edge Function are actually ahead of those comments. Don't trust those specific comments — trust the live state documented above.
- **Local migrations directory is out of sync with the live database.** The live project's migration history (`supabase_migrations.schema_migrations`) includes several applied migrations with **no corresponding `.sql` file** in `supabase/migrations/`: `add_phone_verification_fields_to_users`, `populate_avatar_from_oauth_metadata`, `phone_otp_verification_guards`, `drop_phone_otp_requests_widget_migration`, `push_tokens`, `notifications_targeting`, `merch_inquiry_phone`, `challenge_tier_history_fix_ambiguous_columns`. Anyone trying to reproduce the live schema from the repo alone would be missing these. Additionally, migrations `0001`–`0006` (baseline schema, role policies, field-level guards, about content, community stats function, trek-covers storage) exist locally but do **not** appear in the live migration history table at all — they likely predate CLI-tracked migrations on this project.
- **Live Supabase security advisories** (from the project's own linter, unresolved as of this writing):
  - 3 public storage buckets (`merch-images`, `trek-covers`, `trek-gallery`) have a broad `SELECT` policy that allows object *listing*, not just direct-URL access — minor information exposure.
  - Every `SECURITY DEFINER` function in `public` is flagged as callable by `anon`/`authenticated` roles — mostly intentional (RLS helper functions, trigger functions), but unreviewed as a set.
  - Leaked-password protection (HaveIBeenPwned check) is disabled in Supabase Auth.
