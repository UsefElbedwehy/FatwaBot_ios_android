// Dua import pipeline (docs/features/content-import.md). Mirrors the azkar
// importer for content.dua_categories / content.duas + the apps' bundled JSON.

import {
  chunk,
  deterministicUuid,
  generatedHeader,
  jsonbLiteral,
  resolveLocale,
  sqlString,
  type Translations,
} from "./import_common.ts";

export interface DuaItemInput {
  title?: Translations;
  arabic: string;
  transliteration?: Translations;
  translation?: Translations;
  source?: string;
}

export interface DuaCategoryInput {
  slug: string;
  name: Translations;
  sortOrder?: number;
  items: DuaItemInput[];
}

export interface DuaDataset {
  categories: DuaCategoryInput[];
}

const SLUG_RE = /^[a-z0-9_-]{1,40}$/;

export function validate(dataset: DuaDataset): string[] {
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
    } else slugs.add(c.slug);
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
    }
  }
  return errors;
}

export interface BuildOptions {
  /** Default false — new imports stay unpublished until a reviewer approves. */
  published?: boolean;
  /** Provenance recorded on every row. */
  sourceDataset?: string;
  chunkSize?: number;
}

export function buildSql(dataset: DuaDataset, options: BuildOptions = {}): string {
  const errors = validate(dataset);
  if (errors.length > 0) throw new Error(`Invalid dua dataset:\n - ${errors.join("\n - ")}`);
  const published = options.published ?? false;
  const sourceDataset = options.sourceDataset ?? "";
  const chunkSize = options.chunkSize ?? 500;

  const blocks = dataset.categories.map((c) => {
    const rows = c.items.map((it, i) =>
      "    (cat_id, " +
      [
        String(i),
        jsonbLiteral(it.title ?? {}),
        sqlString(it.arabic.trim()),
        jsonbLiteral(it.transliteration ?? {}),
        jsonbLiteral(it.translation ?? {}),
        sqlString(it.source ?? ""),
        sqlString(sourceDataset),
        String(published),
      ].join(", ") + ")"
    );
    const inserts = chunk(rows, chunkSize).map((part) =>
      `  insert into content.duas
    (category_id, sort_order, title_translations, arabic_text, transliteration_translations, translation_translations, source, source_dataset, published)
  values
${part.join(",\n")};`
    ).join("\n\n");

    return `do $$
declare cat_id uuid;
begin
  insert into content.dua_categories (slug, name_translations, sort_order, published)
  values (${sqlString(c.slug)}, ${jsonbLiteral(c.name)}, ${c.sortOrder ?? 0}, ${published})
  on conflict (app_id, slug) do update set
    name_translations = excluded.name_translations,
    sort_order = excluded.sort_order,
    published = excluded.published,
    updated_at = now()
  returning id into cat_id;

  delete from content.duas where category_id = cat_id;

${inserts}
end $$;`;
  });

  const total = dataset.categories.reduce((n, c) => n + c.items.length, 0);
  return generatedHeader(
    `Duas: ${dataset.categories.length} categories, ${total} duas, published=${published}`,
  ) +
    "\n" + blocks.join("\n\n") + "\n";
}

export function toBundledJson(dataset: DuaDataset, locale: string): unknown {
  return {
    version: 1,
    categories: dataset.categories.map((c, ci) => ({
      id: deterministicUuid(`dua:${c.slug}`),
      slug: c.slug,
      sortOrder: c.sortOrder ?? ci,
      name: resolveLocale(c.name, locale),
      duas: c.items.map((it, ii) => ({
        id: deterministicUuid(`dua:${c.slug}:${ii}`),
        sortOrder: ii,
        title: resolveLocale(it.title, locale), // model requires a String (may be "")
        arabicText: it.arabic.trim(),
        transliteration: resolveLocale(it.transliteration, locale) || null,
        translation: resolveLocale(it.translation, locale) || null,
        source: it.source ?? "",
      })),
    })),
  };
}

// --- Adapter: rn0x/Adhkar-json (Arabic-native Hisn al-Muslim) ----------------
// Public-domain Arabic matn only — we deliberately import the Arabic text +
// Arabic category titles and attribute حصن المسلم, and DO NOT pull any
// translation/transliteration (those editions are typically copyrighted).

export interface HisnArCategory {
  id: number;
  category: string;
  array: Array<{ id: number; text: string }>;
}

export function fromHisnAlMuslimAr(categories: HisnArCategory[]): DuaDataset {
  return {
    categories: categories
      .filter((c) => Array.isArray(c.array) && c.array.some((i) => i.text?.trim()))
      .map((c, idx) => ({
        slug: `hisn-${c.id}`,
        name: { ar: c.category.trim() },
        sortOrder: idx,
        items: c.array
          .filter((i) => typeof i.text === "string" && i.text.trim() !== "")
          .map((i) => ({ arabic: i.text.trim(), source: "حصن المسلم" })),
      })),
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
    console.error(
      "Usage: deno run -A scripts/dua_import.ts --in <dataset.json> [--sql <out.sql>] [--bundled-dir <dir>] [--publish]",
    );
    Deno.exit(1);
  }
  const dataset = JSON.parse(await Deno.readTextFile(input)) as DuaDataset;
  const errors = validate(dataset);
  if (errors.length > 0) {
    console.error(`Validation failed:\n - ${errors.join("\n - ")}`);
    Deno.exit(1);
  }
  const sqlOut = get("--sql");
  if (sqlOut) {
    await Deno.writeTextFile(
      sqlOut,
      buildSql(dataset, { published: publish, sourceDataset: get("--source-dataset") }),
    );
    console.error(`Wrote SQL → ${sqlOut} (published=${publish})`);
  }
  const bundledDir = get("--bundled-dir");
  if (bundledDir) {
    for (const locale of ["ar", "en"]) {
      const path = `${bundledDir}/duas.${locale}.json`;
      await Deno.writeTextFile(path, JSON.stringify(toBundledJson(dataset, locale), null, 2) + "\n");
      console.error(`Wrote bundled → ${path}`);
    }
  }
}
