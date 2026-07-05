# Feature Spec: Dua Library (M2)

> Reference library over `duas`/`dua_categories` (content-pipeline.md). Simpler than Azkar — no session/counter, this is a browse-and-read library.

## Domain model
- `DuaCategory` — id, name, sortOrder (e.g. quran-duas, prophetic-duas, daily-occasions, distress, travel).
- `Dua` — id, categoryId, title, arabicText, transliteration, translation, source (Qur'an ayah ref or hadith citation).
- `FavoriteDua` — local-only, duaId + addedAt (no backend sync in M2; a device-local list).

## Use cases
`ListCategories` · `GetCategoryDuas(categoryId)` · `SearchDuas(query)` (matches title/translation, local full-text over the cached content — no network round-trip) · `ToggleFavorite(duaId)` · `ListFavorites`.

## Screens & states
1. **Dua library home** — categories grid, a "المفضلة" (Favorites) entry pinned first if non-empty, search field.
2. **Category list** — dua titles with source snippet; tap → reading view.
3. **Reading view** — Arabic text (large), transliteration/translation toggle, source attribution, favorite toggle, share action (native share sheet — text only, no image generation in M2).
4. **Search results** — empty state distinguishes "no matches" from "type to search".

## Events
`dua_category_opened {category}`, `dua_viewed {dua_id}`, `dua_favorited {dua_id}`, `dua_search {query_length}` (never log the raw query — privacy).

## Tests
- Search matches Arabic and translation text, is diacritic-insensitive for Arabic (basic normalization — strip tashkeel before matching).
- Favorites persist across restarts, survive content resync (keyed by stable `duaId`, not array index).
- Empty favorites shows the empty state, not an empty section header.
