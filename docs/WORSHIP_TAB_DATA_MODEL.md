# Worship Tab — Data Model & Sourcing Guide

Tab order in the app: **1) Home · 2) Worship · 3) Journey · 4) Settings.**
This doc covers the **Worship** tab: where every field comes from, what **you seed**
in the backend, what is **static/bundled**, what is **computed on-device**, the
**APIs** involved, plus how **notifications** and **prayer times** work today.

---

## 0. The three data sources (mental model)

Everything in the app is one of these:

| Source | Meaning | Needs backend? | Who provides it |
|---|---|---|---|
| **On-device computed** | Calculated on the phone from math + sensors | No | Nobody — it's code |
| **Bundled static seed** | Ships inside the app as JSON; the offline fallback | No | Already in the repo |
| **Backend content (you seed)** | Lives in Supabase; you edit it in the dashboard; the app syncs it | Yes (Supabase) | **You**, via the admin dashboard |
| **User-local** | Created/stored by the user on their own device | No | The user |

Key design rule (ADR-0003 / ADR-0014): the app is **offline-first**. Every content
feature ships with a **bundled seed** so it works with zero backend, then silently
**delta-syncs** newer content from the backend once Supabase is live.

---

## 1. The seven Worship features at a glance

| Feature | Data source | You seed? | API |
|---|---|---|---|
| **Prayer times** | On-device computed (from location + method) | No (only the *method* is config) | `GET /v1/config` (method only) |
| **Qibla** | On-device computed (compass + math) | No | — |
| **Tasbeeh** (counter) | On-device; presets are bundled static; counts are user-local | No | — |
| **Azkar** | Backend content + bundled fallback | **Yes** | `GET /v1/content/azkar` |
| **Dua** | Backend content + bundled fallback | **Yes** | `GET /v1/content/dua` |
| **Awrad** (wird routines) | Backend *templates* + user-created local wirds | **Yes** (templates) | `GET /v1/content/wird-templates` |
| **Hadith** | Backend content + bundled fallback | **Yes** | `GET /v1/content/hadith` |

So of the seven, **four are content you author** (Azkar, Dua, Awrad templates,
Hadith). The rest are code/sensor/user-driven and need nothing from you.

---

## 2. Prayer times — how it actually works

**It is NOT fetched from an API.** Prayer times are **computed on the device** using
the `Adhan` astronomical library (batoulapps/adhan), the same corpus-validated engine
on both platforms.

**Inputs:**
1. **Location** — GPS coordinates from the phone (CoreLocation / FusedLocation), OR a
   **manual city** the user picks (12 bundled cities) if they decline location.
2. **Calculation method** — e.g. `umm_al_qura`, `egyptian`, `muslim_world_league`.
   This is the *only* prayer input that comes from the backend: `config.prayer_defaults`
   maps a country code → method (`SA → umm_al_qura`, `EG → egyptian`, …), served via
   `GET /v1/config`. If the backend is down, a bundled default is used.
3. **High-latitude rule** — for locations ≥ 48°N, `seventh_of_the_night` is applied
   automatically (validated in the M0 golden-corpus spike).

**Outputs, all computed locally:** the 5 daily times + sunrise, the "next prayer"
countdown, the Hijri date, and a 48-hour timeline (also used by the widgets and the
Live Activity). Because it's all on-device and pre-computed a day ahead, prayer times
**work fully offline** and need no network at all.

**What you'd seed (optional):** extra rows in `config.prayer_defaults` if you want
per-country method overrides beyond the seeded SA/EG defaults. Not required to launch.

---

## 3. Qibla & Tasbeeh — zero backend

- **Qibla:** great-circle bearing to Makkah, computed on-device from the user's
  coordinates; the compass needle uses the phone's magnetometer. Nothing to seed.
- **Tasbeeh:** the dhikr **presets** (SubhanAllah/Alhamdulillah/… with target counts)
  are **bundled static** in the app. The running count, completed sets, and history are
  **user-local** (stored on the device). Nothing to seed, no API.

---

