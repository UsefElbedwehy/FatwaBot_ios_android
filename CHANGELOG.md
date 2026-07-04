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
