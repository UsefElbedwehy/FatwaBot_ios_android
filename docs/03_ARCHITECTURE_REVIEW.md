# Architecture Review — Challenges to the Foundation

> The foundation invites challenge ("Challenge weak ideas"). This document records each significant decision I examined, the challenge, and the resolution. Each resolution is captured as a Proposed ADR. **Amendments** change the literal text of the foundation and need your sign-off; **Endorsements** confirm the foundation's call after scrutiny.

## A. Amendments (deviations from the literal foundation — approval needed)

### A1. Prayer times must be computed on-device, not fetched from the backend — ADR-0003
The foundation routes *everything* through `Presentation → ... → Backend API → Supabase`. Applied literally to prayer times, that makes the app's core feature depend on connectivity and backend uptime — unacceptable for a worship utility (airplane mode, poor networks, backend outage during Fajr). **Resolution:** the strict layering still holds for *data*, but prayer times are *computation*: calculate on-device with a battle-tested algorithm; the backend supplies only configuration defaults (per-country calculation method, admin overrides). Same reasoning for Qibla (pure sensors + geometry). This preserves the foundation's intent (backend owns business *policy*) while making worship features offline-perfect.

### A2. Classic UIKit-style Coordinator doesn't fit SwiftUI — amended MVVM-C — ADR-0005
The Coordinator pattern was designed around UIKit's imperative `UINavigationController`. Recreating it verbatim in SwiftUI (iOS 17+) fights `NavigationStack`, breaks deep links and state restoration, and adds indirection without benefit. **Resolution:** keep the *responsibility* (views never navigate themselves; flow logic is testable and centralized) but implement it as typed route enums + per-flow router objects driving `NavigationStack` paths — "MVVM-C, SwiftUI-native dialect." Android equivalent: feature nav-graphs composed by the app module; ViewModels emit navigation events, never navigate.

### A3. "Factory DI" interpreted per-platform — ADR-0006
Factory (hmlongco/Factory) is an iOS-ecosystem library; there is no idiomatic Compose equivalent, and hand-rolled factory containers on Android would be a maintenance liability. **Resolution:** Factory on iOS (as specified); **Hilt** on Android — same intent (compile-time-safe, container-based DI with test overrides), idiomatic per platform.

### A4. Admin Dashboard should go through the same Backend API, not talk to Supabase directly — ADR-0009
The foundation forbids *mobile* → Supabase but is silent on the dashboard. Letting the dashboard hit Supabase directly creates a second, unaudited write path and splits business logic. **Resolution:** dashboard consumes `/admin/v1/...` on the same backend; every admin mutation is audited; "the dashboard is the source of truth" is realized through the API, keeping Supabase replaceable everywhere.

### A5. Anonymous-first authentication — ADR-0004
The foundation lists Authentication as a module but not its policy. Requiring sign-up before showing prayer times would be a retention disaster for a utility app. **Resolution:** full anonymous use (device-scoped identity issued by our API); account sign-in (Apple/Google) required only for leaderboards, display names, and cross-device sync; anonymous → account linking preserves history. *This is a product decision — please confirm.*

### A6. Gamification needs Islamic-identity guardrails, not just "engaging" — ADR-0007
Public competition over worship risks *riya'* (ostentation in acts of worship) and community backlash. **Resolution:** leaderboards opt-in and pseudonymous by default; ranking based on consistency (streaks, challenge completion), never raw worship volume ("prayed 47 rak'ahs" style metrics are out); private-by-default achievements; branded streak iconography per the foundation; copy reviewed for religious tone. Server-authoritative streaks with offline grace and explicit timezone rules.

## B. Endorsements (foundation decisions upheld after challenge)

### B1. Native SwiftUI + Compose (no KMP/Flutter) — ADR-0001
Challenged: two native apps double feature work; KMP could share the domain layer. Upheld: premium feel, widgets, sensors (qibla), notification reliability, and platform-idiomatic UX are the product's core value; KMP adds build complexity and hiring constraints for a codebase where the hard logic (prayer calc) already exists as mature native libraries. Mitigation for duplication: single-source feature specs + shared OpenAPI contract + mirrored module layout (see 02_ARCHITECTURE §3).

### B2. Backend-mediated Supabase, versioned REST — ADR-0002
Challenged: proxying everything adds latency and edge-function cost vs. Supabase client SDKs with RLS. Upheld: provider replaceability, one place for business logic (streak engine especially must be server-authoritative), no service keys or schema knowledge in clients. Latency is mitigated by the offline-first cache policy — no interactive path blocks on the API.

### B3. Supabase + Firebase split — part of ADR-0002
Challenged: two vendor ecosystems. Upheld: FCM is effectively mandatory for Android push and fine for iOS via APNs; Crashlytics/Analytics are best-in-class free tiers; Supabase gives Postgres+RLS+cron+pgvector which Firebase can't match for this domain. Boundaries are clean (Firebase = delivery/telemetry side channels only).

### B4. Feature-first modularization + Clean Architecture — ADR-0010
Upheld as specified; enforced with SPM packages / Gradle convention plugins and a dependency-direction rule (feature → core, never feature → feature; cross-feature flows composed at app level).

### B5. مزايا before AI
Upheld emphatically: worship utilities build daily-habit retention and trust; AI features are trust-sensitive and content-dependent (need the admin KB pipeline first). The AI *interfaces* are still designed now (ADR-0008) so the Home design and API surface don't churn later.

## C. Improvements proposed beyond the foundation

1. **Live Activity / Dynamic Island prayer countdown (iOS)** — natural premium differentiator; post-MVP (M4).
2. **Content pipeline with review workflow** — azkar/dua content versioned, draft→review→publish in the dashboard, delta-synced to apps. Prevents "typo in a dua shipped to millions" incidents.
3. **Notification catalog driven by backend config** — new reminder types without app releases (02_ARCHITECTURE §5).
4. **Golden-file prayer-time test corpus** — correctness as a first-class deliverable, not a QA afterthought.
5. **Analytics event taxonomy doc** from day one — retro-fitted analytics never recovers.
6. **Streak "grace" mechanics** (travel/sickness allowances, Ramadan schedule shifts) — humane and religiously considerate; needs product input (OPEN_QUESTIONS).
7. **Home screen redesigned around "next prayer" as the hero** rather than AI search bars — see [05_DESIGN_DIRECTION.md](05_DESIGN_DIRECTION.md). AI remains present but subordinate until those features ship.

## D. Decisions deliberately deferred

- Persistence library choice on iOS (SwiftData vs GRDB) — M0 spike, low blast radius behind repository interfaces.
- AI provider selection & embedding strategy — Phase AI; interface fixed now (ADR-0008).
- Live Activities, Apple Watch / Wear OS — parked in FUTURE_IMPROVEMENTS.