## 4. Content you seed — Azkar, Dua, Awrad templates, Hadith

These live in Supabase (schema `content`, migration `0005_content_domain.sql`), you
edit them in the **admin dashboard**, and the apps sync them via
`GET /v1/content/{collection}?since_version=N` (delta sync — the app only downloads
rows newer than what it has).

### 4.1 The multi-locale pattern (important)
Every human-readable text field is stored as a **`_translations` JSON object**, not a
plain string:

```json
"name_translations": { "ar": "أذكار الصباح", "en": "Morning Azkar" }
```

- **Arabic (`ar`) is canonical and required.** English (`en`) is optional but
  recommended (English is a launch language).
- `arabic_text` is a **plain text** column (not translated — it's the Arabic scripture
  itself).
- You can add more locales later (16-language ambition, ADR-0014) without schema changes.

### 4.2 Publishing workflow
Every row has `published` (bool) and `version` (int). In the dashboard you create a
**draft**, then **publish** it. Publishing bumps `version`, and the app's next delta
sync picks it up. Unpublished drafts are never served to the app.

### 4.3 Field reference (what you fill in per item)

**Azkar** — `azkar_categories` (groups) → `azkar_items` (the dhikr):

| Category field | Type | Notes |
|---|---|---|
| `slug` | text | stable id, e.g. `morning` |
| `name_translations` | ar/en | e.g. "أذكار الصباح" |
| `sort_order` | int | display order |

| Item field | Type | Notes |
|---|---|---|
| `arabic_text` | text | the dhikr (Arabic) — **required** |
| `transliteration_translations` | ar/en | optional |
| `translation_translations` | ar/en | meaning |
| `virtue_note_translations` | ar/en | "the reward/benefit" note |
| `source` | text | e.g. "Bukhari 6405" |
| `repeat_count` | int | how many times to say it (drives the counter) |
| `sort_order` | int | order within the category |

**Dua** — `dua_categories` → `duas`:

| Dua field | Type | Notes |
|---|---|---|
| `title_translations` | ar/en | e.g. "Dua for anxiety" |
| `arabic_text` | text | the dua — **required** |
| `transliteration_translations` | ar/en | optional |
| `translation_translations` | ar/en | meaning |
| `source` | text | reference |

**Hadith** — `hadith_collections` (e.g. Nawawi 40) → `hadith_entries`:

| Collection field | Type | Notes |
|---|---|---|
| `slug` | text | e.g. `nawawi40` |
| `name_translations` | ar/en | collection name |
| `description_translations` | ar/en | optional blurb |

| Entry field | Type | Notes |
|---|---|---|
| `number` | int | hadith # within the collection |
| `arabic_text` | text | the hadith — **required** |
| `translation_translations` | ar/en | meaning |
| `grading` | text | e.g. "Sahih" |
| `benefit_note_translations` | ar/en | the فائدة note |
| `source` | text | reference |

**Awrad** — `wird_templates` (the "choose a routine" presets; the user's *own* wird
progress is stored **locally on their device**, not in your backend):

| Template field | Type | Notes |
|---|---|---|
| `name_translations` | ar/en | e.g. "Salawat 100×" |
| `description_translations` | ar/en | optional |
| `type` | text | category, e.g. `dhikr` / `quran` / `salawat` |
| `default_target` | int | daily goal, e.g. 100 |
| `default_unit` | text | `times` / `pages` / … |
| `default_frequency` | text | `daily` |

### 4.4 What's already seeded (dummy/starter data)
Both the backend `seed.sql` **and** the bundled app JSON currently ship a **small
placeholder set** so the screens aren't empty during development:

- Azkar: **3 categories, 3 items**
- Dua: **2 categories, 1 dua**
- Hadith: **1 collection, 1 entry**
- Wird templates: **1 template**

This is **dummy/starter data — you will replace/expand it** with the real corpus. The
bundled JSON lives at `ios/.../ContentKit/Resources/*.json` and
`android/core/content/src/main/resources/content/*.json` (ar + en). The backend copy
lives in `backend/supabase/seed.sql`. For launch you'd author the real content in the
dashboard (backend); optionally we refresh the bundled JSON so first-install users see
real content before their first sync.

