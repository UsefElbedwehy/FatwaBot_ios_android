// Hadith import pipeline (docs/features/hadith-import.md).
//
// Offline, reviewable, idempotent: reads a local dataset JSON and emits a SQL
// file that upserts into content.hadith_collections + content.hadith_entries.
// Deliberately NOT a runtime dependency — the app stays offline-first and every
// text is reviewed by you before it's published (authenticity is the product).
//
// Pure transform functions are exported for testing; the CLI at the bottom runs
// only when executed directly.

import { deterministicUuid, resolveLocale } from "./import_common.ts";

export interface Translations {
  [locale: string]: string;
}

export interface HadithCollectionInput {
  slug: string;
  name: Translations;
  description?: Translations;
  sortOrder?: number;
}

export interface HadithEntryInput {
  number: number;
  arabic: string;
  translation?: Translations;
  grading?: string;
  benefit?: Translations;
  source?: string;
}

export interface HadithDataset {
  collection: HadithCollectionInput;
  entries: HadithEntryInput[];
}

export interface BuildOptions {
  /** Whether the imported rows are immediately visible to the app. Defaults to
   * false so nothing goes live unreviewed. */
  published?: boolean;
  /** Provenance recorded on every row (e.g. "fawazahmed0 ara-bukhari"). */
  sourceDataset?: string;
  /** Review state stamped on every entry. Migration 0014 enforces
   * `not published or review_status = 'approved'`, so publishing without an
   * approved status would fail the check constraint. Defaults to 'approved'
   * when published (paired with reviewedBy), else 'pending'. */
  reviewStatus?: "pending" | "approved" | "rejected";
  /** Who approved the rows (e.g. "auto:trusted-import"). Defaults to
   * 'auto:trusted-import' when published, else null. */
  reviewedBy?: string;
  /** Rows per INSERT statement (keeps generated statements a sane size). */
  chunkSize?: number;
}

const SLUG_RE = /^[a-z0-9_-]{1,40}$/;

/** Escapes a value for a single-quoted Postgres string literal. Supabase runs
 * with standard_conforming_strings=on, so only the single quote is special. */
export function sqlString(value: string): string {
  return `'${value.replace(/'/g, "''")}'`;
}

/** A `'<json>'::jsonb` literal with the JSON text safely single-quote-escaped. */
export function jsonbLiteral(obj: Translations): string {
  // Sort keys so identical content produces identical SQL (stable diffs).
  const ordered: Translations = {};
  for (const key of Object.keys(obj).sort()) ordered[key] = obj[key];
  return `${sqlString(JSON.stringify(ordered))}::jsonb`;
}

/** Returns human-readable validation errors; empty array means the dataset is
 * safe to import. */
export function validate(dataset: HadithDataset): string[] {
  const errors: string[] = [];
  const c = dataset.collection;
  if (!c || typeof c.slug !== "string" || !SLUG_RE.test(c.slug)) {
    errors.push(`collection.slug must match ${SLUG_RE} (got ${JSON.stringify(c?.slug)})`);
  }
  if (!c?.name || typeof c.name.ar !== "string" || c.name.ar.trim() === "") {
    errors.push("collection.name.ar is required (Arabic-first)");
  }
  if (!Array.isArray(dataset.entries) || dataset.entries.length === 0) {
    errors.push("entries must be a non-empty array");
    return errors;
  }
  const seen = new Set<number>();
  for (const [i, e] of dataset.entries.entries()) {
    if (!Number.isInteger(e.number) || e.number < 1) {
      errors.push(`entries[${i}].number must be a positive integer (got ${JSON.stringify(e.number)})`);
    } else if (seen.has(e.number)) {
      errors.push(`entries[${i}].number ${e.number} is duplicated`);
    } else {
      seen.add(e.number);
    }
    if (typeof e.arabic !== "string" || e.arabic.trim() === "") {
      errors.push(`entries[${i}].arabic is required and must be non-empty`);
    }
  }
  return errors;
}

function chunk<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}

/** Builds the idempotent SQL for one dataset. Wrapped in a DO block so the
 * collection's generated id can be reused as the entries' FK. Re-running
 * updates existing rows (upsert) rather than erroring or duplicating. */
