# Implementation Roadmap

> Status: Proposed — pending approval. Updated 2026-07-04 (2nd pass): added the config platform (ADR-0011) to M0/M1, the **Awrad** and **Hadith Collections** modules from the design review to M2, campaign engine (ADR-0013) to M3, and multi-locale content (ADR-0014) throughout. Milestones are sequential gates; iOS and Android proceed in lockstep per feature; backend contracts land one milestone ahead of the clients that consume them.

## Milestone 0 — Foundations (infrastructure, no user features)

**Goal:** a compilable, testable skeleton on all four platforms with the design system in place.

- Repo: git init, CI pipelines (iOS/Android/backend/dashboard), issue/PR conventions, `CONTRIBUTING.md`.
- Backend: Supabase project scaffolding, migration tooling, API gateway edge function with `/v1/health`, OpenAPI spec skeleton, **config platform v1** (`/v1/config`, theme tokens, string packs — ADR-0011) + feature flags.
- iOS: workspace + SPM module skeleton (Core, UICore, App), Factory DI wiring, router/coordinator scaffolding, design tokens, theming (light/dark), Arabic/English localization + RTL infrastructure.
- Android: Gradle convention plugins, module skeleton, Hilt, Navigation host, design tokens (Material 3 themed to brand), localization/RTL.
- Design system v1: color/typography/spacing/motion tokens **in the FATWA BOT brand language (maroon/cream, arch motif — see 06_DESIGN_REVIEW.md), consuming server theme tokens with bundled defaults**, core components (cards, buttons, list rows, empty/loading states) with snapshot tests — per [05_DESIGN_DIRECTION.md](05_DESIGN_DIRECTION.md).
- Spikes: iOS persistence choice (SwiftData vs GRDB); prayer-calc library validation against golden timetable corpus.

**Exit criteria:** both apps launch to a themed shell with tab navigation; CI green; `/v1/health` deployed; golden-file prayer tests passing against the chosen calculator.

## Milestone 1 — Prayer Core (the daily-retention spine)

- On-device prayer calculation (methods, madhab, high-latitude, manual adjustments), location handling (GPS + manual city fallback), Hijri date with offset.
- Prayer Home surface: next-prayer hero with countdown, daily timeline (per Home spec).
- Qibla compass: bearing, calibration UX, accuracy indicator, declination correction.
- Local notification engine v1: adhan/iqamah offsets, rolling 3-day scheduling window, per-prayer toggles with help texts.
- Widgets v1: Next Prayer + Prayer Countdown + Hijri Date (WidgetKit + Glance) from app-group store.
- Backend: `/v1/config/prayer-defaults` (per-country method defaults), device registration, anonymous identity (`/v1/auth/anonymous`), **Home layout endpoint `/v1/home` + native section catalog v1** (ADR-0011).
- Settings v1: calculation method, madhab, adjustments, language, theme — rendered from the backend notification/config catalogs where applicable.

**Exit criteria:** a user in any city gets correct offline prayer times, qibla, adhan notifications, and a working widget — with zero sign-up. ✅ **Met 2026-07-05** (iOS 41 / Android 26 / backend 16 tests green; both apps build; deploy pending credentials Q8).

## Milestone 2 — Azkar · Dua · Tasbeeh · Awrad · Hadith Collections (content & worship tools)

