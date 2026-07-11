# ADR-0016: iOS Live Activity for the prayer countdown (local-only, no push)

- **Status:** Accepted 2026-07-08
- **Date:** 2026-07-08

## Context
M4 (docs/04_ROADMAP.md) includes a Dynamic Island / Lock Screen Live Activity showing the countdown to the next prayer, per stakeholder approval. Prayer times are computed entirely on-device and offline (ADR-0003) — the countdown target (the next prayer's time) is known in advance for the full day, so the activity does not need server-pushed updates to stay accurate.

## Decision
Implement the Live Activity as a **local-only ActivityKit extension**, with zero dependency on APNs push-update tokens:

1. New widget-extension target (`FatwaBotLiveActivity`, ActivityKit + WidgetKit `ActivityConfiguration`), added alongside the existing `FatwaBotWidgets` extension in `ios/App/project.yml` — same app-group container, reusing `PrayerWidgetSnapshot` as the data source (no new snapshot type needed).
2. `ActivityAttributes` carries only static identifying data (nothing that changes); the mutable `ContentState` holds `{ prayerName: String, prayerTime: Date }`. The Lock Screen / Dynamic Island view renders the countdown via SwiftUI's `Text(timerInterval:)`, which the system animates client-side with zero app wake-ups between updates.
3. The app starts the activity when a user opts in (Settings toggle, off by default — Live Activities are visible on the lock screen, an attention surface not to be claimed silently) and calls `update()` at exactly two points: whenever `PrayerViewModel` computes a new "next prayer" (a state transition that already exists) and at each prayer transition. No background refresh, no silent push, no APNs token machinery.
4. The activity self-expires (`ActivityConfiguration`'s `staleDate`) shortly after the countdown target passes, and the app explicitly `end()`s it at local midnight — matching the existing day-boundary handling already in `PrayerViewModel`.
5. Android has no Live Activity equivalent; this is an iOS-only enhancement (Android's persistent-notification-with-progress is a separate, smaller follow-up if requested later — not in scope here).

## Consequences
- Zero backend or push infrastructure required — consistent with ADR-0003's offline-first philosophy; nothing new to deploy or credential (does not depend on Q8's Firebase/APNs setup).
- Opt-in, not opt-out: avoids surprising users with an unrequested lock-screen presence.
- `update()` calls are cheap and infrequent (a handful of times per day, driven by existing state transitions) — no new scheduling infrastructure, no drain on the existing local-notification budget (ADR distinct from the adhan/pre-adhan local notifications, which continue unchanged).
- Widget-extension target proliferation: this is the second ActivityKit/WidgetKit extension in `ios/App/project.yml`; if a third is ever needed, consolidate into one extension bundle rather than adding a fourth process.
