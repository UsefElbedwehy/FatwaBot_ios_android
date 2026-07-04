# System & Application Architecture

> Status: Proposed — pending approval. Updated 2026-07-04 (2nd pass) after the design review and the backend-configurability requirements: added the config platform (§3a, ADR-0011), rules-as-data gamification (ADR-0012), campaign engine (ADR-0013), and the Awrad + Hadith Collections modules. Companion: [03_ARCHITECTURE_REVIEW.md](03_ARCHITECTURE_REVIEW.md) records where and why this deviates from the foundation's literal text.

## 1. System Overview

```
┌─────────────┐   ┌──────────────┐        ┌───────────────────┐
│   iOS App   │   │ Android App  │        │  Admin Dashboard  │
│  (SwiftUI)  │   │  (Compose)   │        │ (Next.js, web)    │
└──────┬──────┘   └──────┬───────┘        └────────┬──────────┘
       │  HTTPS · REST /v1 · JWT                   │ REST /admin/v1 · JWT (admin roles)
       └──────────────┬──┴────────────────────────┘
              ┌───────▼────────┐
              │  Backend API   │  Supabase Edge Functions (Deno/TS)
              │  (owns all     │  – versioned REST, OpenAPI-specified
              │  business      │  – auth token issuance/refresh
              │  logic)        │  – streak/challenge engine
              └───────┬────────┘  – content publishing & versioning
                      │           – AI gateway (later phase)
              ┌───────▼────────┐
              │    Supabase    │  Postgres (RLS deny-by-default),
              │                │  Auth, Storage, pg_cron
              └────────────────┘
   Firebase (side channel only): FCM push · Analytics · Crashlytics
   AI Providers (later): behind AIGateway interface, server-side only
```

Rules:

- Mobile apps speak **only** to the Backend API (`/v1/...`). No Supabase SDK in mobile apps. The Supabase **service-role key never leaves the backend**.
- The Admin Dashboard also goes through the API (`/admin/v1/...`) — same discipline, one audited write path (see ADR-0009).
- REST is versioned in the URL path. Contract-first: OpenAPI spec lives in the repo; client DTOs generated or hand-written against it with contract tests.

## 2. Monorepo Layout (ADR-0010)

```
/
├── prompts/            # foundation & working prompts
├── design/             # reference designs (currently missing — see analysis)
├── docs/               # this documentation + adr/
├── backend/
│   ├── supabase/       # migrations, seed data, config
│   ├── functions/      # edge functions (api entrypoint, per-domain handlers)
│   ├── openapi/        # api.v1.yaml, admin.v1.yaml
│   └── tests/
├── ios/
│   ├── App/            # app target, composition root, coordinators
│   ├── Modules/        # Feature packages (SPM): Prayer, Qibla, Azkar, ...
│   ├── Core/           # CoreKit, NetworkingKit, PersistenceKit, DomainKit
│   ├── UICore/         # DesignSystem, components, theming, typography
│   └── Widgets/        # WidgetKit extension
├── android/
│   ├── app/            # composition root, navigation host
│   ├── feature/        # :feature:prayer, :feature:qibla, ...
│   ├── core/           # :core:network, :core:database, :core:domain, :core:common
│   ├── designsystem/   # :core:designsystem
│   └── widget/         # Glance widgets
├── dashboard/          # Next.js admin app
└── content/            # canonical seed content (azkar/dua JSON, reviewed)
```

## 3. Mobile Architecture (both platforms, mirrored)

Layering per the foundation, feature-first:

```
Feature module
├── Presentation   Views (SwiftUI/Compose) + ViewModels (state machines)
├── Domain         Use Cases + Entities + Repository interfaces   ← pure, no frameworks
└── Data           Repository impls + local store + remote DTOs
Shared
├── Core           networking (APIClient/Endpoints), persistence, utilities
├── UICore         design system: tokens, components, typography, motion
└── App            composition root: DI registration, coordinators/nav graph
```

- **iOS:** MVVM + lightweight Coordinator over `NavigationStack` path routers (amended MVVM-C — see ADR-0005); DI via **Factory** (hmlongco/Factory) per the foundation; persistence via SwiftData or GRDB (decide in M0 spike); features as SPM packages.
- **Android:** MVVM + Navigation-Compose graph per feature; DI via **Hilt** (ADR-0006 — the Android analogue of "Factory DI" intent: compile-time-safe container DI); Room + DataStore; Gradle convention plugins for module uniformity.
- **Parity discipline:** the *domain layer* (use case names, entities, repository contracts, error taxonomy) is specified once per feature in `docs/features/<feature>.md` and implemented twice. Same API DTOs, same analytics event names.

### Offline-first data policy

| Data class | Strategy |
|---|---|
| Prayer times, Qibla | Computed on device (ADR-0003); config cached with shipped defaults |
| Azkar/Dua content | Shipped seed bundle + versioned content sync (ETag / content-version) |
| Tasbeeh counts, azkar progress, prayer logs | Local write-ahead, background sync queue, last-write-wins per counter-day (server merges) |
| Streaks/leaderboard/challenges | Server-authoritative, cached read models |
| Settings/preferences | Local first; synced when signed in |

### 3a. Config platform (server-driven behavior — ADR-0011)

The backbone of the "no store release needed" requirement. Four layers, all admin-managed, versioned, and cached offline with bundled defaults:

| Layer | Endpoint | Drives |
|---|---|---|
| Remote config | `/v1/config` | Feature flags, module registry, provider selections, prayer/notification/gamification defaults, supported languages/countries |
| Theme & branding | `/v1/config/theme` | Color palettes (light/dark), type-scale params, logos/artwork URLs, product-name string — tokens as data over a fixed schema |
| String packs | `/v1/config/strings/{locale}` | All UI copy, onboarding content, help texts — delta-synced by version |
| Home layout | `/v1/home` | Ordered typed sections rendered by a **native section catalog**; unknown types skipped (forward-compatible) |

