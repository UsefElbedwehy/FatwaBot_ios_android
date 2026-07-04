# Feature Spec: Prayer (M1)

> On-device prayer engine + Prayer surface + notifications + widgets (ADR-0003). Single-source spec for both platforms. PrayerKit (iOS) exists from the M0 spike; Android mirrors it over adhan-kotlin with the same golden corpus.

## Domain model
- `PrayerSettings` — method, madhab, highLatitudeRule (mandatory ≥48° — spike finding), per-prayer manual adjustments (±30 min), hijriOffsetDays. Defaults resolved: user override → `/v1/config/prayer-defaults(country)` → bundled `*` fallback.
- `PrayerDay` — the six times for a civil date at a location + metadata (method used).
- `NextPrayerState` — current prayer window, next prayer, countdown target; drives Home hero, widgets, and (later) Live Activity from one render model.
- `LocationSource` — `gps(lat,lng)` or `manualCity(cityId)`; last known location cached; the app must be fully functional with a manual city and no location permission.

## Use cases
`GetPrayerDay(date, location, settings)` · `GetNextPrayer(now)` · `GetQiblaBearing(location)` · `UpdatePrayerSettings` · `ResolveDefaultSettings(country)` · `PrecomputeTimeline(days: 5)` (feeds notifications + widgets)

## Screens & states
1. **Prayer screen** — today's six times (current highlighted, past dimmed), date header (Hijri + Gregorian, offset applied), method footnote (tap → settings), day pager (±7 days). States: no-location (city picker inline, not a blocking wall), stale-location hint, loading skeleton only on very first resolve.
2. **Qibla screen** — compass with bearing, accuracy indicator, calibration prompt (figure-8) when sensor accuracy low, magnetic-interference warning, declination-corrected true north. Fallback static bearing display when sensors unavailable (iPad without magnetometer).
3. **Settings ▸ Prayer** — method (from config-driven list), madhab, high-latitude rule (auto by default), per-prayer adjustments, Hijri offset. Every option has help text (string packs).

## Notifications (local engine v1)
- Per-prayer adhan notification + optional pre-adhan offset (5–60 min), per-prayer toggles; iqamah offset reminder (M1 scope: adhan + pre-adhan; iqamah in M2 catalog).
- Rolling 3-day schedule; reschedule on: app foreground, settings change, significant location change, daily BG task. iOS 64-pending-limit budget documented in code.
- Texts from notification template packs (admin-editable).

## Widgets v1
Next Prayer (small), Prayer Timeline (medium), Hijri Date (small). Data: app-group `ConfigSnapshot` + precomputed `PrayerDay` timeline; zero network in widget processes; timeline entries pre-generated for 48h.

## Events (analytics + gamification vocabulary)
`prayer_screen_viewed`, `qibla_used`, `prayer_settings_changed {field}`, `prayer_notification_opened {prayer}`. (No prayer-logging events in M1 — pending Q5 decision.)

## Tests
- Golden corpus (shared 140-entry fixture) green on both platforms — CI-gated.
- DST-transition day: notification schedule has no duplicate/missing adhan.
- Timezone change (travel) → timeline recompute; countdown correctness across midnight and around Isha→Fajr boundary.
- Settings overrides alter output deterministically (snapshot tests per method/madhab).
- Widget timeline: entries monotonic, ≤ platform budget, correct after location change.
