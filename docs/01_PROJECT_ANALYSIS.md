# Project Analysis

> Status: Planning phase — awaiting approval before implementation.
> Date: 2026-07-04

## 1. Repository State (as found)

The repository currently contains **only** the foundation document (PDF + a short markdown summary). Specifically:

| Expected by foundation | Found |
|---|---|
| `prompts/` folder with foundation prompts | ❌ Missing — recreated as `prompts/00_PROJECT_FOUNDATION.md` from the PDF |
| `design/` folder with reference UI | ❌ Missing at first pass — **added 2026-07-04 as `App Demo design/`** (22 screenshots of a web prototype); reviewed in [06_DESIGN_REVIEW.md](06_DESIGN_REVIEW.md) |
| Any application code | ❌ None |
| Git repository | ❌ Not initialized |

**Second-pass update:** the concept demos confirmed the brand (FATWA BOT, mihrab-arch logo, maroon/cream), surfaced two modules absent from the foundation's list — **Awrad (personal wird routines)** and **Hadith Collections (الأربعون learning)** — and validated the opt-in/seasonal leaderboard direction. Both modules are now in scope (roadmap M2). The demo's in-app secret-code admin panel is rejected in favor of the separate dashboard (ADR-0009).

## 2. What We Are Building

A four-part platform:

1. **iOS app** — SwiftUI, iOS 17+, WidgetKit widgets, Live Activities candidate for prayer countdown.
2. **Android app** — Jetpack Compose, Kotlin, Glance widgets.
3. **Backend API** — versioned REST over Supabase (Postgres, Auth, Storage, Edge Functions), with Firebase for push/analytics/crash only.
4. **Admin Dashboard** — separate web app; the operational source of truth for content, configuration, challenges, and feature flags.

Product identity: a **premium Islamic companion** where worship tools (Prayer, Qibla, Azkar, Dua, Tasbeeh) are first-class and AI (Fatwa Search, Hadith Extraction, General Questions) is a later, carefully-sourced layer.

## 3. Domain Analysis — what "production quality" means per module

