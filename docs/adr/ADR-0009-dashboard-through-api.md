# ADR-0009: Admin Dashboard (Next.js) consumes the same backend via /admin/v1

- **Status:** Accepted 2026-07-04 (**amends by extension** — foundation is silent on dashboard↔Supabase)
- **Date:** 2026-07-04

## Context
The foundation forbids mobile→Supabase but doesn't specify the dashboard. Direct Supabase access from the dashboard would create a second, unaudited write path and duplicate business logic.

## Decision
- Dashboard: **Next.js + TypeScript** (server components; shadcn/ui-class component library; Arabic/RTL support).
- It consumes `/admin/v1/...` on the same backend API, authenticated with admin-role JWTs (Supabase Auth roles behind our API).
- Every admin mutation writes an audit log entry (who, what, before/after).
- Content workflow (azkar/dua/announcements/challenges): draft → review → publish, versioned; apps sync published versions only.
- Scope (stakeholder directive 2026-07-04): the dashboard is the **operational control center** — users/roles/moderators, AI ops (providers, fallback chains, prompts, safety policies, usage/token/cost monitoring), branding/themes/remote config/feature flags, Home layout composer, widget config, prayer defaults, full CMS, gamification definition editors, campaign composer with segments + analytics, platform analytics, audit logs, application health. Domain-based navigation and per-domain permissions so it expands without redesign.

## Rationale
"The dashboard is the source of truth" is realized through one audited write path; Supabase stays replaceable everywhere; business rules (e.g. challenge validation) live once.

## Consequences
Admin API surface must be specified alongside each feature it manages (content in M2, gamification in M3, AI in M5). Slightly more backend endpoints in exchange for auditability and consistency.
