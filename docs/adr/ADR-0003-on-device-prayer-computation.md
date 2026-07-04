# ADR-0003: Prayer times and Qibla are computed on-device; backend supplies configuration only

- **Status:** Accepted 2026-07-04 (**amends** the foundation's literal layering)
- **Date:** 2026-07-04

## Context
The foundation routes everything through the Backend API. Prayer times are the app's most-used feature and must work in airplane mode, abroad, and during any backend outage; they are deterministic astronomy, not data.

## Decision
Compute prayer times (and Qibla bearing) on-device using a battle-tested implementation of the Adhan algorithm family (Swift/Kotlin ports validated in an M0 spike). The backend provides only *policy*: per-country default calculation methods, admin overrides, Hijri offset defaults — via `/v1/config/prayer-defaults`, cached with shipped fallbacks.

## Rationale
Offline correctness is non-negotiable for a worship utility; notification scheduling and widget timelines also need multi-day local computation. The foundation's intent — backend owns business *policy* — is preserved.

## Consequences
Correctness burden shifts to the client: a golden-file test corpus (~20 cities × methods × dates, high-latitude and DST cases) gates CI on both platforms. Method/madhab/adjustment settings must produce identical results on iOS and Android.
