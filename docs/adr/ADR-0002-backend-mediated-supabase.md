# ADR-0002: All clients go through a versioned REST Backend API; Supabase is an implementation detail

- **Status:** Accepted 2026-07-04 (endorses foundation)
- **Date:** 2026-07-04

## Context
Supabase client SDKs + RLS would let apps talk to Postgres directly, saving a proxy hop. The foundation forbids this for mobile.

## Decision
Mobile apps and the admin dashboard communicate only with our versioned REST API (`/v1`, `/admin/v1`), implemented initially as Supabase Edge Functions. Firebase is used only for push, analytics, crash reporting. Service-role keys exist only server-side. RLS remains enabled deny-by-default as defense in depth.

## Rationale
One home for business logic (the streak engine must be server-authoritative anyway), provider replaceability, no schema knowledge in clients, auditable admin writes. Latency cost is neutralized by the offline-first client policy — no interactive worship path blocks on the network.

## Consequences
Contract-first development: OpenAPI specs in `backend/openapi/` with contract tests. If Edge Function limits bite (long AI calls, cron complexity), the API contract lets us relocate the backend without client changes.