---

## 5. Notifications — how they work **right now**

There are **two independent systems**. Only the first is live today.

### 5.1 Prayer reminders — LIVE, fully local, no backend, no Firebase
- Computed and scheduled **on the device**: a pure `NotificationPlanner` produces a
  rolling window of adhan + pre-adhan reminders from the on-device prayer timeline.
- Delivered by the OS: **iOS `UNUserNotificationCenter`**, **Android `AlarmManager` +
  broadcast receiver**. These are **local notifications** — they fire even with no
  internet and no server.
- Texts are bundled (ar/en). A per-prayer budget cap prevents spam.
- **This already works** once the user grants notification permission in onboarding.

### 5.2 Campaign / push notifications — BUILT on the backend, NOT wired to the app yet
- The M3 backend has a full **notification campaign engine** (`notifications.templates`,
  `notifications.campaigns`, `notifications.user_prefs`, `notifications.delivery_log`,
  `config.notification_types`) — you author campaigns in the dashboard (e.g. a Hijri-date
  reminder, a "come back" nudge), with per-user prefs and a 2/day cap.
- **The actual *sending* is deliberately stubbed** because it needs **Firebase Cloud
  Messaging (FCM)**. There is **no push client in the app yet** (no FCM SDK, no device
  token registration) — confirmed: nothing wired.
- **To turn push on, we need Firebase** (see the blockers list): add the FCM SDK +
  token registration in both apps, and give the backend an FCM service account to send.
  Until then, campaign notifications can be authored but won't deliver.

**Summary:** prayer-time reminders work today with zero setup. Marketing/engagement
push needs Firebase.

---

## 6. What you need to seed vs. what's automatic

| You seed in the backend (dashboard) | Automatic — you do nothing |
|---|---|
| Real **Azkar** categories + items | Prayer times (computed on-device) |
| Real **Dua** categories + duas | Qibla direction (computed) |
| Real **Hadith** collections + entries | Tasbeeh presets (bundled) + counts (user-local) |
| Real **Awrad** wird templates | User's own wird progress (user-local) |
| (Optional) extra `config.prayer_defaults` per country | Prayer reminders (local notifications) |
| (Optional) notification **campaigns** (needs Firebase to deliver) | App theme/colors (bundled, server-overridable) |

---

## 7. The APIs involved (all under the Supabase edge-function gateway)

Base URL today is the placeholder `https://api.invalid/functions/v1/api` — we flip it to
your real Supabase URL once the project exists.

| Endpoint | Purpose | Auth |
|---|---|---|
| `GET /v1/config` | app config incl. prayer method defaults, theme, strings, Home layout | anonymous |
| `GET /v1/content/azkar?since_version=N` | Azkar delta sync | anonymous |
| `GET /v1/content/dua?since_version=N` | Dua delta sync | anonymous |
| `GET /v1/content/hadith?since_version=N` | Hadith delta sync | anonymous |
| `GET /v1/content/wird-templates?since_version=N` | Awrad templates delta sync | anonymous |
| `POST /v1/auth/anonymous` · `/v1/auth/refresh` · `/v1/me` | anonymous identity (for Journey/gamification) | — |
| `/admin/v1/content/{collection}` (CRUD) | **where you author + publish content** | admin JWT |

Content is served **read-only and anonymously** to the app; you manage it through the
authenticated `/admin/v1` surface (the dashboard).

---

## 8. TL;DR for "what do I do next"

1. **Stand up Supabase** → run the 10 migrations + seed → deploy the edge functions →
   flip the base URL. (Everything above starts flowing.)
2. **Open the dashboard** → replace the dummy Azkar/Dua/Hadith/Awrad starter rows with
   your real corpus → publish. The apps delta-sync it automatically.
3. **Prayer times & Qibla need nothing from you** — they already work on-device.
4. **Prayer reminders already work** — local notifications.
5. **For push/marketing notifications** → add Firebase (then we wire the FCM client +
   backend sender).

