# Design Direction & Home Screen Specification

> Status: Proposed. Updated 2026-07-04 (2nd pass): the concept demos arrived in `App Demo design/` and were reviewed screen-by-screen in [06_DESIGN_REVIEW.md](06_DESIGN_REVIEW.md). This direction now builds on the demo's actual brand (FATWA BOT wordmark, mihrab/minaret arch logo, maroon-on-cream) instead of the earlier placeholder palette, and incorporates the demo's Awrad and Hadith Collections features. Per ADR-0011, all tokens defined here are *server-overridable values* over a fixed schema.

## 1. Design Principles

1. **Sakinah (serenity) over stimulation.** A worship companion must feel calm: generous whitespace, soft depth, restrained motion. No gamified visual noise on worship surfaces.
2. **Arabic-first typography.** Arabic is the primary script, not a translation afterthought: a high-quality Arabic UI face (e.g. IBM Plex Sans Arabic / Noto Kufi class) for interface text and an Uthmanic-style face for Qur'anic/azkar text, with a Latin companion that harmonizes in weight and x-height. Full RTL as the default layout direction.
3. **Time is the product.** The user's relationship with the app is structured by the five prayers. The UI should always answer "what is now, what is next, how long" without a single tap.
4. **Zero-connectivity dignity.** Offline is not an error state. No spinners on worship features — cached/computed content renders instantly; sync happens silently.
5. **Premium = restraint + craft.** One accent palette, one radius system, one motion curve family, consistent haptics. Micro-interactions (counter taps, streak advance, prayer transition) are where the premium feel lives.

## 2. Design Tokens (v1)

- **Palette (from the demo's brand, refined):** deep maroon primary (~`#7A2A2A` family, contrast-tuned) on warm cream surfaces, with a restrained gold accent for achievement moments; an 8-step neutral ramp for real hierarchy (the demo's two-tone limitation fixed). Full light/dark themes — dark is not inverted-maroon but a warm near-black tuned for pre-Fajr use (true-black option). The **mihrab-arch motif** from the demo's logo becomes the branded streak icon (validating the no-fire-emoji rule) and the ornamental divider language, used sparingly.
- **Type scale:** display / title / body / caption with Arabic-metrics-first line heights; Dynamic Type / font-scale compliant at every size.
- **Spacing:** 4-pt base grid; card radius 16–20; consistent elevation via soft shadows/blur, not hard borders.
- **Motion:** 200–350 ms spring-based transitions; reduced-motion honored; prayer-time transitions animate the sky-gradient of the hero (dawn/noon/dusk/night) — subtle, not literal.

## 3. Information Architecture

Bottom navigation, 4 tabs (both platforms):

1. **الرئيسية (Home)** — the daily companion surface (spec below).
2. **العبادة (Worship)** — Azkar, Dua, Tasbeeh, Qibla, **Awrad (my routines)**, and **Hadith Collections** as a curated tools surface with recents — replaces the demo's undifferentiated المزايا grid.
3. **المسيرة (Journey)** — streaks, challenges, achievements, leaderboard (opt-in surfaces).
4. **الإعدادات (Settings)** — prayer configuration, notifications catalog, account, appearance.

AI features live on Home (per the foundation) and open as focused full-screen experiences. Search History is reachable from the AI surface and Settings.

## 4. Home Screen — Redesign Specification

**Stakeholder-clarified identity (2026-07-04): the product has two identities and Home must carry both** — AI-powered Islamic Assistant *and* Daily Islamic Companion. The three AI services (ابحث عن فتوى / استخراج الأحاديث / سؤال ديني عام) are first-class and must not hide behind navigation; the companion surfaces (prayer, progress, content) make the screen daily-valuable. The section order below is the *default server layout* (ADR-0011) — every section's order, visibility, and props are backend-composed from the native catalog.

Default layout, top to bottom:

1. **Ambient header** — Hijri + Gregorian date, location name, subtle sky-gradient tied to the current prayer period. Greeting varies by time (صباح الخير / مساء الخير), served from string packs.
2. **Next-prayer hero card** — prayer name (Arabic calligraphic treatment), live countdown, adhan time, thin five-prayer timeline strip showing progress through the day. Tap → full Prayer screen. This card's data is also the widget's data — one shared render model.
3. **AI section — "اسأل" (Ask)** — the assistant identity, above the fold. One clean entry field (the demo's "ما حكم...؟" placeholder retained) plus the three first-class intents as tappable cards: ابحث عن فتوى / استخراج الأحاديث / سؤال ديني عام, with the demo's trust line ("البحث عن الإجابة على ضوء منهج أهل السنة والجماعة") as footnote. One tap = focused Ask experience with streamed, cited answers. **Recent searches** appear as a compact row beneath once history exists. Pre-AI-launch (M1–M4) the section renders in "coming soon" state or is hidden by server layout — the slot and design are final now.
4. **Today's progress + actions** — the day's worship loop as completable cards with an inline progress summary: Morning/Evening Azkar, the user's awrad (أثرك daily board collapsed into Home), Daily Challenge, Tasbeeh quick-start. Completion feeds streaks via activity events; the demo's "أتممت وردي اليوم" moment kept as a micro-interaction over tracked items, not self-declaration.
5. **Streak summary strip** — compact branded overall-streak indicator (mihrab-arch motif + count) linking to Journey. Never a leaderboard rank on Home — private by default.
6. **Daily content** — Daily Hadith and Daily Dua cards (admin-scheduled from CMS content; share + save actions; deep-link into Hadith Collections / Dua library).
7. **Featured content / announcement slot** — admin-composed CMS cards (Ramadan campaign, new challenge, featured collection).
8. **Quick actions & widget shortcuts** — compact grid: Qibla, Tasbeeh, Azkar, Search History, plus an "add widget" education card (deep-links to the OS widget gallery flow where the platform allows).

Section types 1–8 form the native **section catalog v1** (ADR-0011); the server composes order/visibility/props per platform, locale, and season.

States: first-launch (pre-permission: city picker fallback, notification priming happens contextually, not as a wall), offline (identical, minus announcement slot), pre-Fajr dark ambiance, Ramadan variant (suhoor/iftar countdown replaces/joins hero — flagged, admin-schedulable).

## 5. Screen-level Standards (apply to every feature)

- Every list has designed **empty, loading (skeleton, not spinner), error, and offline** states.
- Every destructive action confirms; every long operation is cancellable.
- Haptics: light tick per tasbeeh count, success pattern on set completion, gentle notification on streak advance.
- Accessibility: 44-pt touch targets, VoiceOver/TalkBack labels including Arabic pronunciation-correct strings, WCAG AA contrast in both themes, reduced-motion variants for all custom animation.
- RTL correctness verified by snapshot tests in both languages.
- **Tablet/iPad & large screens:** adaptive layouts from M0 — Home sections reflow to a two-column grid, Worship becomes sidebar + detail (NavigationSplitView / list-detail pane), reading experiences (azkar, hadith) get comfortable measure (~65ch) instead of stretched full-width; no letterboxed phone UI.
- **Onboarding:** value-first (show today's prayer times for an assumed/asked city before any permission), contextual permission priming (location when opening prayer/qibla, notifications after first completed action), content slides served from string packs (ADR-0011) so onboarding is admin-editable.

## 6. Deliverables During Implementation

- Design-system components built in M0 with snapshot tests (see roadmap).
- Per-feature spec in `docs/features/` includes its screen states before implementation.
- Interactive HTML mockups of key screens (Home first) can be produced for stakeholder review before M1 UI work begins — on request, or as the first artifact of M1.