### Prayer Times
- Must be **correct, offline, and instant**. Users check prayer times in airplane mode, in basements, abroad.
- Calculation methods vary by region (Umm al-Qura, Egyptian General Authority, MWL, ISNA, Karachi, etc.), plus madhab-dependent Asr (Shafi'i vs Hanafi), high-latitude rules, and per-prayer manual adjustments.
- **Implication:** prayer times must be computed **on-device** using a well-tested algorithm (the Adhan algorithm family has mature Swift/Kotlin implementations). The backend supplies *configuration defaults* (per-country method recommendations, admin overrides), never the times themselves. See ADR-0003.
- Hijri date display with user-adjustable offset (±2 days) — Hijri calendars drift by region.

### Qibla
- Pure on-device feature: magnetometer + GPS + great-circle bearing to the Kaaba (21.4225°N, 39.8262°E).
- Hard parts are UX: sensor calibration prompts, magnetic interference detection, accuracy indicator, true-north vs magnetic-north declination correction, and a fallback (sun/map based) when sensors are unreliable.

### Azkar & Dua
- Content-driven: categorized collections (morning, evening, after-prayer, sleep, travel...), with repeat counts, source attribution (Qur'an/Hadith reference), transliteration and translation.
- Content is managed in the Admin Dashboard, versioned, and **cached offline** with a content-version sync protocol — the app ships with a seed bundle so first launch works offline.
- Reading experience matters: large Arabic typography (Uthmanic-style font for Qur'anic text), progress through a session, haptic count taps.

### Tasbeeh
- Fully offline counter with named dhikr presets, target counts, sets, haptics, and history. Syncs counts to backend opportunistically for streaks/stats.

### Search History
- History of the user's AI queries (fatwa/hadith/general) — stored server-side per user, cached locally, deletable (privacy).

### Gamification & Leaderboard
- Streak engine with multiple categories (prayer logging, azkar, tasbeeh, app-defined) + one overall streak; branded streak iconography (no fire emoji).
- **Sensitivity:** public competition over acts of worship risks *riya'* (ostentation) and will draw justified criticism. Design decision (ADR-0007): leaderboards are **opt-in**, pseudonymous by default, and framed around consistency (streaks/challenges), never around raw worship counts. Server-authoritative scoring with offline grace periods and timezone-aware day boundaries (a "day" = the user's local Maghrib-to-Maghrib or midnight boundary — needs a product decision, see OPEN_QUESTIONS).

### Notifications
- Two delivery classes: **local scheduled** (adhan/iqamah offsets, azkar times, third-night — all computable on device, reliable offline) and **remote push** (challenges, announcements, streak-rescue nudges) via FCM/APNs.
- Third-night reminder = last third of the night, computed from Maghrib→Fajr interval; recompute daily.
- Per-notification toggles + offsets + help text ⇒ a notification *preferences schema* shared across platforms and driven by backend config.

### Widgets
- iOS WidgetKit timeline entries can be pre-computed for days ahead (prayer times are deterministic) — no network needed. Android Glance similar with WorkManager refresh.
- Prayer countdown on iOS: timeline with per-minute relevance, plus consider Live Activity for the imminent-prayer window (post-MVP).

### AI Layer (deferred to later phase, designed now)
- RAG over an admin-curated knowledge base (fatwa sources, hadith collections) with mandatory citations; provider-agnostic gateway interface (Claude/others swappable); Arabic-first retrieval quality; strict "no answer without sources" policy for fatwa-class questions with graceful refusal + scholar-referral messaging.

## 4. Cross-Cutting Concerns

- **Localization & RTL:** Arabic-first with full RTL layouts; English secondary. All strings externalized from day one. Arabic numerals config (Eastern vs Western digits).
- **Offline-first:** every مزايا feature works with zero connectivity. Network enhances (sync, leaderboards, content updates) but never gates worship features.
- **Privacy:** location used for prayer/qibla stays on device by default; only coarse country granularity is sent for country leaderboards, with consent. Anonymous-first onboarding (see §5).
- **Accessibility:** Dynamic Type / font scaling, VoiceOver/TalkBack labels for Arabic content, reduced motion, RTL-correct semantics.
- **Performance:** cold start < 1.5s to a useful Home (cached prayer times render immediately); 60/120fps scrolling; widget battery discipline.

## 5. Key Product Insight Not Explicit in the Foundation

**Anonymous-first onboarding.** Forcing sign-up before showing prayer times would kill retention for a utility-class app. Recommendation: the app is fully usable anonymously (device-scoped identity); an account (Supabase Auth via our API) is required only for leaderboards, cross-device sync, and publishing a display name. This shapes the auth architecture (ADR-0004) and must be decided before Milestone 1.

## 6. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Missing `design/` assets → product-intent gaps | Medium | Design direction doc + Home spec produced; request assets in parallel; validate with stakeholder at each milestone |
| Prayer-time correctness errors (religious-trust killer) | High | On-device battle-tested algorithm, golden-file tests against published official timetables for ~20 cities/methods |
| Gamification backlash (riya' concerns) | Medium | ADR-0007 opt-in/pseudonymous design; framing review |
| Notification reliability (OEM battery killers on Android, iOS 64-local-notification limit) | High | Rolling scheduling window (next 3–5 days), reschedule on app open/BG task/push-triggered refresh; consolidate per-prayer notifications |
| Scope: 4 platforms, ~18 modules | High | Strict milestone gating (roadmap), backend+content contracts first, iOS and Android tracked in lockstep per feature |
| Supabase Edge Function limits (cron, long AI calls) | Medium | Versioned REST contract keeps backend replaceable (ADR-0002); AI gateway can move to a dedicated service later |

## 7. Planning Deliverables Index

- [prompts/00_PROJECT_FOUNDATION.md](../prompts/00_PROJECT_FOUNDATION.md) — canonical foundation (from PDF)
- [02_ARCHITECTURE.md](02_ARCHITECTURE.md) — system & app architecture
- [03_ARCHITECTURE_REVIEW.md](03_ARCHITECTURE_REVIEW.md) — challenges to foundation decisions + resolutions
- [04_ROADMAP.md](04_ROADMAP.md) — milestones & sequencing
- [05_DESIGN_DIRECTION.md](05_DESIGN_DIRECTION.md) — design system + Home screen redesign spec
- [adr/](adr/) — Architecture Decision Records (proposed, pending approval)
- [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md) — decisions requiring stakeholder input
- [CHANGELOG.md](../CHANGELOG.md)
