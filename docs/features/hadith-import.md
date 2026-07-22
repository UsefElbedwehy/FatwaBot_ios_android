# Hadith import

How the hadith corpus gets into FatwaBot. Like the [azkar/dua import](content-import.md),
it is **offline, reviewable, and idempotent** — text is imported once into our own
database and bundled/synced to the apps; there is no runtime dependency on any
third-party hadith API. Authenticity is the product, so every text carries its
provenance and passes through the [review model](content-verification.md).

Related: [hadith-collections.md](hadith-collections.md) (the feature),
[content-pipeline.md](content-pipeline.md) (bundle-then-sync delivery).

## Source & licensing

Arabic matn comes from [`fawazahmed0/hadith-api`](https://github.com/fawazahmed0/hadith-api)
(the `ara-<book>` editions). We import **the Arabic matn and gradings only**: the
classical matn is public domain, whereas the aggregator's English translations
have uncertain licensing — so `translation` stays `null` until a properly
licensed, reviewed English pass. Provenance is recorded per row in
`source_dataset` (e.g. `fawazahmed0 hadith-api (ara-bukhari) — Arabic matn`).

## Collections shipped

Eight collections, imported published as a **trusted import** (approved,
`reviewed_by = 'auto:trusted-import'`) pending a scholarly diacritics/grading
proofread — they surface in `content.needs_review`.

| Collection | slug | ~entries | Delivery |
| --- | --- | --- | --- |
| Nawawi's Forty | `nawawi40` | 42 | **Bundled offline** |
| Forty Hadith Qudsi | `qudsi40` | 40 | **Bundled offline** |
| Sahih al-Bukhari | `bukhari` | 7,554 | Sync-only |
| Sahih Muslim | `muslim` | 7,360 | Sync-only |
| Sunan Abu Dawud | `abudawud` | 5,272 | Sync-only |
| Jami' at-Tirmidhi | `tirmidhi` | 3,889 | Sync-only |
| Sunan an-Nasa'i | `nasai` | 5,672 | Sync-only |
| Sunan Ibn Majah | `ibnmajah` | 4,336 | Sync-only |

**Bundled vs. sync-only.** The delivery layer is per-collection-per-locale JSON
(see content-pipeline.md). The two compact classics are small (~50 KB/locale) and
ship in the app bundle for full offline use. The six large books are multiple MB
each — too large to bundle — so they are **catalogued** in the offline
`hadith-collections` index (with counts) but their detail is fetched on demand via
sync the first time a user opens them. All eight are always available server-side.

## Numbering

The DB key is `(app_id, collection_id, number)` with `number int`. The source
uses fractional `hadithnumber`s (e.g. `402.2`) for secondary narrations whose
integer part collides with the primary. We key on the **integer canonical number**
(what scholars cite) and skip the fractional variants and empty-matn entries — the
primary narration under each number is always retained. The importer logs how many
were skipped per collection; nothing is dropped silently.

## Pipeline

`scripts/hadith_import.ts` is the library (pure, tested transforms):
- `fromFawazEdition(slug, names, arabicEdition, englishEdition?, opts)` — maps a
  fawaz edition onto a `HadithDataset` (integer-keyed, matn-only unless an English
  edition is passed).
- `buildSql(dataset, opts)` — idempotent upsert on `(app_id, collection_id,
  number)`. `published: true` stamps `review_status = 'approved'` +
  `reviewed_by = 'auto:trusted-import'` so it satisfies the 0014 constraint
  (`not published or review_status = 'approved'`); the default stays unpublished +
  pending.
- `toBundledJson(dataset, locale)` / `collectionsIndex(datasets, locale)` — emit
  the apps' offline JSON (deterministic ids so ar/en stay aligned).

`scripts/build_hadith.ts` is the driver over all eight collections. From a
directory of `ara-<book>.json` editions:

```bash
# 1. fetch the Arabic editions (once)
for ed in ara-nawawi ara-qudsi ara-bukhari ara-muslim ara-abudawud \
          ara-tirmidhi ara-nasai ara-ibnmajah; do
  curl -s "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/$ed.json" \
    -o editions/$ed.json
done

# 2. generate per-collection SQL + the bundled offline JSON
deno run -A scripts/build_hadith.ts \
  --editions-dir editions \
  --sql-dir out/sql \
  --bundled-dir out/bundled
```

The per-collection SQL is baked into migrations `0015_seed_hadith_classics.sql`
(nawawi40 + qudsi40) and `0016`–`0021` (the six major books); the bundled JSON is
copied into the three resource trees (`content/seed/`, iOS `ContentKit/Resources/`,
android `core/content/.../resources/content/`). Apply with `supabase db push`.

## Re-running

Re-importing is safe: `buildSql` upserts on the natural key and carries
`source_dataset` through `on conflict do update`, but **leaves the review columns
untouched** — a previously approved (or human-reviewed) hadith stays as-is. See
content-verification.md for the reviewer workflow over `content.needs_review`.
