# ADR-0012: Leaderboards, streaks, and missions defined as data (rules-as-data engine)

- **Status:** Accepted 2026-07-04 (extends ADR-0007)
- **Date:** 2026-07-04

## Context
Requirement: admins must configure leaderboard types (global/country/city/friends × weekly/monthly/seasonal/lifetime × challenge-specific), ranking/point/eligibility/tie-break/visibility/reward rules, and the streak system (day boundaries, grace, missions, badges, milestones) — all without app updates.

## Decision
Gamification becomes a **definition-driven engine**. The server stores *definitions*; the apps render *descriptors*; nothing about a specific leaderboard or mission is hardcoded in clients.

1. **Leaderboard definitions** (`gamification.leaderboard_defs`): `{scope: global|country|city|friends, period: weekly|monthly|seasonal|lifetime|challenge, metric, eligibility rules, tie_breakers[], visibility, display_requirements (e.g. published-name needed), rewards[], season schedule, enabled}`. `pg_cron` materializes ranked snapshots per active definition. Apps call `GET /v1/leaderboards` → list of active boards (localized title, columns, my-rank, entries) and render generically. Friends scope is a future definition, not future client code.
2. **Point & ranking formulas** as a **constrained declarative form** — weighted sums over named activity-event counters with caps, decay, and bonus terms, validated by the dashboard. Explicitly **not** arbitrary code/scripting: formulas must be auditable, deterministic, and safe (the failure mode "admin typo makes leaderboard nonsense" must stay recoverable via recompute from the event log).
3. **Streak definitions**: category streaks and the overall streak defined as data — qualifying event types, required daily quantity, **day-boundary policy** and **grace rules** (count, recovery window, travel/sickness allowances) all server-side per ADR-0007's server-authoritative event fold.
4. **Missions/challenges/badges/achievements/milestones**: admin-authored entities with localized content, criteria (same constrained form), schedule (daily/weekly/seasonal), rewards. `GET /v1/gamification/profile` returns the user's assembled state (streaks, active missions + progress, badges).
5. Since raw events are the source of truth, **rule changes apply prospectively by default**, with an explicit admin "recompute period" action for corrections.

## Consequences
- Clients contain zero scoring logic — they render descriptors and submit idempotent activity events (unchanged from ADR-0007).
- New event types still need app releases (they originate from real user actions); new *combinations* of existing events don't. The event vocabulary is therefore designed broadly up front (`docs/features/gamification.md`).
- City-scope boards need city-level location consent — privacy decision in OPEN_QUESTIONS.