---

## Appendix A — Free data sources & APIs per feature (researched 2026-07)

> Bottom line: for **Azkar, Dua, and Hadith** there are **free open datasets** we can
> import into the backend seed — you do **not** have to hand-type the corpus. For
> **prayer times / Qibla / Hijri** an API exists but we don't need it (on-device is
> more accurate and offline). **Awrad templates** have no dataset — those are your
> product's own curation.

| Feature | Free API / dataset? | Recommendation |
|---|---|---|
| **Prayer times** | ✅ AlAdhan API (free, no key) | **Don't use it** — on-device is equal-or-better accuracy + offline + punctual. Use only as an optional server-side cross-check. |
| **Qibla** | ✅ AlAdhan has a qibla endpoint | Not needed — computed on-device. |
| **Hijri date** | ✅ AlAdhan calendar API | Not needed — computed on-device. |
| **Hadith** | ✅ **fawazahmed0/hadith-api** (CDN, no key, AR+EN, the 9 canonical books) + AhmedBaset/hadith-json (50,884 hadiths) | **Import to seed.** sunnah.com official API needs a key. |
| **Azkar** | ✅ Hisn al-Muslim JSON datasets (rn0x/Adhkar-json incl. audio, Seen-Arabic morning/evening) | **Import to seed.** No live "azkar API", but ready JSON. |
| **Dua** | ✅ Same Hisn al-Muslim datasets include duas | **Import to seed.** |
| **Quran** (future) | ✅ fawazahmed0/quran-api, alquran.cloud (free) | For a future Quran feature. |
| **Tasbeeh** | — | No data needed. |
| **Awrad templates** | ❌ none | **You curate** (a handful of routines — small, product-specific). |

**⚠️ You must still vet the content.** Open datasets are raw scrapes. For a religious
app, someone knowledgeable should confirm the text, the harakat (diacritics), the
grading, and the source attribution — especially for hadith. We import the dataset to
save typing; **you approve what gets published.**

### Prayer-time accuracy — the real cause (not an API problem)
The 2–3 min difference you saw vs. the "Azkar" app is a **calculation-method / tuning**
difference, **not** on-device-vs-API. Every source (on-device Adhan, AlAdhan API, the
other app) uses the **same astronomical math** and the same ~15 named methods. AlAdhan's
own docs state that even their API differs from official authorities (Dubai IACAD, etc.)
by **1–5 minutes**, because official/mosque times are **manually tuned**. So an API would
**not** fix it. The fix is to (a) match the **calculation method** of the authority you
want to track, (b) set the **Asr madhab** (Shafi vs Hanafi shifts Asr ~30–60 min), and
(c) apply small **per-prayer minute offsets** to match the local authority. Our engine
already supports all three (`PrayerSettings.method` + per-prayer `adjustments`). Tell us
the country/authority to match and it's a config change — offline, no API.

### Notifications waking a terminated app — important clarification
- **iOS:** **local** notifications already fire when the app is fully **terminated** —
  the OS holds the scheduled notification. **No push needed.** This already works today.
- **Android:** local `AlarmManager` alarms also fire when terminated, **but** aggressive
  OEM battery optimizers (Xiaomi/MIUI, Huawei, Samsung, Oppo) can kill them. This is the
  **only** place a server **FCM push backup** genuinely improves reliability.
- Caveat if we ever push prayer times from the server: FCM does **not** guarantee
  to-the-second delivery (can be delayed minutes), and the server would need each user's
  **location** (a privacy shift from today's on-device-only model) plus per-user daily
  scheduling at scale. So push is a **reliability backup for Android**, not a better
  primary for punctual prayer alerts.

**Sources:** AlAdhan API & methods (aladhan.com/prayer-times-api, /calculation-methods),
fawazahmed0/hadith-api (github.com/fawazahmed0/hadith-api), Hisn al-Muslim JSON
(github.com/rn0x/Adhkar-json, github.com/Seen-Arabic/Morning-And-Evening-Adhkar-DB).
