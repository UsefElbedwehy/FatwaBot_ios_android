# Feature Spec: Content Pipeline (M2)

> Shared infrastructure underlying Azkar, Dua, Hadith Collections, and Wird Templates. Mirrors `docs/features/config-sync.md`'s offline-first pattern but for bulk reference content rather than small config blobs.

## Principles
- **Arabic canonical, multi-locale by schema** (ADR-0014): every content row stores `{field}_translations: {locale: value}`, published per-locale independently.
- **Bundled seed, then sync**: apps ship a seed bundle (`content/seed/*.json`, same files the backend seeds from) so first launch is fully offline. Sync fetches only what changed since the bundled/cached version (per-collection version numbers, not per-row).
- **Read-only client**: content is admin-authored (dashboard CMS, task 27); apps never write content, only local user state (favorites, wird instances, progress) layered on top.

## Domain model (backend `content` schema)
- `azkar_categories` (id, slug, sort_order, translations{name}) — morning, evening, after_prayer, sleep, travel, general.
- `azkar_items` (id, category_id, sort_order, translations{arabic_text, transliteration, translation, virtue_note}, source, repeat_count, version, published)
- `duas` (id, category_id, translations{title, arabic_text, transliteration, translation, source}, version, published) + `dua_categories` (mirrors azkar_categories shape)
- `hadith_collections` (id, slug, translations{name, description}, sort_order, version, published)
- `hadith_entries` (id, collection_id, number, translations{arabic_text, translation, grading, benefit_note}, source, version, published)
- `wird_templates` (id, translations{name, description}, type, default_target, default_unit, default_frequency, version, published)

Every table's `version` is a monotonically increasing integer bumped on any published change to that row; the **collection-level** sync endpoint returns a `collection_version` (max row version) so clients can skip a fetch entirely when nothing changed.

## Backend API (task 19)
`GET /v1/content/{collection}?locale=ar&since_version=N` → `{ collection_version, items: [...] }` or `{ up_to_date: true }`. Collections: `azkar`, `duas`, `hadith-collections/{slug}`, `wird-templates`. Unauthenticated (content is public read).

## Client sync service (task 21, mirrors ConfigService)
- `ContentService.load(collection)` — synchronous read of cache, falling back to the bundled seed JSON embedded in the app.
- `ContentService.refresh(collection, locale)` — fetch delta, validate, persist; per-collection failure is silent and independent (same policy as config layers).
- Cache storage: one JSON file per collection per locale (not a single blob) so a large hadith collection doesn't invalidate azkar on refresh.

## Analytics events
`content_sync_succeeded {collection, version}`, `content_sync_failed {collection, reason}`.

## Tests (both platforms, mirroring config-sync spec)
1. First launch, no network → bundled seed renders.
2. Refresh with new version → applied, persisted, `up_to_date` short-circuits when nothing changed.
3. Malformed response → cache untouched.
4. Locale switch → separate cache entry, no cross-contamination.
