# Configurability Catalog (ADR-0015)

The configurable-by-default test: anything embedded in mobile code must claim one of four exemptions — **technical**, **security**, **performance**, or **platform**. This catalog is the enforcement record; code review checks new hardcodings against it. Update it whenever a value moves between columns.

## Backend-driven (no store release needed)

| Surface | Mechanism | Since |
|---|---|---|
| Feature flags & module availability | `/v1/config` flags (staged rollout, version gates) | M0 |
| Remote config values (Hijri offset default, caps, policies) | `/v1/config` | M0 |
| Theme: colors (light/dark), radii, product display name, logo assets | `/v1/config/theme` over fixed token schema | M0 |
| All UI copy, onboarding content, help texts | `/v1/config/strings/{locale}` versioned packs | M0 |
| Supported languages + script metadata | `/v1/config` locales | M0 |
| Home layout: section order, visibility, props | `/v1/home` → native section catalog | M0 (renderer M1) |
| Prayer calculation defaults per country (method, madhab, high-latitude rule — mandatory ≥48°) | `/v1/config/prayer-defaults` | M0 |
| Worship content: azkar, duas, hadith collections, wird templates | content APIs, versioned publishing | M2 |
| Notification types, templates, offsets defaults, campaigns, segments | catalog/templates/campaigns (ADR-0013) | M2–M3 |
| Gamification: streak rules, day boundaries, grace, missions, badges, achievements, rewards, leaderboard definitions, seasons, point formulas | definitions engine (ADR-0012) | M3 |
| AI: providers, priority, fallback chain, models, sampling params, prompts, system prompts, routing, safety policies, KB sources | AI config domain (ADR-0008) | M5 |
| CMS: announcements, featured content, daily hadith/dua scheduling | blocks-based CMS | M2+ |

## Hardcoded — with claimed exemption

| Item | Exemption | Notes |
|---|---|---|
| App name under icon, app icon, store listings | Platform | iOS alternate icons (pre-shipped set) possible later |
| True launch screen | Platform | Neutral branded launch → themed splash overlay at first frame |
| Widget *types* (extension binaries) | Technical | Widget *content/config* is server-driven |
| Prayer/Qibla astronomy | Performance + offline correctness (ADR-0003) | Policy inputs are remote |
| Section catalog component code | Technical (native UI, ADR-0011) | New section types ship in app updates; unknown types skipped |
| Token *schema* (which tokens exist) | Technical | Values are remote |
| Certificate pinning set, auth flow shape | Security | |
| Bundled fallback defaults (theme, strings, config) | Technical (offline-first) | Must mirror server seed — parity check in CI (M1 TODO) |
| Activity-event vocabulary | Technical | Events originate from real native interactions; combinations are remote |
