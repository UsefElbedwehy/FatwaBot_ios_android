// Azkar import pipeline (docs/features/content-import.md).
// Imports azkar categories + items into content.azkar_categories/azkar_items and
// (optionally) regenerates the apps' bundled offline JSON. Offline, reviewable,
// idempotent — no runtime API dependency.

import {
  chunk,
  deterministicUuid,
  generatedHeader,
  jsonbLiteral,
  resolveLocale,
  sqlString,
  type Translations,
} from "./import_common.ts";

export interface AzkarItemInput {
  arabic: string;
  transliteration?: Translations;
  translation?: Translations;
  virtue?: Translations;
  source?: string;
  repeatCount?: number;
}

export interface AzkarCategoryInput {
  slug: string;
  name: Translations;
  sortOrder?: number;
  items: AzkarItemInput[];
}

export interface AzkarDataset {
  categories: AzkarCategoryInput[];
}

const SLUG_RE = /^[a-z0-9_-]{1,40}$/;

export function validate(dataset: AzkarDataset): string[] {
  const errors: string[] = [];
  if (!Array.isArray(dataset.categories) || dataset.categories.length === 0) {
    return ["categories must be a non-empty array"];
  }
  const slugs = new Set<string>();
  for (const [ci, c] of dataset.categories.entries()) {
    if (typeof c.slug !== "string" || !SLUG_RE.test(c.slug)) {
      errors.push(`categories[${ci}].slug must match ${SLUG_RE} (got ${JSON.stringify(c.slug)})`);
    } else if (slugs.has(c.slug)) {
      errors.push(`categories[${ci}].slug '${c.slug}' is duplicated`);
    } else {
      slugs.add(c.slug);
    }
    if (!c.name || typeof c.name.ar !== "string" || c.name.ar.trim() === "") {
      errors.push(`categories[${ci}].name.ar is required`);
    }
    if (!Array.isArray(c.items) || c.items.length === 0) {
      errors.push(`categories[${ci}].items must be a non-empty array`);
      continue;
    }
    for (const [ii, it] of c.items.entries()) {
      if (typeof it.arabic !== "string" || it.arabic.trim() === "") {
        errors.push(`categories[${ci}].items[${ii}].arabic is required and non-empty`);
      }
      if (it.repeatCount !== undefined && (!Number.isInteger(it.repeatCount) || it.repeatCount < 1)) {
        errors.push(`categories[${ci}].items[${ii}].repeatCount must be a positive integer`);
      }
    }
  }
  return errors;
}

export interface BuildOptions {
  /** Default false — new imports stay unpublished until a reviewer approves. */
  published?: boolean;
  /** Provenance recorded on every row (e.g. "Seen-Arabic (MIT)"). */
  sourceDataset?: string;
  chunkSize?: number;
}

/** Idempotent SQL. Items have no natural key, so each category is rebuilt
 * (delete-then-insert) — this handles reordered/removed items cleanly and never
 * duplicates on re-run. Azkar progress is tracked by category, not item, so
 * replacing items is safe. */
export function buildSql(dataset: AzkarDataset, options: BuildOptions = {}): string {
  const errors = validate(dataset);
  if (errors.length > 0) throw new Error(`Invalid azkar dataset:\n - ${errors.join("\n - ")}`);
  const published = options.published ?? false;
  const sourceDataset = options.sourceDataset ?? "";
  const chunkSize = options.chunkSize ?? 500;

  const blocks = dataset.categories.map((c) => {
    const rows = c.items.map((it, i) =>
      "    (cat_id, " +
      [
        String(i),
        sqlString(it.arabic.trim()),
        jsonbLiteral(it.transliteration ?? {}),
        jsonbLiteral(it.translation ?? {}),
        jsonbLiteral(it.virtue ?? {}),
        sqlString(it.source ?? ""),
        String(it.repeatCount ?? 1),
        sqlString(sourceDataset),
        String(published),
      ].join(", ") + ")"
    );
    const inserts = chunk(rows, chunkSize).map((part) =>
      `  insert into content.azkar_items
    (category_id, sort_order, arabic_text, transliteration_translations, translation_translations, virtue_note_translations, source, repeat_count, source_dataset, published)
  values
${part.join(",\n")};`
    ).join("\n\n");

    return `do $$
declare cat_id uuid;
begin
  insert into content.azkar_categories (slug, name_translations, sort_order, published)
  values (${sqlString(c.slug)}, ${jsonbLiteral(c.name)}, ${c.sortOrder ?? 0}, ${published})
  on conflict (app_id, slug) do update set
    name_translations = excluded.name_translations,
    sort_order = excluded.sort_order,
    published = excluded.published,
    updated_at = now()
  returning id into cat_id;

  delete from content.azkar_items where category_id = cat_id;

${inserts}
end $$;`;
  });

  const total = dataset.categories.reduce((n, c) => n + c.items.length, 0);
  return generatedHeader(`Azkar: ${dataset.categories.length} categories, ${total} items, published=${published}`) +
    "\n" + blocks.join("\n\n") + "\n";
}

/** Emits the apps' bundled offline JSON for one locale (mirrors the shape the
 * ContentKit / core:content loaders expect). Deterministic ids so re-runs and
 * the ar/en files stay aligned. */
