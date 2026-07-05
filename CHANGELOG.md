# Changelog

All notable changes to this project are documented here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/); milestone-based until first release.

## [Unreleased]

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
