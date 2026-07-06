# Feature Spec: Leaderboard Engine (M3)

> Implements ADR-0012's leaderboard half. Ranks **consistency** (streak length, mission/challenge completion) — never raw worship volume — per ADR-0007's guardrail against *riya'*.

## Resolved product decisions this spec encodes
- **Q2c:** city-scope boards are opt-in only. A user's city is never collected passively; joining a city board is the explicit action that captures it, and it can be cleared/changed at any time from the same opt-in screen.
- Leaderboards are opt-in and pseudonymous by default (ADR-0007): joining generates an auto-handle; publishing a real display name is a distinct, explicit second step (reuses `accounts.md`'s `display_name`).

## Domain model (`gamification.leaderboard_defs`, admin content — same generic CRUD as streak_defs/missions/badges)
- `key`, `name_translations`, `scope` (`global | country | city`), `period` (`weekly | monthly | seasonal | lifetime | challenge`), `metric` (a point formula, see below), `eligibility` (`{ min_account_age_days?, requires_streak_key? }`), `tie_breakers: string[]` (ordered fallback metrics), `visibility` (`public | opt_in_only`), `display_requirements` (`{ requires_published_name: boolean }`), `rewards_translations`, `season` (`{ starts_at, ends_at }`, nullable outside `seasonal`/`challenge`), `enabled`.
- **Point formula** (constrained declarative form, ADR-0012 point 2): `terms: [{ event_type, weight, cap_per_period }]` — `points = Σ weight_i * min(count_of(event_type_i, period), cap_per_period_i)`. No arbitrary code; a formula is just data, so a bad admin edit is fixable by editing the row and re-triggering a snapshot, not a deploy.
- `leaderboard_memberships` (not admin content): `user_id`, `leaderboard_def_id` (or scope generically), `handle` (auto-generated pseudonym), `publish_name: boolean`, `city` (nullable, only set when opted into a city board), `joined_at`.
- `leaderboard_snapshots` (not admin content): `leaderboard_def_id`, `period_key` (e.g. `2026-W28`), `rank`, `user_id`, `score`, `computed_at` — materialized, not computed per-request.

## Snapshot materialization
A scheduled job (Postgres `pg_cron` once Supabase is live; a Deno cron-equivalent task in the interim per the backend's current local-dev setup) recomputes snapshots per **enabled, published** `leaderboard_def` on its period cadence (e.g. daily for `weekly`/`monthly`, immediately on season boundary for `seasonal`). Recompute is idempotent and safe to rerun (pure function of `activity_events` + membership + current def).

## API
- `GET /v1/leaderboards` — authenticated. Returns the list of boards the user is eligible/opted into: `{ key, name, scope, period, my_rank, entries: [{ rank, handle, display_name?, score }] }`. A board the user hasn't joined is listed with `my_rank: null` and a join affordance, not hidden — discoverability matters for an opt-in system.
- `POST /v1/leaderboards/{key}/join` — body: `{ publish_name: boolean, city?: string }` (`city` required only for `scope: city` boards — this is the one explicit action that captures city, per Q2c). Generates a pseudonymous handle if the user has none yet.
- `POST /v1/leaderboards/{key}/leave` — removes membership (and any city association captured only for that board).
- `PATCH /v1/leaderboards/{key}/membership` — body: `{ publish_name?, city? }` — change publish/city choice without leaving.

## Client behavior
- A single generic leaderboard renderer (board header, my-rank card, ranked list) drives every board — no per-scope or per-period client code; unknown `scope`/`period` values render generically rather than crashing (forward-compatible, matching the Home section catalog's unknown-type-skipping discipline).
- Join flow: explicit opt-in screen — pseudonym shown first, "publish my name instead" as a secondary toggle, city picker shown only for boards with `scope: city` and framed as optional/reversible.
- Never renders a "most prayers" or worship-volume metric — only consistency-based boards render (enforced by admin-authored `metric` definitions, not a client-side filter, but the client's copy/design should never imply raw worship is being ranked).

## Tests
- Backend: point formula correctly sums weighted, capped counters per period; tie-breakers apply in order; snapshot recompute is idempotent (rerunning produces the same ranks for unchanged input); joining a city board without supplying `city` is rejected; leaving a board clears its city association without affecting other boards' memberships.
- Both platforms: generic renderer handles an unknown `scope`/`period` value without crashing; join/leave/publish-name toggle round-trips correctly; a user with no leaderboard membership sees discoverable-but-unjoined boards, not an empty screen.
