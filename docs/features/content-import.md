# Content import pipeline (hadith · azkar · dua)

Three importers share `scripts/import_common.ts` and the same philosophy — **offline,
reviewable, idempotent**: import a vetted dataset once into your own DB (+ regenerate
the apps' bundled offline JSON), never call a third-party content API at runtime.

| Type | Script | Test |
|---|---|---|
| Hadith | `scripts/hadith_import.ts` | `tests/hadith_import_test.ts` |
| Azkar  | `scripts/azkar_import.ts`  | `tests/azkar_import_test.ts` |
| Dua    | `scripts/dua_import.ts`    | `tests/dua_import_test.ts` |

## Datasets imported so far (2026-07)
- **Azkar** — [Seen-Arabic/Morning-And-Evening-Adhkar-DB](https://github.com/Seen-Arabic/Morning-And-Evening-Adhkar-DB)
  (MIT): 26 morning + 24 evening, with Albānī gradings, English translation + transliteration.
  Adapter: `fromSeenArabic`.
- **Dua** — [rn0x/Adhkar-json](https://github.com/rn0x/Adhkar-json), the Arabic-native
  full Hisn al-Muslim: 132 categories / 267 duas. **Arabic matn + Arabic titles only**
  (public domain), attributed `حصن المسلم`; translations/transliterations deliberately
  omitted (those editions are typically copyrighted). Adapter: `fromHisnAlMuslimAr`.
- **Hadith** — not yet imported; adapter ready for the fawazahmed0 editions.

> ⚠️ Imported **verbatim** from the sources above. The Arabic matn is public domain,
> but a **scholarly diacritics proofread is recommended before public launch**, and
> only **rights-cleared** translations should be added. `published` defaults to false
> for exactly this reason — the two datasets above were published because they carry
> real references, but you can unpublish/regenerate anytime.

---

## Hadith importer

Imports hadith collections into `content.hadith_collections` + `content.hadith_entries`
so they're served by the existing content API (`/v1/content/hadith-collections`)
and synced to both apps. **Offline + reviewable by design** — we never call a
third-party hadith API at runtime (that would break offline-first and hand text
vetting to someone else; authenticity is the product). Instead you import a
dataset **once**, review it, and publish it from your own database.

Script: `backend/scripts/hadith_import.ts`. Pure transforms are unit-tested
(`backend/tests/hadith_import_test.ts`).

## Content tiers (where hadith fits)
1. **Bundled** — core Azkar/Duas ship in the app, work offline on first launch.
2. **Seeded + delta-synced** — full hadith collections (this pipeline) → your DB → content API.
3. **Admin-managed** — edited over time via the dashboard CRUD (`hadith-collections` / `hadith-entries`).

## Input format (`HadithDataset`)
```json
{
  "collection": {
    "slug": "nawawi40",                       // ^[a-z0-9_-]{1,40}$, unique per app
    "name":        { "ar": "…", "en": "…" },  // ar required (Arabic-first)
    "description": { "ar": "…", "en": "…" },  // optional
    "sortOrder": 0
  },
  "entries": [
    {
      "number": 1,                            // positive int, unique within collection
      "arabic":  "…",                         // required, non-empty
      "translation": { "en": "…" },           // optional
      "grading":  "متفق عليه",                 // optional (e.g. صحيح / حسن / ضعيف)
      "benefit":  { "ar": "…", "en": "…" },    // optional فائدة note
      "source":   "رواه البخاري ومسلم"          // optional
    }
  ]
}
```
See `backend/scripts/samples/nawawi40.sample.json` for a working example.

## Run it
```bash
cd backend
# review pass — writes UNPUBLISHED rows (invisible to the app until you publish)
deno run --allow-read --allow-write scripts/hadith_import.ts \
  --in scripts/samples/nawawi40.sample.json \
  --out supabase/imports/hadith_nawawi40.sql

# when you're happy with the texts, publish:
deno run --allow-read --allow-write scripts/hadith_import.ts \
  --in scripts/samples/nawawi40.sample.json --publish \
  --out supabase/imports/hadith_nawawi40.sql
```
The generated SQL is **idempotent** — re-running upserts (never duplicates), so
you can re-import after fixing a text. `published` defaults to `false` so nothing
goes live unreviewed; `--publish` (or flipping the flag in the dashboard) makes
it visible.

## Apply it
Data imports are kept out of the migrations folder (migrations = schema). Apply
the generated file directly:
```bash
# Supabase Dashboard → SQL Editor → paste supabase/imports/hadith_<slug>.sql → Run
# …or, with the DB connection string:
psql "$SUPABASE_DB_URL" -f supabase/imports/hadith_<slug>.sql
```
Then confirm:
```bash
curl -s "$API/v1/content/hadith-collections" -H "authorization: Bearer $TOK" …
```

## Getting real data
The **Arabic matn of the canonical collections is public domain** (centuries old)
— safe to import. **English translations are often copyrighted** — only import
translations you have the right to use, or leave `translation` empty and add
your own. The importer includes an adapter, `fromFawazEdition(...)`, that maps
the widely-mirrored fawazahmed0 edition JSON (`ara-<coll>.json` + optional
`eng-<coll>.json`) onto `HadithDataset`, merging the English edition as the
translation and carrying gradings. Fetch those editions yourself (offline),
review the license, then feed them through.

## Safety notes
- SQL string building doubles single quotes (`sqlString`) — injection-safe for
  Arabic text full of quotes; `jsonbLiteral` emits sorted-key JSON for stable diffs.
- `validate()` rejects bad slugs, missing Arabic names, duplicate/invalid entry
  numbers, and empty Arabic before any SQL is emitted.
- Large collections (Bukhari ≈ 7000) are chunked into multiple INSERTs.
