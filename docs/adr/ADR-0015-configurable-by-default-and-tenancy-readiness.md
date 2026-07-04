# ADR-0015: Configurable-by-default principle; multi-tenancy-ready schemas

- **Status:** Accepted (stakeholder directive, 2026-07-04)
- **Date:** 2026-07-04

## Context
Final pre-implementation directive: prefer backend configurability over hardcoding unless a clear technical, security, performance, or platform limitation exists; the platform must evolve for years without unnecessary store releases. Additionally, avoid schema/service assumptions that only one application/organization will ever exist — without implementing multi-tenancy now.

## Decision
1. **Configurable-by-default test.** Every implementation decision that embeds a value, rule, list, layout, or text in mobile code must pass one of four exemptions: *technical* (needs native capability, e.g. widget types), *security* (e.g. certificate pinning set, auth flows), *performance* (e.g. prayer astronomy on device per ADR-0003 — note: its *defaults* are still remote), or *platform* (store metadata, app icon, launch screen). Otherwise it lives in backend config/content (ADR-0011..0014). Code review enforces this; `docs/guides/CONFIGURABILITY.md` catalogs what is configurable and the approved exemptions.
2. **Clients render; backend decides.** Mobile apps are renderers + interaction executors + offline caches. Any branching on business policy (eligibility, scoring, availability, ordering) must consume a backend-provided value, not a compiled constant. Bundled defaults exist only as offline fallbacks and mirror server values.
3. **Tenancy-ready, not multi-tenant.** Every backend table that stores configuration, content, campaigns, gamification definitions, AI settings, or analytics carries `app_id uuid not null default '<primary-app-uuid>'` referencing `apps(id)`, and unique constraints are scoped `(app_id, …)`. Services resolve config through an app-scoped context object rather than global singletons; JWTs carry `app_id` as a claim. No tenant routing, isolation, or admin UI is built now — the cost today is one defaulted column and query discipline; the payoff is white-labeling or a second product without schema surgery.

## Consequences
- API surface unchanged for now (single app resolved server-side from the token/key).
- User-owned rows (events, preferences) inherit app scope through their user; only definition/config tables carry the column directly.
- RLS policies include `app_id` predicates from day one, making future isolation additive rather than a rewrite.