Client rule: config never blocks rendering — bundled/cached values render instantly; updates apply on next launch or immediately where safe. Widgets read the same theme/config from the app-group store.

## 4. Backend Design

- **Edge Functions (TypeScript)** organized as one API gateway function per API version routing to per-domain handlers (`prayer-config`, `content`, `gamification`, `auth`, later `ai`). Shared code in `backend/functions/_shared`.
- **Postgres schema domains:** `identity` (users, devices, display profiles, roles), `content` (azkar, duas, hadith collections + benefit notes, **wird templates**, CMS documents, all multi-locale per ADR-0014, versioned publishing), `gamification` (activity_events → projections, plus **definitions**: leaderboard_defs, streak_defs, missions, badges, achievements, rewards — ADR-0012), `notifications` (catalog, templates, campaigns, segments, delivery/open metrics — ADR-0013), `config` (remote config, theme, string packs, home layout — ADR-0011), `analytics` (client event ingest, aggregates), `ai` (later: sources, documents, chunks/embeddings, query history, provider/prompt/routing config, usage & cost metering).
- **Tenancy-readiness (ADR-0015):** all definition/config/content/campaign tables carry a defaulted `app_id` FK; unique constraints and RLS policies are app-scoped; services resolve config via an app-scoped context. Single-app today, white-label-able without schema surgery.
- **CMS content model:** blocks-based documents — rich text (portable JSON, renderable natively), images, video, audio, PDFs/attachments (Supabase Storage URLs), markdown, and sanitized HTML as an explicit block type (rendered in a constrained web view only where a native mapping doesn't exist). Same model feeds announcements, featured content, daily hadith/dua, and onboarding cards.
- **Analytics pipeline:** one event taxonomy doc; clients batch app events (screen views, feature usage, search, funnel steps, notification opens) to `/v1/analytics/events` (anonymous-id aware, consent-gated) → Postgres aggregates for the dashboard, alongside Firebase Analytics/Crashlytics for crashes and performance. Server components emit AI usage/token/cost and campaign delivery metrics directly.
- **Gamification engine (rules-as-data, ADR-0012):** clients submit idempotent *activity events* (client UUID, timestamp, timezone) and render *descriptors* (`/v1/leaderboards`, `/v1/gamification/profile`). All scoring, streak folding, day boundaries, grace, seasons, and rewards are server-side definitions editable from the dashboard; point formulas are a constrained declarative form (auditable, recomputable from the event log — never arbitrary code). `pg_cron` materializes leaderboard snapshots and drives challenge/season lifecycle.
- **RLS everywhere, deny-by-default**, even though access is API-mediated — defense in depth.
- **Auth:** Supabase Auth used *behind* the API: `/v1/auth/*` endpoints proxy sign-in (Apple/Google/anonymous) and return access/refresh JWTs the mobile apps hold as opaque tokens (ADR-0004). Anonymous-first: device gets an anonymous identity; account linking upgrades it without data loss.

## 5. Notification Architecture (ADR-0013)

- **Local engine (on device):** schedules from the on-device prayer calculator — adhan/iqamah offsets, morning/evening azkar, third-night, and periodic dhikr reminders (interval + active-window, per the demo). Rolling window (iOS 64-notification pending limit ⇒ schedule ~3 days ahead, reschedule on app open, background refresh, and significant location change). Message texts come from admin-editable **template packs**, synced like content.
- **Remote (FCM → APNs/Android):** admin **campaigns** — one-time, recurring (incl. Hijri-calendar-triggered Ramadan/Eid), event-triggered, and audited emergency sends; audience filters; per-timezone fan-out; silent config-refresh pushes update local schedules/templates.
- **Catalog & preferences:** backend-defined catalog (id, category, localized title/help text, defaults, delivery class) renders the Settings screen; per-type user toggles + offsets synced; server enforces preferences for remote, client for local. New notification types appear without app releases.

## 6. Widget Architecture

- Widgets read from an app-group-shared store (iOS App Group container / Android shared Room-DataStore), never hit the network themselves. The app precomputes a multi-day timeline of prayer entries after any location/config change.

## 7. AI Layer (design now, build later)

```
POST /v1/ai/fatwa-search | /v1/ai/hadith-extract | /v1/ai/question
        → AIGateway (interface)
            → provider adapters (Claude first; interchangeable)
            → retrieval: admin-curated KB (pgvector) with source-tier ranking
        ← answer + mandatory citations[] + confidence + refusal states
```

- Server-side only; mobile apps never hold AI provider keys. Provider adapters cover Anthropic, OpenAI, Google Gemini, Azure OpenAI, and self-hosted/local models behind one interface; **routing rules** (feature → provider/model/params), prompts, and system prompts are versioned dashboard-managed config — switchable without mobile changes. Search/retrieval providers are abstracted the same way.
- Fatwa-class answers **must** carry citations; otherwise return a structured refusal directing users to qualified scholars. Admin dashboard controls prompts, source whitelist, and provider config.

## 8. Quality & Delivery Infrastructure

- **CI:** per-platform pipelines (build, unit tests, lint/format, snapshot tests for design-system components); backend contract tests against the OpenAPI spec; migration checks.
- **Testing focus:** golden-file tests for prayer calculations (≈20 cities × methods × dates incl. high latitude + DST transitions), streak-engine property tests (timezones, offline gaps, day boundaries), ViewModel state-machine tests.
- **Observability:** Crashlytics + Firebase Analytics (event taxonomy doc), structured logs in Edge Functions.
- **Feature flags:** backend `config` domain, evaluated per-platform, admin-managed.
