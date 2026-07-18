# Product Requirements — Stakeholder Brief (2026-07-12)

Captured verbatim-in-intent from the stakeholder. Nothing here is lost; each item
is tracked to a milestone below.

## Vision
- A **strong, secure, hard-to-hack database** and a **trusted reference for every question**.
- Content **restricted to specific, vetted fatwas and named scholars** (مشايخ محددة).
- Contact email: **fatwabot@gmail.com**

## Core problem to solve (the reason the app exists) — AI Fatwa Search [M5]
Two failures the stakeholder hit in other apps:
1. Search returns a fatwa attributed to a scholar and links to a source, **but the
   quoted text does not match the actual source**.
2. The text **does not match the video** it came from.
→ Requirement: **100% source-accurate** search & answers. This means ingesting sources
   and, for audio/video, producing an **accurate transcript** so the answer is exactly
   what the scholar said, with a correct citation. Search will be **AI-powered**.

### Approved source list (Part 1 — sites + YouTube for transcription)
Websites (fatwas / hadith / general questions):
- Ibn Baz — https://binbaz.org.sa/fatwas/kind/1
- Al-Durar al-Saniyyah — https://dorar.net/
- Sh. Abdurrazzaq al-Badr — https://www.al-badr.net/
- Sh. Salih Al al-Sheikh — https://saleh.af.org.sa/
- Sh. Abdulkarim al-Khudair — https://shkhudheir.com/
- Sh. Saad al-Shathri — https://audio.islamweb.net/audio/index.php?page=lecview&sid=927
- IslamWeb — https://www.islamweb.net/ar/
- Al-Maktaba al-Shamela (reference library) — https://shamela.ws/
- Sh. Ibn Uthaymeen — https://binothaimeen.net/
- Permanent Committee for Ifta (KSA) — https://www.aliftaksa.com/
- Islam Q&A — https://islamqa.info/
- Sh. Salih al-Fawzan (archive) — https://alfawzan.live/
- Sh. Uthman al-Khamees — https://othmanalkamees.net/
- Sh. Mutlaq al-Jasser — https://www.dr-mutlaq.com/

YouTube channels (for audio→text transcription):
- Uthman al-Khamees — https://youtube.com/@othmanalkamees
- Mutlaq al-Jasser — https://youtube.com/@dr-mutlaq
- Ibn Uthaymeen — https://youtube.com/@ibnothaimeentv
- Ibn Baz — https://youtube.com/@alsheikhbinbaz
- Al-Fawzan — https://youtube.com/channel/UC33zSaBeWvxCQttkkPknydA

Part 2 (books / كتب) — stakeholder still compiling; will send later.
**Q (answered):** Sources can be sent anytime and are **easy to add later** — ingestion
is incremental (add a source → re-index), no rebuild needed. See M5 plan.

## Streak / Journey requirements
1. Streaks as **per-category boxes** + **one general box for the overall total** (largely
   already built: per-activity streaks; needs an explicit "overall" streak).
2. User must be able to **add their name** to appear on the leaderboard **globally and
   locally** (already built: publish-name opt-in + city).
3. **The streak icon must be the app logo (mihrab-arch mark), NOT a fire emoji.** [design fix]
4. Admin/controller can add **challenges** to each streak box **or** to the general total
   (missions engine exists; needs per-streak + overall targeting in the dashboard).

## Notification requirements
- **Last-third-of-the-night** notification (الثلث الأخير من الليل) — computed from prayer
  times (Isha→Fajr window). [new, on-device]
- User can **toggle every notification on/off** individually. [new settings surface]
- **Iqama reminder** — a reminder at a user-defined offset after the adhan. [new]
- **Pre-adhan alert** at a user-defined time before the adhan (offset already supported;
  needs a user control).
- A **"?" info affordance per notification/feature** in Settings → an "About the app"
  help section explaining what each item does. [new help section]

## Prayer times — STATUS: fixed (2026-07-12)
Default method was MWL → caused the 2–3 min gap; changed default to **Umm al-Qura** on
both platforms, validated to ≤1 min against the AlAdhan authority. Stays on-device. If
you want to match a specific local authority beyond pure Umm al-Qura, we can add
per-prayer minute offsets (engine already supports them).

## Live Activity — BUG to fix
It must **update the single existing activity**, not start a **new** one per prayer
(it created one for Isha and another for Fajr). Fix: reuse/update the running Activity;
only start one if none exists; roll it over to the next prayer on transition. [bug fix]

## Security / other
- AI DB search must be robust and abuse-resistant.
- iOS push still needs the Apple Developer Program (APNs key); Android push works on Firebase alone.

---

## Milestone mapping
| Item | Where | Status |
|---|---|---|
| Prayer times → Umm al-Qura | done | ✅ 2026-07-12 |
| Supabase live (API) | infra | ⏳ needs `supabase db push` (your DB password) |
| Firebase push (Android) | infra | ⏳ after client SDK wiring |
| Live Activity update-not-recreate | bug | ▶️ next |
| Streak icon = logo | design | ▶️ next |
| Overall streak box + admin challenges | M3+ ext | queued |
| Notification suite (last-third, toggles, iqama, ?-help) | new | queued |
| AI fatwa search + source transcription | **M5 (core)** | design phase — the big build |
