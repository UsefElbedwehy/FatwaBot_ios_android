# Feature Spec: Hadith Collections (M2)

> From the concept-demo review — الأربعون-style learning collections over `hadith_collections`/`hadith_entries` (content-pipeline.md). Distinct from the future AI hadith-extraction feature (M6): this is a curated, admin-authored reading/learning experience, not a search tool.

## Domain model
- `HadithCollection` — id, name (e.g. الأربعون النووية, بلوغ المرام, الإيمانية, القدسية), description, entryCount.
- `HadithEntry` — id, collectionId, number, arabicText, translation, grading (متفق عليه, صحيح, حسن, etc.), benefitNote (الفائدة), source.
- `HadithProgress` — local: collectionId, lastReadEntryNumber, readEntryNumbers (Set), for resume + completion badge.

## Use cases
`ListCollections` · `GetCollectionEntries(collectionId)` · `GetEntry(collectionId, number)` · `MarkRead(collectionId, number)` (auto-marks on navigating past, not requiring an explicit action) · `GetProgress(collectionId)`.

## Screens & states
1. **Collections browser** — collection cards with name, entry count, progress (e.g. "12/42 مقروء").
2. **Reading view** (per the concept demo, refined): hadith number badge, Arabic text, grading chip, benefit-note card visually distinct from the hadith text itself, prev/next navigation (swipe + buttons), jump-to-entry picker for long collections.
3. **Completion state**: collection card shows a completed badge once all entries are read; no gamification burst (ADR-0007 tone) — a quiet checkmark.

## Notifications
Optional "hadith of the day" reminder (catalog entry, default off) — surfaces one unread entry from the user's in-progress collection, or a random entry from a completed one.

## Events
`hadith_collection_opened {collection}`, `hadith_entry_read {collection, number}`.

## Tests
- Progress persists across restarts; `readEntryNumbers` is a set (re-reading doesn't double count).
- Prev/next navigation clamps at collection boundaries (no wraparound, no crash at entry 1 or the last entry).
- Collections render from bundled seed offline on first launch.
- RTL numeral display respects the locale's digit preference (config.locales.digits per ADR-0011/0014).
