# FatwaBot — Feature Source Map

Where each feature's data/logic actually comes from. Three categories: **Our backend** (Supabase-backed API, not yet deployed — blocked on Q8 credentials), **3rd-party / device APIs**, **On-device only** (no network at all).

## 1. Our backend (`/v1/*`, `/admin/v1/*`)

Currently non-functional in the shipped build — `AppEnvironment.apiBaseURL` is a placeholder because no Supabase project has been deployed yet (Q8). Code is complete and tested; it just has nothing to talk to.

| Feature | Endpoint(s) |
|---|---|
| Anonymous auth / device identity | `/v1/auth/anonymous`, `/v1/auth/refresh`, `/v1/me` |
| Account linking (Apple/Google) | `/v1/auth/apple`, `/v1/auth/google`, `/v1/auth/link` |
| App config, theme colors, feature flags, Home layout | `/v1/config/*` |
| Azkar, Dua, Tasbeeh presets, Awrad templates, Hadith Collections content | `/v1/content/*` |
| Streaks, missions, badges | `/v1/gamification/profile`, activity-event ingest |
| Leaderboards | `/v1/leaderboard/*` |
| Search history | `/v1/search-history/*` |
| Push notification campaigns, prefs, catalog | `/v1/notifications/*` (dispatch itself needs Firebase — also Q8) |
| Admin dashboard (content CMS, user management, all of the above) | `/admin/v1/*` |

## 2. 3rd-party / device APIs

| Feature | Source |
|---|---|
| Device GPS location | iOS CoreLocation / Android FusedLocation — on-device, no 3rd-party network call |
| Compass heading (Qibla) | iOS CoreLocation heading / Android magnetometer sensor |
| Local notifications (adhan, azkar reminders) | iOS `UNUserNotificationCenter` / Android `AlarmManager` — scheduled on-device, not push |
| Push notifications (future) | Firebase Cloud Messaging — not wired yet (Q8) |
| Crash reporting / analytics (future) | Firebase Crashlytics/Analytics — not wired yet (Q8) |
| Lock Screen countdown (iOS only) | Apple ActivityKit — local-only, no push |

## 3. On-device only, zero network

| Feature | How |
|---|---|
| Prayer time calculation | Computed on-device from lat/long + calculation method (astronomical formulas, `adhan` library), not fetched from any server |
| Hijri date | Computed on-device |
| Qibla direction | Computed on-device from great-circle bearing to Makkah |
| Onboarding flow | Local screens only, no backend calls |
| Home/Lock Screen widgets | Read a pre-computed local snapshot file written by the app; zero network in the widget process itself |

## Bottom line

Everything a user can *feel* today — prayer times, Qibla, adhan reminders, azkar/dua/tasbeeh/awrad/hadith content, onboarding — works fully offline, on-device. Everything that needs **our backend** (accounts, streaks/leaderboards, search history sync, admin-managed content updates, push notifications) is built and tested but inert until a Supabase project + Firebase project are provisioned (Q8).