export function toBundledJson(dataset: AzkarDataset, locale: string): unknown {
  return {
    version: 1,
    categories: dataset.categories.map((c, ci) => ({
      id: deterministicUuid(`azkar:${c.slug}`),
      slug: c.slug,
      sortOrder: c.sortOrder ?? ci,
      name: resolveLocale(c.name, locale),
      items: c.items.map((it, ii) => ({
        id: deterministicUuid(`azkar:${c.slug}:${ii}`),
        sortOrder: ii,
        arabicText: it.arabic.trim(),
        transliteration: resolveLocale(it.transliteration, locale) || null,
        translation: resolveLocale(it.translation, locale) || null,
        virtueNote: resolveLocale(it.virtue, locale) || null,
        source: it.source ?? "",
        repeatCount: it.repeatCount ?? 1,
      })),
    })),
  };
}

// --- Adapter: Seen-Arabic Morning-And-Evening-Adhkar-DB (MIT) ----------------
// result/en.json carries Arabic `content` + `translation` + `transliteration`;
// result/ar.json carries the Arabic `fadl` (virtue) + `source` (with grading).
// `type`: 0 = both morning & evening, 1 = morning only, 2 = evening only.

export interface SeenArabicItem {
  order: number;
  content: string;
  translation?: string;
  transliteration?: string;
  count?: number;
  fadl?: string;
  source?: string;
  type: number;
}

export function fromSeenArabic(ar: SeenArabicItem[], en: SeenArabicItem[]): AzkarDataset {
  const enByOrder = new Map(en.map((x) => [x.order, x]));
  const build = (types: number[]): AzkarItemInput[] =>
    ar
      .filter((x) => types.includes(x.type))
      .sort((a, b) => a.order - b.order)
      .map((a) => {
        const e = enByOrder.get(a.order);
        return {
          arabic: a.content,
          translation: e?.translation ? { en: e.translation } : undefined,
          transliteration: e?.transliteration ? { en: e.transliteration } : undefined,
          virtue: a.fadl ? { ar: a.fadl } : undefined,
          source: a.source ?? "",
          repeatCount: a.count && a.count > 0 ? a.count : 1,
        };
      });

  return {
    categories: [
      { slug: "morning", name: { ar: "أذكار الصباح", en: "Morning Adhkar" }, sortOrder: 0, items: build([0, 1]) },
      { slug: "evening", name: { ar: "أذكار المساء", en: "Evening Adhkar" }, sortOrder: 1, items: build([0, 2]) },
    ],
  };
}

// --- Adapter: a single rn0x/Adhkar-json (Hisn al-Muslim) category ------------
// For azkar categories that source has but Seen-Arabic doesn't (after-prayer,
// sleep, waking). Arabic matn only, attributed حصن المسلم (translations of that
// edition are typically copyrighted).

export interface HisnCategoryRaw {
  id: number;
  category: string;
  array: Array<{ id: number; text: string; count?: number }>;
}

export function fromHisnCategory(
  cat: HisnCategoryRaw,
  slug: string,
  name: Translations,
  sortOrder: number,
): AzkarCategoryInput {
  return {
    slug,
    name,
    sortOrder,
    items: cat.array
      .filter((i) => typeof i.text === "string" && i.text.trim() !== "")
      .map((i) => ({
        arabic: i.text.trim(),
        repeatCount: i.count && i.count > 0 ? i.count : 1,
        source: "حصن المسلم",
      })),
  };
}

/** Merges several rn0x categories into one azkar category (their items are
 * concatenated in the given order). Used to group related Hisn al-Muslim
 * chapters — e.g. riding + journey + return → a single "travel" category. */
export function fromHisnCategories(
  cats: HisnCategoryRaw[],
  slug: string,
  name: Translations,
  sortOrder: number,
): AzkarCategoryInput {
  return {
    slug,
    name,
    sortOrder,
    items: cats.flatMap((c) => fromHisnCategory(c, slug, name, sortOrder).items),
  };
}

// --- CLI ---------------------------------------------------------------------

if (import.meta.main) {
  const args = Deno.args;
  const get = (flag: string) => {
    const i = args.indexOf(flag);
    return i >= 0 ? args[i + 1] : undefined;
  };
  const input = get("--in");
  const publish = args.includes("--publish");
  if (!input) {
    console.error("Usage: deno run -A scripts/azkar_import.ts --in <dataset.json> [--sql <out.sql>] [--bundled-dir <dir>] [--publish]");
    Deno.exit(1);
  }
  const dataset = JSON.parse(await Deno.readTextFile(input)) as AzkarDataset;
  const errors = validate(dataset);
  if (errors.length > 0) {
    console.error(`Validation failed:\n - ${errors.join("\n - ")}`);
    Deno.exit(1);
  }
  const sqlOut = get("--sql");
  if (sqlOut) {
    await Deno.writeTextFile(sqlOut, buildSql(dataset, { published: publish, sourceDataset: get("--source-dataset") }));
    console.error(`Wrote SQL → ${sqlOut} (published=${publish})`);
  }
  const bundledDir = get("--bundled-dir");
  if (bundledDir) {
    for (const locale of ["ar", "en"]) {
      const path = `${bundledDir}/azkar.${locale}.json`;
      await Deno.writeTextFile(path, JSON.stringify(toBundledJson(dataset, locale), null, 2) + "\n");
      console.error(`Wrote bundled → ${path}`);
    }
  }
}