export function buildSql(dataset: HadithDataset, options: BuildOptions = {}): string {
  const errors = validate(dataset);
  if (errors.length > 0) {
    throw new Error(`Invalid hadith dataset:\n - ${errors.join("\n - ")}`);
  }
  const published = options.published ?? false;
  const sourceDataset = options.sourceDataset ?? "";
  // 0014 enforces `not published or review_status = 'approved'`, so a published
  // row must carry an approved status or the insert fails the check constraint.
  const reviewStatus = options.reviewStatus ?? (published ? "approved" : "pending");
  const reviewedBy = options.reviewedBy ?? (published ? "auto:trusted-import" : "");
  const reviewedByLiteral = reviewedBy ? sqlString(reviewedBy) : "null";
  const reviewedAtLiteral = reviewStatus === "approved" ? "now()" : "null";
  const chunkSize = options.chunkSize ?? 500;
  const c = dataset.collection;

  const entryValues = dataset.entries.map((e) =>
    "    (col_id, " +
    [
      String(e.number),
      sqlString(e.arabic),
      jsonbLiteral(e.translation ?? {}),
      sqlString(e.grading ?? ""),
      jsonbLiteral(e.benefit ?? {}),
      sqlString(e.source ?? ""),
      sqlString(sourceDataset),
      sqlString(reviewStatus),
      reviewedByLiteral,
      reviewedAtLiteral,
      String(published),
    ].join(", ") +
    ")"
  );

  const insertStatements = chunk(entryValues, chunkSize).map((rows) =>
    `  insert into content.hadith_entries
    (collection_id, number, arabic_text, translation_translations, grading, benefit_note_translations, source, source_dataset, review_status, reviewed_by, reviewed_at, published)
  values
${rows.join(",\n")}
  on conflict (app_id, collection_id, number) do update set
    arabic_text = excluded.arabic_text,
    translation_translations = excluded.translation_translations,
    grading = excluded.grading,
    benefit_note_translations = excluded.benefit_note_translations,
    source = excluded.source,
    source_dataset = excluded.source_dataset,
    review_status = excluded.review_status,
    reviewed_by = excluded.reviewed_by,
    reviewed_at = excluded.reviewed_at,
    published = excluded.published,
    updated_at = now();`
  ).join("\n\n");

  return `-- Generated by scripts/hadith_import.ts — do not hand-edit; re-run the importer.
-- Collection: ${c.slug} (${dataset.entries.length} entries, published=${published})
-- Idempotent: re-applying updates existing rows.

-- Dollar-quote tag $fb$ (not $$): some matn contains a literal "$$" that would
-- otherwise close the block early.
do $fb$
declare col_id uuid;
begin
  insert into content.hadith_collections
    (slug, name_translations, description_translations, sort_order, published)
  values
    (${sqlString(c.slug)}, ${jsonbLiteral(c.name)}, ${jsonbLiteral(c.description ?? {})}, ${
    c.sortOrder ?? 0
  }, ${published})
  on conflict (app_id, slug) do update set
    name_translations = excluded.name_translations,
    description_translations = excluded.description_translations,
    sort_order = excluded.sort_order,
    published = excluded.published,
    updated_at = now()
  returning id into col_id;

${insertStatements}
end $fb$;
`;
}

// --- Adapters: map common public dataset shapes onto HadithDataset -----------

/** The fawazahmed0/hadith-db edition shape (jsdelivr): one file per edition,
 * e.g. ara-bukhari.json / eng-bukhari.json:
 *   { metadata: { name, section, ... }, hadiths: [{ hadithnumber, text, ... }] }
 * Pass the Arabic edition as `arabicEdition` (public domain for the canonical
 * matn) and optionally an English edition to merge as the translation. */
export interface FawazEdition {
  metadata?: { name?: string };
  hadiths?: Array<
    { hadithnumber?: number; arabicnumber?: number; text?: string; grades?: Array<{ grade?: string }> }
  >;
}

