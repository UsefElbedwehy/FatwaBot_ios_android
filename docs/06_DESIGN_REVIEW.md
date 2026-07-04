# Concept Design Review — `App Demo design/`

> Status: Planning phase, second pass (2026-07-04). The 22 screenshots show a working web prototype (Arabic, RTL, maroon-on-cream). Treated per the foundation as concept demonstrations of product intent — mined for vision, challenged screen by screen, not reproduced.

## 1. What the demo establishes (adopted)

| Signal | Adoption |
|---|---|
| **Brand identity exists**: "FATWA BOT" wordmark, mihrab/minaret arch logo, deep maroon (~#7A2A2A) on warm cream, ornamental divider motifs | Adopt as the brand baseline; refine into full token system (dark mode, accessibility contrast) — replaces the night-teal/gold placeholder in the design direction. The mihrab arch becomes the **branded streak icon** (demo already uses it — validates ADR-0007's no-fire-emoji direction) |
| **أثرك module** (tabs: لوحتي / أوراد / الأربعون / إعدادات) — personal *awrad* (wird) routines: custom recurring worship goals (name, type e.g. صلاة على النبي, daily target, unit, frequency), a daily board with completion button, streak counter, and stats (total azkar, completed days, **Qur'an pages**, salawat count) | **New module adopted: Awrad (الأوراد)** — a personal worship-routine builder feeding the streak/gamification engine. Not in the first planning pass; added to roadmap M2–M3. Qur'an-pages stat implies a lightweight "Qur'an reading wird" goal type (manual logging — not a mushaf reader) |
| **الأربعون hadith collections** — Nawawi's 40, بلوغ المرام, الإيمانية, القدسية; hadith cards with number badge, grading (متفق عليه), and a "الفائدة" benefit note; prev/next reading flow | **New module adopted: Hadith Collections (learning)** — admin-managed collections with per-hadith benefit notes; progress tracking; candidate hadith-of-the-day reminder (demo has a 12-hourly hadith notification toggle). Distinct from the AI hadith-extraction KB |
| **Periodic dhikr reminders** — master toggle, interval (hourly…), active window (8am–10pm), per-type toggles (تسبيح, تهليل, استغفار, صلاة على النبي, short azkar), hadith-reminder | Folds into the backend-driven notification catalog; validates the catalog design and adds the "recurring randomized content reminder" template type |
| **Leaderboard**: محلي/عالمي tabs, season reset date ("يتجدد التصنيف في 1 يناير 2027"), explicit opt-in join CTA, empty state with guidance | Validates ADR-0007 (opt-in) and the new requirement for **seasons**; generalized into the leaderboard-definitions engine (ADR-0012) |
| **Language ambition**: 16+ languages in the picker (Urdu, Hindi, Bengali, Nepali, Sinhala, Malay, Indonesian, Turkish, Somali, French, Swahili, Filipino, Hausa…) | Confirms multi-locale content schema from day one and backend-driven supported-languages list (ADR-0014). Launch scope still needs a decision (OPEN_QUESTIONS Q7) |
| Tasbeeh: preset dhikr chips, big tap target, total + target (33), reset | Adopted; refine (haptics, sets, custom dhikr, history) |
| Prayer times list with Hijri+Gregorian header; Qibla compass with logo needle | Adopted; both rebuilt on the on-device engine (ADR-0003) |

## 2. What the demo gets wrong (challenged & redesigned)

1. **Home is an AI landing page.** Logo hero + three AI cards + search field — while every daily-value feature (prayer, azkar, tasbeeh, streak) hides behind a grid icon labeled المزايا. For a companion app this inverts the usage frequency: users need prayer times five times a day and a fatwa occasionally. **Redesign:** Home = daily companion (next-prayer hero, today's worship loop, streak, then the Ask section with the three AI intents preserved as chips). The three-card AI concept survives as the Ask section's intent selector.
2. **Navigation buries the product.** Bottom bar is [grid | home | ⋯-menu] — the grid page is a junk-drawer of 8+ features with no hierarchy, and settings/language/contact hide behind "⋯". **Redesign:** 4 tabs (Home / Worship / Journey / Settings) per the design direction; no junk-drawer, no hidden settings.
3. **Prayer times require a button press** ("تحديد موقعي وعرض الأوقات" empty state) and a manual "تحديث" refresh button. Times must simply *be there* — computed on device, refreshed automatically (ADR-0003). Location asked contextually once.
4. **In-app admin panel behind a secret code** (لوحة التحكم — رمز سري on the المزايا grid). Security-wise and review-wise unacceptable in production. **Replaced** by the separate Admin Dashboard (ADR-0009). No admin surface ships in the mobile binaries.
5. **Streak day counted by "أتممت وردي اليوم" self-declaration button.** Keep the completion moment (it's a good ritual) but credit comes from the activity-event pipeline (ADR-0007) — the button completes *actual tracked items*, not a bare claim.
6. **No empty/loading/error language.** Empty states are bare grey text; no offline states; no skeletons. The design-direction standards (§5) apply to every screen.
7. **Leaderboard "محلي" tab means "this device"** (local-only data) in the demo. In production this slot becomes **country** (and city, once defined) scopes from the real leaderboard engine.
8. **Accessibility gaps**: low-contrast rose-on-cream chips, small tap targets in the tab strip, no dark mode anywhere in the demo. All addressed by token-level contrast rules and dark theme from M0.
9. **Wird form UX**: modal form with dropdowns for type/unit/frequency. Redesign as guided creation (pick from admin-curated wird templates first, custom as escape hatch) — templates are backend content, so new wird types arrive without app updates.

## 3. Design-language verdict

Keep: warm cream surfaces, maroon primary, arch motif, ornamental dividers (used sparingly), Arabic-first typography.
Fix: introduce a true type scale (the demo has ~2 sizes), an 8-level neutral ramp for hierarchy (demo relies on maroon-or-grey), consistent radius/elevation tokens, dark theme (pre-Fajr "true black" variant), WCAG AA contrast on all text chips, RTL-mirrored iconography.

The redesigned Home in [05_DESIGN_DIRECTION.md §4](05_DESIGN_DIRECTION.md) stands, now expressed in the demo's brand language, with one adjustment: **Today's actions row includes the user's awrad board** (the أثرك daily checklist collapses into Home as completable cards), and the Ask section uses the demo's three intents verbatim: ابحث عن فتوى / استخراج الأحاديث / سؤال ديني عام.
