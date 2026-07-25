# Analytics & Crash Reporting

_Status: Android implemented 2026-07-25. iOS crash reporting via TestFlight; iOS
product analytics NOT implemented — see [Platform asymmetry](#platform-asymmetry)._

Covers roadmap task M4 #44. The goal is modest and specific: when the client (or
a beta user) says "it closed itself", we should be able to see the stack trace
instead of guessing; and we should be able to tell which worship features are
actually used.

## Privacy rules (binding)

This is a worship app used by anonymous-first users, and analytics goes to a
third party (Firebase). The following are **forbidden payloads**, not merely
discouraged — they are enforced by the boundary interface's contract and must be
upheld by every call site:

| Never send | Why |
| --- | --- |
| **Search queries** | "Is X permissible" is among the most sensitive things a user types. Log *that* a search happened, never *what* it said. |
| **Location** (coordinates or city) | Prayer times are computed on-device (ADR-0003) precisely so location never leaves it. Analytics must not undo that. |
| **Identity** (display name, email, user id, push token) | The app is anonymous-first by design. |
| **Content bodies** (du'a/hadith text, personal wird notes) | A stable category key or id is fine; free text is not. |

Permitted payloads: screen names, stable category keys, counts.

### User opt-out

Reporting is **on by default** — a crash nobody can see is a crash nobody can
fix, and nothing personal is collected. But Settings → Diagnostics has a switch
that disables it, because a user of a worship app who would rather send nothing
at all shouldn't have to uninstall to get that.

The switch calls `setAnalyticsCollectionEnabled(false)` and
`isCrashlyticsCollectionEnabled = false` — it disables the SDKs themselves, not
just our call sites — and the choice is applied on every app start before
anything is reported (`FirebaseAnalyticsTracker.applyPersistedChoice()`).

## Architecture

`AnalyticsTracking` (in `:core:common`) is the only thing feature modules see —
mirroring the existing `ActivityEventRecording` / `HapticsProviding` boundaries,
so Firebase stays an `:app`-only implementation detail (ADR-0010: feature
modules never depend on a vendor SDK, and stay unit-testable via
`NoopAnalyticsTracking`).

```
:core:common   AnalyticsTracking (interface) + AnalyticsEvents (name constants)
:app           FirebaseAnalyticsTracker  ─ Firebase Analytics + Crashlytics
               AnalyticsPreferences      ─ the opt-out, local only
```

Event and screen names live in `AnalyticsEvents` as constants rather than inline
string literals, so the same concept can't be logged as `dua_opened` in one
place and `open_dua` in another — which silently splits a metric across two
names in the dashboard and is invisible until someone questions the numbers.

### Screen views

Reported from **one place** — `RootScaffold` observes `(selected tab, worship
destination)` and reports on change. Per-screen `onAppear` hooks were rejected:
they drift as screens are added and quietly stop firing, and nothing fails
loudly when they do.

## What is instrumented (Android)

- **Screen views** for every top-level tab and worship destination.
- **`widget_opened_app`** with a `route` param — the one signal that says whether
  the widgets are earning their place on someone's home screen.
- Constants are declared for search/tasbeeh/azkar/notification events; call
  sites for those are not all wired yet.

## Crash reporting

| Platform | Mechanism | Notes |
| --- | --- | --- |
| Android | Firebase Crashlytics | Gradle plugin + SDK. Honors the opt-out. `AnalyticsTracking.nonFatal(Throwable)` records handled errors for triage. |
| iOS | **TestFlight / Xcode Organizer** | No third-party SDK. |

### Why no Firebase SDK on iOS

`firebase-ios-sdk` is a heavy dependency, and we already declined it once for
push (see `docs/features/push-notifications.md`). Apple's own pipeline gives
symbolicated crash reports for TestFlight and App Store builds at zero
dependency cost, which covers the actual need — seeing crashes during the
client's review and the beta.

The one requirement is that archives carry dSYMs, or the reports arrive
unreadable. `DEBUG_INFORMATION_FORMAT: dwarf-with-dsym` is pinned for `Release`
in `ios/App/project.yml` rather than left to the Xcode default.

Crash reports appear in **Xcode → Window → Organizer → Crashes** (needs the
Apple Developer account, Q8).

## Platform asymmetry

**iOS has no product analytics.** Crash reporting reaches parity via TestFlight,
but screen views and feature-usage events are Android-only right now. That means
usage data is half-blind — and iOS is the platform demos happen on.

Options to close it, in preference order:

1. **Reuse our own backend event pipeline.** The activity-event ingest built for
   gamification (`/v1/activity/events`) already exists on both platforms, with an
   admin dashboard. Extending it for product analytics keeps everything
   first-party, needs no third-party SDK on either platform, and sidesteps the
   privacy questions entirely. Most work, best outcome.
2. **Add `firebase-ios-sdk`** for Analytics (+ optionally Crashlytics), matching
   Android exactly. Fastest to parity; adds the dependency we've twice avoided.
3. **Leave it.** Acceptable only while Android is the measurement platform and
   iOS relies on TestFlight for crashes.

No option is chosen yet — this needs a product call.

## Setup still required (owner)

- Rotate the Firebase service-account key that was exposed in chat.
- Add the Android release **SHA-1** to the Firebase project (needed for some
  Firebase features; Crashlytics itself does not require it).
- Apple Developer account for TestFlight / Organizer crash access (Q8).
- Verify events land: Firebase console → Realtime, and force a test crash on a
  debug build to confirm the Crashlytics pipeline before relying on it.
