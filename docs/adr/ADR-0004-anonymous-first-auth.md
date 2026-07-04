# ADR-0004: Anonymous-first authentication, backend-mediated Supabase Auth

- **Status:** Accepted 2026-07-04 (**product decision — approved**)
- **Date:** 2026-07-04

## Context
The foundation lists Authentication as a module without policy. Forcing sign-up before prayer times would crater retention for a utility app.

## Decision
- App is fully usable with zero sign-up: `/v1/auth/anonymous` issues a device-scoped identity (JWT) at first launch.
- Apple/Google sign-in (via `/v1/auth/*`, proxying Supabase Auth) is required only for: leaderboards, publishing a display name, cross-device sync.
- Anonymous → account linking migrates all history (streaks, tasbeeh counts, settings) losslessly.
- Mobile apps hold tokens as opaque values; no Supabase Auth SDK on clients (consistent with ADR-0002).

## Consequences
All M1/M2 features must function against anonymous identity. Streak data model keys on user-id from day one so linking is a re-parent, not a migration. Account deletion (store requirement) deletes both identity classes.
