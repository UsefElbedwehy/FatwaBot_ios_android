# ADR-0007: Gamification with Islamic-identity guardrails; server-authoritative streaks

- **Status:** Accepted 2026-07-04 (**product-sensitive — approved**)
- **Date:** 2026-07-04

## Context
The foundation asks for engaging gamification "respecting the application's Islamic identity." Public competition over worship risks *riya'* (ostentation) and community backlash; naive streaks punish travelers, the sick, and timezone changes.

## Decision
1. **Leaderboards are opt-in** and pseudonymous by default (auto-generated handle; publishing a real display name is a second explicit step, per the foundation's "may optionally publish").
2. Ranking measures **consistency** (streak length, challenge completion) — never raw worship volume; no "most prayers" style boards.
3. Achievements and streaks are **private by default**; sharing is explicit per item.
4. Branded streak identity (crescent-ember motif per design direction) — no fire emoji, per the foundation.
5. **Server-authoritative streaks** folded from idempotent client activity events (client UUID + timestamp + timezone). Day boundary and grace mechanics (offline sync grace, travel allowance) defined in the gamification feature spec; open product choices tracked in OPEN_QUESTIONS.
6. All gamification copy reviewed for religious tone (encouraging istiqamah, not competition in piety).

## Consequences
Slightly more backend work (event pipeline, projections) in exchange for un-cheatable leaderboards and a defensible product stance. Requires timezone-handling property tests.
