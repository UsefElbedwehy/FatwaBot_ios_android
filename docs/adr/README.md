# Architecture Decision Records

All ADRs 0001–0015 were **Accepted 2026-07-04** with the stakeholder's final approval of the planning package (including the configurable-by-default and tenancy-readiness directives).

| ADR | Title | Type |
|---|---|---|
| [0001](ADR-0001-native-apps-no-cross-platform.md) | Native SwiftUI + Compose, no cross-platform framework | Endorses foundation |
| [0002](ADR-0002-backend-mediated-supabase.md) | All clients through versioned REST API; Supabase hidden | Endorses foundation |
| [0003](ADR-0003-on-device-prayer-computation.md) | Prayer/Qibla computed on-device; backend = config only | **Amends foundation** |
| [0004](ADR-0004-anonymous-first-auth.md) | Anonymous-first auth, backend-mediated Supabase Auth | **Product decision** |
| [0005](ADR-0005-swiftui-native-mvvm-c.md) | MVVM-C in SwiftUI-native dialect (typed routers) | **Amends foundation** |
| [0006](ADR-0006-dependency-injection.md) | Factory (iOS), Hilt (Android) | Interprets foundation |
| [0007](ADR-0007-gamification-islamic-guardrails.md) | Gamification guardrails; server-authoritative streaks | **Product-sensitive** |
| [0008](ADR-0008-ai-gateway-citations.md) | AI gateway, provider abstraction, citation-mandatory | Endorses foundation |
| [0009](ADR-0009-dashboard-through-api.md) | Dashboard through /admin/v1 on same backend | Extends foundation |
| [0010](ADR-0010-monorepo-feature-first-modules.md) | Monorepo, mirrored feature-first modules | Endorses foundation |
| [0011](ADR-0011-server-driven-configuration.md) | Server-driven configuration & Home layout platform | **New requirement (2nd pass)** |
| [0012](ADR-0012-gamification-rules-as-data.md) | Leaderboards/streaks/missions as data-driven definitions | **New requirement (2nd pass)** |
| [0013](ADR-0013-notification-campaign-engine.md) | Admin-managed notification campaign engine | **New requirement (2nd pass)** |
| [0014](ADR-0014-multi-locale-content-strategy.md) | Multi-locale content strategy (16+ language ambition) | **From design review** |
| [0015](ADR-0015-configurable-by-default-and-tenancy-readiness.md) | Configurable-by-default principle; tenancy-ready schemas | **Stakeholder directive** |

Convention: one decision per file, `Status: Proposed → Accepted → (Superseded by ADR-XXXX)`. New ADR whenever a decision with real alternatives is made.
