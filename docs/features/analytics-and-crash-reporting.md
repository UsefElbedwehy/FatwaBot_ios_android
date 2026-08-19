# Analytics & Crash Reporting

_Status: implemented 2026-07-25, both platforms. Product analytics runs on our
**own first-party ingest** (`POST /v1/analytics/events`) on iOS and Android.
Crash reporting: Firebase Crashlytics on Android, TestFlight/Xcode Organizer on
iOS._

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

`AnalyticsTracking` is the only thing feature modules see — mirroring the
existing `ActivityEventRecording` / `HapticsProviding` boundaries, so neither a
vendor SDK nor a transport leaks into features (ADR-0010), and they stay
unit-testable via `NoopAnalyticsTracking`.

```
iOS
  CoreKit        AnalyticsTracking (protocol) + AnalyticsEvents (name constants)
                 QueuedAnalyticsEvent + FileAnalyticsEventQueueStore (capped)
  NetworkingKit  BackendAnalyticsRecorder  ─→ POST /v1/analytics/events
  App            AnalyticsPreferences      ─ the opt-out, local only

Android
  :core:common   AnalyticsTracking (interface) + AnalyticsEvents  [same names]
  :core:network  BackendAnalyticsRecorder  ─→ POST /v1/analytics/events
  :app           CompositeAnalyticsTracking ─ fans out to both sinks
                 FirebaseAnalyticsTracker   ─ Firebase Analytics + Crashlytics
                 AnalyticsPreferences       ─ the opt-out, one switch for both
```

`AnalyticsEvents` names are **identical across platforms** — a mismatch would
silently split a metric across two names in the dashboard and stay invisible
until someone questions the numbers.

### Why our own pipeline rather than Firebase everywhere

Firebase Analytics would have needed `firebase-ios-sdk` on iOS — a heavy
dependency we'd already declined for push. More importantly, a worship app's
usage data is exactly the sort of thing worth keeping first-party: the ingest is
ours, the retention policy is ours, and there's no third party to reason about.

Android **dual-sends** (Firebase *and* our ingest) via
`CompositeAnalyticsTracking`, which wraps each child in `runCatching` so one sink
failing can't stop the other. Firebase was already wired and gives free
aggregate/retention dashboards, and Crashlytics uses Analytics for breadcrumbs —
but our ingest is the cross-platform source of truth.

Both sinks are governed by the **same** `AnalyticsPreferences` switch, so the
Settings toggle can't leave one of them still reporting. Note that Firebase keeps
its own reserved screen-view schema (`screen_name`); only our sink uses the
`screen_view` / `screen` names above, so the two dashboards aren't directly
comparable field-for-field.

Flush lifecycle: iOS uses `.task` + `scenePhase == .background`; Android uses
`MainActivity.onCreate`/`onStop`. `onStop` was chosen over `ProcessLifecycleOwner`
because the app is single-activity (so `onStop` already *is* backgrounding) and
`lifecycle-process` isn't a dependency — the cost is a redundant flush on
configuration change, which is free since an empty queue short-circuits.

### Transport behaviour

Deliberately **batched**, unlike `GamificationEventRecorder`, which flushes per
event because each event matters individually:

- Events append to a disk-backed queue, **capped at 500** (an offline week must
  not grow an unbounded file or produce a giant first flush; oldest are dropped).
- A request goes out when the queue hits 20 events, or on app launch / when the
  app backgrounds. Posting once per screen view would burn radio for nothing.
- One flush sends the whole queue in one request, then removes only the ids it
  submitted — more may have queued mid-flight.
- A failed flush is silent and leaves the queue intact. The ingest is idempotent
  per `client_event_id`, so retrying a partially-applied request never
  double-counts.
- Consent is re-read on **every** call, so revoking it takes effect immediately
  rather than on next launch, and opting out also discards whatever is queued.

## API

`POST /v1/analytics/events` (Bearer auth), max 100 events per batch:

```json
{ "events": [
  { "client_event_id": "uuid", "name": "screen_view",
    "occurred_at": "2026-07-25T12:00:00Z", "platform": "ios",
    "app_version": "0.1.0", "params": { "screen": "dua" } }
] }
```
→ `{ "accepted": n, "duplicates": n, "rejected": n }`

An individual invalid event is skipped and counted in `rejected`; it never fails
the batch, because one bad event must not drop every good one alongside it.

### Server-side privacy guard

