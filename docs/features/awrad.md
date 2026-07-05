# Feature Spec: Awrad — Personal Wird Routines (M2)

> From the concept-demo review (docs/06_DESIGN_REVIEW.md, أثرك module). Fully local in M2 — user-created routines with local daily tracking; `wird_templates` (content-pipeline.md) supplies the guided-creation starting points. Server sync of wird instances is a natural M3+ extension once accounts exist (ADR-0004), not required now since anonymous users already get local persistence.

## Domain model
- `WirdTemplate` (from backend, read-only) — name, description, type (e.g. صلاة_على_النبي, تلاوة, ذكر_عام, custom), defaultTarget, defaultUnit (مرة/صفحة/دقيقة), defaultFrequency (daily/weekly).
- `Wird` (user's instance, local) — id, name, type, target, unit, frequency, createdAt, archivedAt?.
- `WirdDailyProgress` — wirdId, date, count, completedAt?.
- `WirdStats` — derived: total azkar count, completed-days count, Qur'an pages (if any wird has unit=page), salawat count (if any wird has type=صلاة_على_النبي) — mirrors the concept demo's stats row.

## Use cases
`ListTemplates` · `CreateWird(fromTemplate | custom)` · `ListActiveWirds` · `TickWird(wirdId, amount: Int)` · `MarkDayComplete` (the demo's "أتممت وردي اليوم" moment — completes all of today's wirds meeting target, kept as a micro-interaction; per the pass-2 design direction, credit still derives from tracked per-wird ticks, not the button alone) · `ArchiveWird` · `GetStats(range)`.

## Screens & states
1. **Awrad board** (Home "today's actions" section per design direction, and its own full screen from Worship tab) — daily checklist: each wird as a row with progress (count/target), tap to increment quickly or open detail for larger increments; overall day-completion state.
2. **Create wird** — template picker (grouped by type) shown first; "إنشاء ورد مخصص" (custom) as an explicit secondary path at the bottom — never the default, to steer users toward maintained content per the design review's guidance.
3. **Stats screen** — the four-stat grid from the concept demo (total azkar, completed days, Qur'an pages, salawat), refined with real hierarchy (design review §3) instead of four identical cards.
4. **Empty state** — no wirds yet: prompts "add your first wird" pointing at templates, not a bare "no data" message.

## Notifications
Daily wird reminder (catalog entry, user-configurable time) — "لم تكمل وردك اليوم" style nudge, only fires if today's wirds are incomplete by the configured time.

## Events
`wird_created {template_id | "custom"}`, `wird_ticked {wird_id, amount}`, `wird_day_completed` (reserved for M3 streak vocabulary).

## Tests
- Ticking past target doesn't error; day-completion requires all *active* (non-archived) wirds to reach target.
- Archiving a wird removes it from the board without deleting its historical progress (stats remain accurate).
- Stats aggregation is correct across wird type/unit combinations (page-unit wirds sum into Qur'an-pages stat; other units don't).
- Template list renders even fully offline (bundled seed).
