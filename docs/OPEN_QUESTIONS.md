# Open Questions — Stakeholder Input Needed

Decisions I should not make unilaterally. None block approval of the overall plan; questions note when they must be answered.

## ~~Q1 — Missing design assets~~ ✅ Resolved 2026-07-04
Designs arrived in `App Demo design/` and are reviewed in [06_DESIGN_REVIEW.md](06_DESIGN_REVIEW.md).

## Q2 — Product name (before store setup; brand otherwise resolved)
The demo confirms the visual brand (FATWA BOT wordmark, mihrab-arch logo, maroon/cream) — adopted as the design baseline. Remaining question: is **"Fatwa Bot" the final public name**? It undersells the companion platform (prayer, azkar, awrad, streaks) and centers the least-shipped feature; a broader name with "Fatwa" as the AI feature name is worth considering. Per ADR-0011 the in-app display name is server-configurable, but the store name and the name under the icon are not.

## Q2b — Points/formula editing power (before M3 dashboard work)
ADR-0012 proposes constrained declarative formulas (weighted counters, caps, decay) rather than free-form scripting for ranking/point rules. If you expect admins to need genuinely novel scoring logic per season, say so now — that changes the engine design (sandboxed evaluator, much more testing surface). Recommendation: constrained form.

## ~~Q2c — City leaderboards & location privacy~~ ✅ Resolved 2026-07-06
Opt-in city sharing only: city is never collected by default; a user must explicitly opt in and confirm their city specifically to join a city-scope leaderboard.

## ~~Q2d — Notification frequency cap~~ ✅ Resolved 2026-07-06
Default cap of 2 campaign (non-worship) notifications per user per day, admin-configurable per campaign type. Locally-computed worship reminders (adhan/azkar) are unaffected.

## Q3 — Anonymous-first onboarding (ADR-0004, before M1)
Confirm: app fully usable with no sign-up; accounts only for leaderboards/display-name/sync. Alternative (sign-up wall) simplifies backend identity slightly but will hurt retention.

## ~~Q4 — Streak day-boundary & grace rules~~ ✅ Resolved 2026-07-06
Fajr-to-Fajr window presented simply as "today", with a limited grace/mercy allowance for missed days. **Additionally:** the day-boundary policy, grace count, and recovery window must be fully admin-editable data (`gamification.streak_defs`), not hardcoded defaults with override — the admin can change the rules at any time without an app release, consistent with ADR-0015's configurable-by-default principle.

## ~~Q5 — Prayer-log semantics~~ ✅ Resolved 2026-07-06
Streaks/leaderboards derive only from verifiable in-app worship actions (azkar sessions, tasbeeh, wird ticks) — never self-reported prayer logging. A private prayer journal may exist for personal tracking but never feeds gamification.

## Q6 — AI scholarly oversight (before M5)
Fatwa-class AI answers carry real religious risk. Is there a scholar/domain expert who will review the source whitelist, refusal boundaries, and the evaluation set? Launching fatwa search without named scholarly oversight is not recommended.

## Q7 — Languages at launch
The demo's picker lists 16+ languages — the schema now supports all of them from day one (ADR-0014), but each locale needs human-reviewed translation of worship content. Recommendation: launch Arabic + English, prove the translation pipeline with one more locale in beta, then expand. Confirm the launch set.

## Q8 — Credentials & accounts (before M0 exit)
Needed from you when implementation starts: Supabase org/project, Firebase project, Apple Developer + App Store Connect, Google Play Console, GitHub org/repo (the folder is not yet a git repository — I'll `git init` at M0 start unless you prefer an existing remote).
