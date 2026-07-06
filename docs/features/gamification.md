# Feature Spec: Gamification Engine — Activity Events, Streaks, Missions, Badges (M3)

> Implements ADR-0007 (Islamic-identity guardrails, server-authoritative streaks) and ADR-0012 (rules-as-data). Clients submit idempotent activity events and render server-assembled descriptors; **zero scoring or streak logic lives in the apps**.

## Resolved product decisions this spec encodes
- **Q5:** streaks/missions/badges only ever qualify on verifiable in-app actions (`azkar_completed`, `tasbeeh_session_completed`, `wird_ticked`, `wird_day_completed`, `hadith_entry_read`, …) — never a self-reported "I prayed" tap. A private prayer journal, if built later, is explicitly out of the event vocabulary that feeds gamification.
- **Q4:** the streak "day" is Fajr-to-Fajr, shown to the user simply as "today"; day-boundary policy and grace mechanics are **admin-editable data**, not hardcoded constants, so the rules can change without an app release.

## Why day-boundary is a configurable approximation, not astronomical Fajr
Prayer times are computed **on-device** (ADR-0003) — the backend never runs the prayer-calculation library and activity events don't necessarily carry the user's location. Server-authoritative streak folding therefore approximates "Fajr-to-Fajr" with an **admin-configurable fixed local clock time** (default `04:00`) rather than true astronomical Fajr per city. This is a deliberate, documented simplification: it captures the product intent (the day doesn't roll over at a worship-insensitive local midnight) without requiring server-side geolocation or astronomical computation. `streak_defs.day_boundary_local_time` is admin-editable per Q4's requirement.

## Reusing the admin-content mechanism for definitions
Streak/mission/badge/achievement/leaderboard **definitions** are admin-authored, versioned, draft→publish data — structurally identical to the content rows task 27 already built a generic CRUD for (`AdminContentRow { id, published, version, fields }`). Rather than a parallel bespoke admin API, M3 extends `ADMIN_COLLECTIONS` with `gamification` schema tables (`streak-defs`, `missions`, `badges`, `achievements` — leaderboard defs are covered in `leaderboard.md`) that share the exact same shape (`id`, `app_id`, `published`, `version`, `updated_at`) and go through the same `/admin/v1/content/{collection}` routes, audit log included, for free.

## Domain model (`gamification` schema)
- `activity_events` (raw, immutable, **not** admin content): `id`, `app_id`, `user_id`, `event_type`, `client_event_id` (client-generated UUID), `occurred_at` (client-supplied instant), `timezone`, `metadata jsonb`, `created_at`. `unique(app_id, user_id, client_event_id)` — resubmitting the same client event is a no-op (idempotent ingest).
- `streak_defs` (admin content): `key`, `name_translations`, `event_types text[]` (qualifying event types — any one occurring `required_daily_count` times advances the day), `required_daily_count`, `day_boundary_type` (`fixed_local_time | midnight`), `day_boundary_local_time`, `grace_allowance` (grace days available per `grace_period_days` window), `enabled`.
- `missions` (admin content): `key`, `name_translations`, `description_translations`, `criteria` (`{ event_type, target_count, window: daily|weekly|lifetime }`), `schedule` (`daily|weekly|seasonal`), `reward_translations`, `starts_at`/`ends_at` (nullable = always active). SQL column is `progress_window` — `window` is a reserved word in Postgres; the API/engine still call it `window`.
- `badges` (admin content; achievements are represented as badges — same shape, no separate table, per the M3 implementation note below): `key`, `name_translations`, `description_translations`, `icon_ref`, `criteria` (same constrained shape as missions, typically `window: lifetime`), `hidden_until_earned bool`.

> **Implementation note (M3):** badges and achievements are conceptually identical (both are lifetime-criteria unlocks) and were merged into a single `gamification.badges` table / `badges` admin collection rather than two near-duplicate schemas. Revisit only if a real product distinction between the two emerges.
- `user_streak_state` (derived/cached, not admin content): `user_id`, `streak_def_id`, `current_length`, `longest_length`, `grace_remaining`, `last_qualifying_date`.
- `user_mission_progress`, `user_badges` (derived/cached): progress counters and unlock timestamps.

## Constrained criteria form (ADR-0012 point 2)
Every mission/badge/achievement criterion is `{ event_type: string, target_count: integer, window: "daily" | "weekly" | "lifetime" }` — evaluated by counting matching `activity_events` in the window and comparing to `target_count`. No arbitrary expressions; a new *kind* of criterion (e.g. multi-event weighted combos) is a schema extension, not a scripting escape hatch — keeps every rule auditable and recomputable from the event log.

## API
- `POST /v1/gamification/events` — body: `{ events: [{ client_event_id, event_type, occurred_at, timezone, metadata? }] }` (batched, since clients may replay a backlog after being offline). Authenticated (anonymous or account). Returns `{ accepted: number, duplicates: number }`.
- `GET /v1/gamification/profile` — authenticated. Returns assembled state: `{ streaks: [{ key, name, current_length, longest_length, grace_remaining }], missions: [{ key, name, progress, target, window, ends_at }], badges: [{ key, name, icon_ref, earned_at }] }`. Folding happens on read (recomputed from `activity_events` + current published `streak_defs`/`missions`/`badges`, not a separately-drifting cache) — correctness over raw read speed at this scale, revisit if profile reads get expensive.

## Client behavior
- Existing features (Azkar, Tasbeeh, Awrad, Hadith Collections) each emit one activity event on their existing completion moments — no new UI, just a fire-and-forget event submission (queued locally, flushed opportunistically, survives offline).
- Gamification screens render `GET /v1/gamification/profile` verbatim: progress bars, streak counters, badge grids — no client-side counting or day-boundary math.
- Branded streak visuals: crescent-ember motif (mihrab-arch family), never a fire emoji, per the foundation and ADR-0007.
- Achievements/streaks are **private by default**; an explicit per-item "share" action is a future extension, not built in M3.

## Tests
- Backend: idempotent event ingest (resubmitting a `client_event_id` doesn't double-count); streak folding correctly advances/breaks/grants grace across a simulated day-boundary and timezone change; mission/badge progress counts only within their configured window; changing a `streak_def`'s day-boundary time doesn't retroactively rewrite already-computed history (fold is a pure function of current defs + full event log, so this is naturally true — assert it explicitly in a test).
- Both platforms: event queue survives app restart and offline gaps; profile screen renders purely from the server response with no local math.