The handler **rejects** any event whose `params` contain a forbidden key
(`query`, `q`, `search`, `text`, `lat`, `lng`, `location`, `city`, `name`,
`email`, `token`, `user_id`, …). It also rejects — rather than truncates — a
param value over 100 characters: legitimate params are short stable keys, so an
oversized value means a client is sending free text under an allowed key, and
truncating would silently persist the first 100 characters of what might be a
user's question.

This is the server's last chance to refuse sensitive data if a client bug ever
starts sending it, which is why the check lives here and not only in the clients.

### Storage

`analytics.events` (migration 0023) — separate schema and table from
`gamification.activity_events`, **not** a reuse of it. That table is read in full
per user by `listEvents` to fold streaks on every `/v1/gamification/profile`
request; writing high-volume screen views into it would slow streak computation
on every profile load and pollute the fold.

Unique on `(app_id, user_id, client_event_id)` for idempotency, indexed on
`(app_id, occurred_at)` and `(app_id, name, occurred_at)`, RLS enabled, and
`on delete cascade` from `identity.users` so deleting a user removes their
analytics. High-volume and prunable — retention trimming is a future ops task.

Event and screen names live in `AnalyticsEvents` as constants rather than inline
string literals, so the same concept can't be logged as `dua_opened` in one
place and `open_dua` in another — which silently splits a metric across two
names in the dashboard and is invisible until someone questions the numbers.

### Screen views

Reported from **one place** — `RootScaffold` observes `(selected tab, worship
destination)` and reports on change. Per-screen `onAppear` hooks were rejected:
they drift as screens are added and quietly stop firing, and nothing fails
loudly when they do.

## What is instrumented (both platforms)

- **Screen views** for every top-level tab and worship destination.
- **`widget_opened_app`** with a `route` param — the one signal that says whether
  the widgets are earning their place on someone's home screen.
- **`non_fatal_error`** with an `error_type` param — the error's *type name only*,
  never its message, which can embed a URL, a file path, or user input.
- Constants are declared for search/tasbeeh/azkar/notification events; call sites
  for those are not all wired yet.

Screen views are reported from **one place** per platform (`RootTabView` on iOS,
`RootScaffold` on Android), observing the current tab + pushed destination.
Per-screen `onAppear`/`LaunchedEffect` hooks were rejected: they drift as screens
are added and quietly stop firing, and nothing fails loudly when they do.

One known blind spot: iOS pushes the Prayer and Leaderboard screens with
view-based `NavigationLink`s rather than typed path values, so those don't appear
in the typed `worshipPath` and are reported as their parent screen. Converting
them to value-based links would close it.

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

## Remaining asymmetry

**Product analytics is now at parity** — both platforms post the same event names
to the same first-party ingest, so one dataset covers both.

**Crash reporting is not, by design.** Android has Crashlytics (real-time,
grouped, with breadcrumbs); iOS relies on TestFlight/Organizer, which is
batched and only covers TestFlight/App Store builds. That was the accepted
trade for not adding `firebase-ios-sdk`. `non_fatal_error` gives iOS a thin
first-party signal (error *type* counts) but is not a crash reporter — it can't
catch a hard crash, since the process is gone before a flush could run.

If iOS crash visibility ever proves insufficient, the options are
`firebase-ios-sdk` (matching Android) or a lighter third-party reporter — both
reintroduce a dependency, so this stays a deliberate open trade rather than an
oversight.

## Setup still required (owner)

- **Apply migration 0023** — `cd backend && supabase db push`. Nothing is
  recorded until then; the clients queue and silently retry, which is the
  intended failure mode but means you'll see no data.
- **Add `analytics` to the Supabase project's exposed schemas** (Dashboard →
  Settings → API). The migration grants PostgREST access, but the dashboard
  setting is authoritative — without it every `/v1/analytics/*` call 500s with
  "schema must be one of …". Same trap migration 0011 documents.
- **Deploy the function** — `supabase functions deploy api` (the new route ships
  with it).
- Rotate the Firebase service-account key that was exposed in chat.
- Add the Android release **SHA-1** to the Firebase project (needed for some
  Firebase features; Crashlytics itself does not require it).
- Apple Developer account for TestFlight / Organizer crash access (Q8).
- Verify end-to-end once deployed: check rows land in `analytics.events`, and
  force a test crash on an Android debug build to confirm Crashlytics before
  relying on it.
