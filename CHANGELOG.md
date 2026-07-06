# Changelog

All notable changes to this project are documented here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/); milestone-based until first release.

## [Unreleased]

### 2026-07-07 — Milestone 3 backend complete (accounts, gamification, leaderboards, search history, notifications)
- **Specs first:** wrote all 5 M3 feature specs before code; resolved OPEN_QUESTIONS Q2c/Q2d/Q4/Q5 with the stakeholder (opt-in-only city leaderboards, 2/day notification cap, Fajr-to-Fajr admin-editable day boundary, in-app-actions-only streaks — never self-reported prayer logging).
- **Accounts (ADR-0004 extension):** `/v1/auth/apple`, `/v1/auth/google` sign-in and `/v1/auth/link` anonymous→account upgrade, both behind a pluggable `IdentityProviderVerifier` (dev-stub today, real Apple/Google JWKS verification later with no contract change — blocked only by Q8 credentials). Linking preserves `user_id`, so no local/synced state is lost. Optional self-chosen `display_name` via `PATCH /v1/me/profile`.
- **Gamification engine (ADR-0007/0012):** idempotent batched activity-event ingest; pure streak-folding logic (`gamification_engine.ts`) — day-boundary approximated as an admin-configurable fixed local time (real Fajr needs on-device location the backend doesn't have), grace tokens that preserve but don't extend a streak and replenish outside a rolling window. `GET /v1/gamification/profile` assembles streaks/missions/badges live from the event log + currently-published definitions — no separately-drifting cache.
- **Leaderboard engine (ADR-0012):** weighted/capped point formulas, ranking with ordered tie-breakers, pseudonymous-by-default join/leave/membership (real name shown only if the board requires it or the member opts in), admin-triggered snapshot recompute standing in for `pg_cron` until Supabase is deployed.
- **Search history:** per-user, paginated, source-filterable CRUD; reserved AI sources (`ai_fatwa`/`ai_hadith`/`ai_question`) unused until M5.
- **Notifications:** admin-editable catalog + per-user preference overrides; pure cap-check logic (2/day default, admin-configurable, campaign-only — never applies to locally-computed worship/gamification reminders). Actual FCM dispatch is explicitly deferred (needs Firebase credentials + audience-segment querying beyond this milestone) — catalog, prefs, delivery-log schema, cap logic, and open-tracking are all real and tested, ready for a dispatch handler once those land.
- **Key architectural continuity win:** every new definition table (streak_defs, missions, badges, leaderboard_defs, notification_types, templates, campaigns) reuses task 27's generic `/admin/v1/content` CRUD instead of a parallel bespoke API — extended `ADMIN_COLLECTIONS` to carry a `(schema, table)` pair per collection instead of an assumed single schema.
- **Totals:** 93 backend tests (up from 76), all green; every migration (0007–0010) verified against a throwaway local Postgres; OpenAPI specs (mobile + admin) updated throughout; lint/fmt clean at every step.
- **Remaining M3 work:** iOS/Android gamification + leaderboard + search-history UI, streak/challenge widgets, and dashboard CRUD for the new admin collections.

### 2026-07-04 — Planning phase
- Transcribed the foundation PDF into canonical [prompts/00_PROJECT_FOUNDATION.md](prompts/00_PROJECT_FOUNDATION.md).
- Added planning package: project analysis, architecture, architecture review, roadmap (M0–M7), design direction + Home screen spec, ADR-0001…0010 (all Proposed), open questions, future improvements, README.
- Flagged missing `design/` concept-demo assets and absent git initialization.
- **Gate:** awaiting stakeholder approval before Milestone 0 implementation.

### 2026-07-04 — Planning pass 2 (design review + configurability requirements)
- Reviewed the 22 concept screens added in `App Demo design/` → [docs/06_DESIGN_REVIEW.md](docs/06_DESIGN_REVIEW.md); adopted the FATWA BOT brand (maroon/cream, mihrab-arch motif) into the design direction.
- New modules from the designs: **Awrad (personal wird routines)** and **Hadith Collections (الأربعون learning)** — added to roadmap M2; rejected the demo's in-app secret-code admin panel.
- New ADRs for the backend-configurability philosophy: ADR-0011 (server-driven config, theme, strings, Home layout), ADR-0012 (leaderboards/streaks/missions as data), ADR-0013 (notification campaign engine), ADR-0014 (multi-locale content).
- Updated architecture (config platform §3a, schema domains, campaign engine, AI provider routing), roadmap (M0–M3 scope), open questions (Q1 resolved; new Q2b–Q2d).
- **Gate:** awaiting stakeholder approval of pass-2 updates before Milestone 0.

### 2026-07-04 — Final approval & implementation start
- Stakeholder approved architecture, roadmap, and documentation; all ADRs 0001–0014 marked **Accepted**.
- Final directives folded in: ADR-0015 (configurable-by-default + tenancy-ready schemas); Home spec rebalanced for the dual identity (AI assistant + daily companion — AI section above the fold, daily hadith/dua, featured content, quick actions/widget shortcuts sections added to the catalog); ADR-0008 extended (provider priority, fallback chains, sampling params, safety policies, cost metering); ADR-0013 extended (segmentation, delivery/open analytics, A/B-ready templates); ADR-0009 dashboard scope = operational control center; CMS block model (rich text, images, video, audio, PDF, markdown, sanitized HTML); analytics pipeline domain added.
- Repository initialized under git. **Milestone 0 implementation begins.**

### 2026-07-04 — Milestone 0 complete (local)
- **Backend:** config-platform migrations (apps/ADR-0015, config domain, identity skeleton), seed data, Edge Function API gateway (`/v1/health`, `/v1/config`, `/v1/config/theme`, `/v1/config/strings/{locale}`, `/v1/home`, `/v1/config/prayer-defaults`), OpenAPI v1 contract, 11 deno tests green.
- **iOS:** FatwaBotKit (CoreKit contract models, NetworkingKit APIClient, DesignSystemKit tokens with server-theme overlay) — 9 tests green; XcodeGen app target with themed 4-tab shell, ar/en + RTL; simulator build green.
- **Android:** version-catalog Gradle setup, Hilt, `:core:common` contract models (2 tests green), `:core:designsystem` Material3 brand theme, 4-tab Compose shell, ar/en + RTL; full `gradlew build` green (JDK 21 + SDK 35 provisioned).
- **Dashboard:** Next.js control-center shell with domain navigation and backend health probe; lint/typecheck/build green.
- **Prayer spike (ADR-0003):** 140-entry golden corpus (adhan-js reference) reproduced by adhan-swift within ±90s; qibla bearings ±1°. **Finding:** ≥48° latitude requires an explicit high-latitude rule — library defaults diverge by hours across ports; policy encoded in `config.prayer_defaults` and the corpus.
- **CI:** paths-filtered workflows for all four platforms (activate when a GitHub remote is added).
- M1 feature specs pre-written: config-sync, prayer.
- **Blocked on credentials (Q8):** Supabase project (deploy `/v1/health` + migrations), Firebase, store accounts, GitHub remote for CI.

### 2026-07-05 — Milestone 1 in progress (6 of 9 tasks complete)
- **Backend auth (ADR-0004):** `/v1/auth/anonymous` (device-registered identity, HS256 access JWT + hashed single-use refresh tokens), `/v1/auth/refresh` rotation with replay rejection, `/v1/me` bearer probe; migration 0004; 16 deno tests green.
- **iOS ConfigSync (ADR-0011 client half):** ConfigKit — snapshot store (atomic, app-group-ready), per-layer independent refresh, delta string packs, flag gating with `min_app_version`; 6 tests per spec.
- **Prayer engines on both platforms:** settings (clamped adjustments, Hijri offset), day/timeline, next-prayer across midnight/Isha boundaries, Hijri dates; **high-latitude auto rule stated identically** (≥48° → seventh-of-the-night); iOS 11 + Android 11 tests green, both passing the 140-entry golden corpus.
- **UI slices on both platforms:** server-layout Home renderer (native section catalog v1: header/hero/ask/quick-actions, unknown types skipped), gradient prayer hero with live countdown + 5-prayer strip, Ask section with the three intents + trust line, Prayer screen with day pager and Hijri header, manual-city fallback (12 bundled cities), iOS Qibla compass with calibration/interference states; Factory (iOS) and Hilt (Android) composition; both apps build green.
- Remaining M1: local notification engines, widgets, Android ConfigSync port.

### 2026-07-05 — Milestone 1 complete
- **Android ConfigSync port (ADR-0011):** `:core:network` (OkHttp ApiClient + client-context headers), `:core:config` (ConfigService with parallel per-layer refresh, delta string packs, min_app_version flag gating, atomic FileConfigStore); Home now renders the real server layout + flags. 6 tests mirroring the iOS spec cases. Full ConfigSync parity between platforms.
- **Local notification engines (ADR-0013):** pure `NotificationPlanner` on both platforms (rolling window, per-prayer adhan + pre-adhan offsets, budget cap, stable ids) with 5 mirrored tests each; iOS scheduler over UNUserNotificationCenter, Android over AlarmManager + a boot-surviving BroadcastReceiver; reschedule wired into both ViewModels; adhan texts in ar/en.
- **Widgets v1 (ADR-0003):** shared `PrayerWidgetSnapshot` (precomputed 48h, app-group/file store) written by the app; iOS WidgetKit extension (Next Prayer, Timeline, Hijri) and Android Glance (Next Prayer, Hijri) reading it with zero network. 3 tests each platform.
- **M1 exit criteria met:** a user in any city gets correct offline prayer times, qibla, adhan notifications, and a working widget — with zero sign-up. Totals: iOS 41 tests, Android 26 tests, backend 16 tests, all green; both apps build.
- **Still blocked on credentials (Q8)** for deployment/CI only — all M1 features work locally offline-first.

### 2026-07-06 — Milestone 2 in progress (6 of 11 tasks complete)
- **Content pipeline (ADR-0014):** `content` schema (azkar/dua categories+items, hadith collections+entries, wird templates — all multi-locale jsonb translations, versioned publishing); real seed content (Hisnul-Muslim-style morning/evening/after-prayer azkar, Quranic + daily-occasion duas, 3 entries of Nawawi's 40 with benefit notes, 3 wird templates) validated against a throwaway local Postgres. `GET /v1/content/{azkar,duas,hadith-collections[/{slug}],wird-templates}` — locale-resolved, delta-aware (`since_version`); 9 backend tests.
- **Client content sync (both platforms):** ContentKit/`:core:content` mirror ConfigSync's offline-first pattern — bundled seed JSON fallback, per-collection independent cache, silent failure. Bundled seed generated from the same backend seed data (single source).
- **Tasbeeh (fully local):** presets, custom dhikr, configurable target, haptics (tick + distinct target-reached), history/stats; hoisted `HapticsProviding` to CoreKit/`core:common` so later features can share it without a feature→feature dependency (ADR-0010). 8 tests each platform.
- **Azkar:** session state machine (auto-advance at exact repeatCount, same-day resume, idempotent completion), category list with completed-today badge, reading screen (virtue-note card, calm completion state per ADR-0007 — no gamified burst). 6 tests each platform.
- **Dua library:** browse/search/favorites; favorites keyed by stable duaId (survives content resync, not array position); diacritic-insensitive Arabic search distinguishing "not searching" from "no matches"; reading view with share. 7 tests each platform.
- **Found & fixed:** ContentKit's server-contract structs had no explicit `public init` — Swift's synthesized memberwise init for a public struct is only internal, silently working via Codable but unconstructible from feature-module tests/fixtures. Also two recurring iOS/macOS cross-compile snags (`navigationBarTitleDisplayMode`, `.listStyle(.insetGrouped)` are iOS-only; AppFeatures builds for macOS too for fast `swift test` runs) — both guarded with `#if os(iOS)`.
- Worship tab now hosts real Prayer/Qibla/Tasbeeh/Azkar/Dua destinations on both platforms (two-level back navigation for list↔detail features); Hadith Collections remains the last "coming soon" row.
- Remaining M2: Awrad, Hadith Collections, final Worship/Home quick-actions wiring, Admin Dashboard v1 (auth + CMS).

### 2026-07-06 — Milestone 2 in progress (10 of 11 tasks complete)
- **Awrad:** template-guided wird creation, local daily ticking, day-completion requiring all active wirds to hit target, archiving that preserves historical stats, lifetime aggregation (dhikr/days/Qur'an-pages/salawat) mirroring the concept demo's stat row. 8 tests each platform.
- **Hadith Collections:** browse/read Nawawi's-40-style collections, progress keyed by entry number (a set, no double-counting), resumes at last-read entry, prev/next clamped at boundaries, jump-to-entry. 6 tests each platform.
- **Worship tab + Home quick actions wired (both platforms):** all seven مزايا worship modules (Prayer, Qibla, Azkar, Dua, Tasbeeh, Awrad, Hadith) now reachable from the Worship tab; Home's quick actions deep-link directly into a screen (iOS: NavigationPath + navigationDestination; Android: hoisted destination state), not just switch tabs.
- **Found & closed a real parity gap:** Android never had a Qibla screen at all (iOS had it since M1) or a Home quick-actions row (silently dropped with a "arrives in M2" comment) — both built now: SensorManager rotation-vector heading provider + animated compass (Android), QuickAction enum + row (Android), completing platform parity for the entire مزايا section.
- Remaining M2: Admin Dashboard v1 (auth + content CMS).

### 2026-07-06 — Milestone 2 complete
- **Admin Dashboard v1 (ADR-0009), backend:** `/admin/v1` surface on the same gateway function — self-issued admin JWTs (`aud=admin`, distinct from mobile tokens), generic draft/publish/version CRUD across the 7 whitelisted content collections, audit log on every mutation. Version bumps only once a row has been published, so draft iteration doesn't churn the client-visible version. `admin.admin_users` / `admin.audit_log` (migration 0006, RLS deny-by-default); `openapi/admin.v1.yaml`; bootstrap dev admin seeded (`admin@fatwabot.dev`, dev-only password, `on conflict do nothing`). 15 new backend tests (76 total); lint/fmt clean.
- **Admin Dashboard v1, UI:** real Next.js pages replacing the M2 placeholder — login (server action + httpOnly session cookie), content collection index/list/editor (locale tabs sourced from `/v1/config`, not hardcoded) with Save/Publish/Unpublish, audit log with collection filtering. `proxy.ts` (Next 16's renamed middleware convention) gates the authenticated routes; a defense-in-depth 401 handler clears the session and redirects if a token expires mid-session.
- **Verified end-to-end** against a throwaway local gateway (real router + in-memory repos, no live Supabase needed): login → list → edit → save (no version bump on a draft) → publish → edit again (version bump confirmed) → audit log (all mutations recorded, most recent first) → create draft. typecheck/lint/build all green.
- **M2 exit criteria met:** all seven مزايا worship modules complete and wired on both platforms with parity; content is admin-authored end-to-end (create → edit → publish → visible on `/v1/content/*`) with a full audit trail.
- **Still blocked on credentials (Q8)** for deployment/CI only — all M0–M2 features work locally offline-first or against the local dev backend.