- Content schema (**multi-locale per ADR-0014**) + seed bundles (morning/evening/after-prayer/sleep/travel azkar; categorized duas; initial hadith collections with benefit notes; wird templates) in `content/`, with sources and translations.
- Backend content publishing: versioned content API, delta sync, ETag caching, per-locale publishing states.
- Azkar reading experience: session flow, repeat counters with haptics, progress, completion states; morning/evening azkar notifications; periodic dhikr reminders (interval + active window, from the demo).
- Dua library: categories, search, favorites.
- Tasbeeh: presets, targets, sets, haptics, history; Tasbeeh widget; Azkar widget.
- **Awrad (from design review):** template-guided wird creation (custom as escape hatch), daily board with completion flow, personal stats (azkar totals, completed days, Qur'an pages, salawat) — events feed the M3 streak engine.
- **Hadith Collections (from design review):** collection browser (Nawawi's 40, etc.), hadith reading flow with grading + الفائدة notes, progress, optional hadith-of-the-day reminder.
- Admin dashboard v1 (content-first): auth (admin roles), CMS for azkar/duas/hadith collections/wird templates with draft→review→publish workflow and locale tabs; notification template packs.

**Exit criteria:** full offline azkar/dua/tasbeeh/awrad/hadith experience; all content and reminder texts updatable from the dashboard without app releases.

## Milestone 3 — Accounts, Gamification & Leaderboard (completes مزايا)

- Auth: Apple/Google sign-in via `/v1/auth/*`, anonymous→account linking, profile + optional display name.
- Activity-event pipeline (idempotent client events → server engine) with **definition-driven rules (ADR-0012)**: streak categories + overall streak, day-boundary/grace policies, missions, badges, achievements, milestones — all admin-editable data; branded streak visuals (mihrab-arch motif).
- Achievements, daily/weekly challenges (admin-authored), reward system — rendered from descriptors, zero client scoring logic.
- **Leaderboard engine (ADR-0012):** definitions for scope (global/country/city/friends-ready) × period (weekly/monthly/seasonal/lifetime/challenge) with eligibility, tie-breaking, visibility, display requirements, rewards, and season resets; generic leaderboard renderer in apps; snapshots via pg_cron. Launch set: global + country, weekly + seasonal + lifetime.
- Search History module (server-side store + local cache + delete) — ships as the container that AI features will later populate; in this milestone it records in-app content searches.
- **Notification campaign engine (ADR-0013):** catalog + templates + campaigns (one-time/recurring/Hijri-triggered/emergency), per-timezone fan-out, streak/challenge notifications via FCM; preference schema synced.
- Dashboard: challenges/missions/badges CRUD, leaderboard definitions + ops, user management, announcements, campaign composer with audit trail, notification catalog.
- Widgets: Streak + Daily Challenge.

**Exit criteria:** the entire مزايا section is production-complete — the foundation's gate for starting AI work.

## Milestone 4 — Premium polish pass

- Onboarding flow (value-first, permission priming for location/notifications), empty states, micro-interactions, animation audit, accessibility audit (VoiceOver/TalkBack, Dynamic Type, reduced motion), performance pass (cold start, widget battery), Live Activity prayer countdown (iOS) if approved.
- Beta program (TestFlight / Play internal), crash & analytics dashboards, store listing prep.

**Exit criteria:** beta-quality release candidates on both stores.

## Milestone 5 — AI Phase 1: Knowledge base & Fatwa Search

- Dashboard: fatwa sources, hadith collections, knowledge-base ingestion (pgvector), AI configuration (providers, prompts, source whitelist).
- Backend AIGateway (provider-abstracted, Claude-first), citation-mandatory answer pipeline, refusal states, rate limits, moderation, query history → Search History module.
- App: ابحث عن فتوى experience on Home (per Home spec's AI section), streaming answers with cited sources UI, feedback controls.

## Milestone 6 — AI Phase 2: Hadith Extraction & General Questions

- استخراج الأحاديث: hadith identification/grading presentation from curated collections.
- سؤال ديني عام: general Q&A with stricter refusal boundaries.
- AI quality evaluation harness (curated eval set reviewed by a domain expert), dashboard analytics for AI usage/quality.

## Milestone 7 — Launch & hardening

- Load testing, security review (API, RLS, secrets), App Store / Play submission, rollout with feature flags, post-launch monitoring runbooks.

## Sequencing rationale

- Config platform starts in M0 because everything else consumes it — theming, strings, flags, and the Home section catalog are the delivery mechanism for the "no store release" requirement (ADR-0011).
- M1 before M2: prayer is the daily hook and hardest correctness problem; it also builds the notification+widget infrastructure everything else reuses.
- Awrad and Hadith Collections join M2 (not a new milestone): they are content-plus-local-state features that reuse M2's content pipeline; their events plug into M3's engine.
- Accounts deferred to M3: nothing before leaderboards *needs* identity beyond anonymous — keeps M1/M2 friction-free (ADR-0004).
- Dashboard grows feature-by-feature alongside its consumers rather than as a big-bang project.
- AI last per the foundation, but its API shape, Home placement, and Search History container are designed from M0 so nothing churns.

## Tracking

- `CHANGELOG.md` updated per milestone; `docs/features/<feature>.md` spec written before each feature's implementation; ADR added whenever a decision with alternatives is made.