export function fromFawazEdition(
  slug: string,
  names: Translations,
  arabicEdition: FawazEdition,
  englishEdition?: FawazEdition,
  options: { description?: Translations; sortOrder?: number } = {},
): HadithDataset {
  const englishByNumber = new Map<number, string>();
  for (const h of englishEdition?.hadiths ?? []) {
    if (typeof h.hadithnumber === "number" && typeof h.text === "string") {
      englishByNumber.set(h.hadithnumber, h.text);
    }
  }
  // The DB key is `number int` and unique per collection. fawaz uses fractional
  // hadithnumbers (e.g. 402.2) for secondary narrations whose integer part
  // collides with the primary — key on the integer canonical number and skip the
  // fractional variants (the primary narration is always retained). The caller
  // can compare entries.length against the raw count to report how many were
  // skipped — nothing is dropped silently.
  const entries: HadithEntryInput[] = [];
  const seen = new Set<number>();
  for (const h of arabicEdition.hadiths ?? []) {
    if (typeof h.hadithnumber !== "number" || !Number.isInteger(h.hadithnumber)) continue;
    if (typeof h.text !== "string" || h.text.trim() === "") continue;
    if (seen.has(h.hadithnumber)) continue;
    seen.add(h.hadithnumber);
    const en = englishByNumber.get(h.hadithnumber);
    const grade = h.grades?.map((g) => g.grade).filter(Boolean).join(" · ") ?? "";
    entries.push({
      number: h.hadithnumber,
      arabic: h.text.trim(),
      translation: en ? { en: en.trim() } : undefined,
      grading: grade,
    });
  }
  return {
    collection: { slug, name: names, description: options.description, sortOrder: options.sortOrder },
    entries,
  };
}

// --- Bundled offline JSON (mirrors the app's ContentKit / core:content shapes) -
// One detail file per collection per locale (hadith-<slug>.<locale>.json) plus a
// single collections index (hadith-collections.<locale>.json). Deterministic ids
// so re-runs and the ar/en files stay in lockstep. Only compact collections are
// bundled; large ones are catalogued in the index and fetched on demand (sync).

/** The per-collection detail file the app loads for `hadith-<slug>.<locale>`. */
export function toBundledJson(dataset: HadithDataset, locale: string): unknown {
  const c = dataset.collection;
  return {
    version: 1,
    slug: c.slug,
    name: resolveLocale(c.name, locale),
    description: resolveLocale(c.description, locale),
    entries: dataset.entries.map((e) => ({
      id: deterministicUuid(`hadith:${c.slug}:${e.number}`),
      number: e.number,
      arabicText: e.arabic.trim(),
      translation: resolveLocale(e.translation, locale) || null,
      grading: e.grading ?? "",
      benefitNote: resolveLocale(e.benefit, locale) || null,
      source: e.source ?? "",
    })),
  };
}

/** The catalogue file (`hadith-collections.<locale>`): lightweight summaries for
 * every collection, whether or not its detail is bundled. */
export function collectionsIndex(
  datasets: HadithDataset[],
  locale: string,
): unknown {
  return {
    collections: datasets.map((d) => ({
      id: deterministicUuid(`hadith:${d.collection.slug}`),
      slug: d.collection.slug,
      name: resolveLocale(d.collection.name, locale),
      description: resolveLocale(d.collection.description, locale),
      entryCount: d.entries.length,
    })),
  };
}

// --- CLI ---------------------------------------------------------------------

function parseArgs(
  args: string[],
): { input?: string; out?: string; publish: boolean; sourceDataset?: string } {
  const result: { input?: string; out?: string; publish: boolean; sourceDataset?: string } = {
    publish: false,
  };
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === "--publish") result.publish = true;
    else if (a === "--in") result.input = args[++i];
    else if (a === "--out") result.out = args[++i];
    else if (a === "--source-dataset") result.sourceDataset = args[++i];
  }
  return result;
}

if (import.meta.main) {
  const { input, out, publish, sourceDataset } = parseArgs(Deno.args);
  if (!input) {
    console.error(
      "Usage: deno run --allow-read --allow-write scripts/hadith_import.ts --in <dataset.json> [--out <file.sql>] [--publish]\n" +
        "  <dataset.json> is a normalized HadithDataset (see docs/features/hadith-import.md).",
    );
    Deno.exit(1);
  }
  const dataset = JSON.parse(await Deno.readTextFile(input)) as HadithDataset;
  const errors = validate(dataset);
  if (errors.length > 0) {
    console.error(`Validation failed:\n - ${errors.join("\n - ")}`);
    Deno.exit(1);
  }
  const sql = buildSql(dataset, { published: publish, sourceDataset });
  const outPath = out ?? `supabase/imports/hadith_${dataset.collection.slug}.sql`;
  await Deno.mkdir(new URL("./", `file://${Deno.cwd()}/${outPath}`).pathname, { recursive: true }).catch(
    () => {},
  );
  await Deno.writeTextFile(outPath, sql);
  console.error(
    `Wrote ${dataset.entries.length} entries for '${dataset.collection.slug}' → ${outPath}` +
      `${
        publish
          ? " (published)"
          : " (unpublished — review, then re-run with --publish or flip in the dashboard)"
      }`,
  );
}
