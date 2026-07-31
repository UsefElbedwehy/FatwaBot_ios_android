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


## بلوغ المرام — the four "missing" numbers

The imported collection holds 1,564 entries spanning numbers 1–1568, so four
numbers are absent: **190, 333, 678, 1449**. All four were checked against the
source (turath.io #17757, ت. ماهر ياسين الفحل, دار القبس 1435/2014, whose
metadata declares `[ترقيم الكتاب موافق للمطبوع]`). **No hadith text is missing.**

| Number | Why it is absent |
|---|---|
| 190 | Source numbers it jointly with 189 — `١٨٩ و١٩٠ - وعن ابن عمر، وعائشة` — one hadith carrying two narrators. Stored once, as 189. |
| 678 | Same, joint with 677 — `٦٧٧ و٦٧٨ - وعن عائشة وأم سلمة`. Stored once, as 677. |
| 333 | The printed edition skips it. Source runs 332 → 334 with only footnotes between. |
| 1449 | The printed edition skips it. Source runs 1448 → 1450 with only footnotes between. |

Entries 189 and 677 were confirmed to retain **both** narrators, so the joint
numbering did not truncate either one.

These are exactly the two failure modes worth distinguishing: an editorial
numbering convention (190, 678), and the edition's own unused numbers (333,
1449). Neither is import loss, and no re-import is warranted.


## Gradings

`hadith_entries.grading` is populated two different ways, and the distinction
matters when reasoning about provenance:

| Collection | Coverage | Origin |
|---|---|---|
| بلوغ المرام | 1351 / 1564 | **Extracted** from the matn by `scripts/extract_hadith_grading.ts` (0029). Every value is a literal substring of its own entry. |
| العمدة | 414 / 414 | **Authored** (0030): 409 stamped `متفق عليه` — the collection's defining criterion, which appears nowhere in its text — and 5 left as the text states. |
| النووية / القدسية | 0 | Not attempted. |

The 213 uncovered بلوغ المرام entries are continuation entries (`وفي رواية…`,
`وله شاهد…`) that hang off the preceding hadith and carry no ruling of their own.

**Five العمدة entries are deliberately not stamped**, because each contradicts
the blanket rule: 187 (أبو داود), 198 and 397 (مسلم only), 340 (الجماعة),
398 (البخاري only). Stamping those would convert a harmless redundancy into a
factual error.

### Two extractor guards, both derived from real misfires

Each fires on exactly one entry in 1,978, with no false rejections:

- **Unbalanced closing quote** → the anchor landed inside the matn's quotation.
  العمدة 173 ends `...فَلَا أَزَالُ أُخْرِجُهُ كَمَا كُنْتُ أُخْرِجُهُ »` — أخرجه there is Abu
  Sa'id's verb. A takhrij that legitimately quotes an alternate wording keeps its
  quotes balanced, so 76 valid بلوغ gradings containing «…» are unaffected.
- **Colon immediately after رواه** → companions, not collectors. العمدة 191 reads
  `رَوَاهُ: أَبُو هُرَيْرَةَ، وَعَائِشَةُ، وَأَنَسُ بْنُ مَالِكٍ`. A real takhrij names its collector
  first (`رَوَاهُ الْبَيْهَقِيُّ: عَنْ عَلِيٍّ…`), so the colon never comes first.
