# Feature Spec: Azkar (M2)

> Reading/counting experience over `azkar_categories`/`azkar_items` (content-pipeline.md). Single-source spec for both platforms.

## Domain model
- `AzkarCategory` — id, name, sortOrder.
- `AzkarItem` — id, categoryId, arabicText, transliteration, translation, virtueNote (فائدة, optional), source, repeatCount, sortOrder.
- `AzkarSessionState` — categoryId, currentItemIndex, currentItemCount (progress toward that item's repeatCount), completedItemIds, startedAt.
- `AzkarCompletionRecord` — categoryId, completedAt (local history; feeds M3 streak events later — this milestone just records locally).

## Use cases
`ListCategories` · `GetCategoryItems(categoryId)` · `StartSession(categoryId)` · `TickCurrentItem` (increments count; auto-advances to next item at repeatCount, haptic on both tick and item-complete) · `CompleteSession` (records completion, resets state) · `ResumeSession` (session state persists across app restarts within the same day).

## Screens & states
1. **Azkar home** — grid/list of categories (morning ☀️-style icon, evening, after-prayer, sleep, travel, general) with today's completion badge (✓ if completed today).
2. **Session screen** — current item's Arabic text (large, Uthmanic-style rendering per design direction), transliteration + translation (togglable), virtue note in a highlighted card, repeat counter (large tap target, count/target), progress bar across the category's items. Completion screen: a calm confirmation, not a celebratory burst — "الأذكار" is worship, not a game (per ADR-0007 tone guidance).
3. **Empty/loading/offline** — standard states per design direction; azkar render from bundled seed even fully offline on first launch.

## Notifications (extends ADR-0013 catalog)
- Morning azkar reminder (time-window default, e.g. after Fajr), evening azkar reminder (after Asr) — both local-computed, catalog-driven toggle + time override, per docs/features/prayer.md's notification infrastructure.
- Periodic dhikr reminder (from the concept-demo review): interval + active-window, random azkar snippet — reuses the same local scheduling infra as prayer notifications.

## Events
`azkar_category_opened {category}`, `azkar_item_completed {category, item_id}`, `azkar_session_completed {category, duration_s}` (this event name is reserved for the M3 streak engine's activity-event vocabulary).

## Tests
- Repeat-count auto-advance at exactly N reaches the next item, not N+1.
- Resume mid-session after app restart same day restores exact position.
- Session completion is idempotent (double-completing doesn't double-record).
- RTL layout + Dynamic Type/font-scale snapshot for the session screen.
