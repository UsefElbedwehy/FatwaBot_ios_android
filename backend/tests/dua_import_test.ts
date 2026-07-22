import { assert, assertEquals, assertStringIncludes, assertThrows } from "jsr:@std/assert@1";
import {
  buildSql,
  type DuaDataset,
  fromHisnAlMuslimAr,
  type HisnArCategory,
  toBundledJson,
  validate,
} from "../scripts/dua_import.ts";

const DATASET: DuaDataset = {
  categories: [
    {
      slug: "istikhaarah",
      name: { ar: "دعاء الاستخارة", en: "Istikharah" },
      sortOrder: 0,
      items: [
        { title: { ar: "الاستخارة" }, arabic: "اللَّهُمَّ إِنِّي أَسْتَخِيرُكَ بِعِلْمِكَ", source: "البخاري" },
        { arabic: "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً" },
      ],
    },
  ],
};

Deno.test("validate accepts good data and rejects bad slug/empty arabic", () => {
  assertEquals(validate(DATASET), []);
  assert(validate({ categories: [] }).length > 0);
  assert(validate({ categories: [{ slug: "X Y", name: { ar: "x" }, items: [{ arabic: "a" }] }] }).some((e) => e.includes("slug")));
  assert(validate({ categories: [{ slug: "x", name: { ar: "x" }, items: [{ arabic: " " }] }] }).some((e) => e.includes("arabic")));
});

Deno.test("buildSql upserts category + rebuilds duas idempotently", () => {
  const sql = buildSql(DATASET);
  assertStringIncludes(sql, "insert into content.dua_categories");
  assertStringIncludes(sql, "on conflict (app_id, slug) do update set");
  assertStringIncludes(sql, "delete from content.duas where category_id = cat_id;");
  assertStringIncludes(sql, "insert into content.duas");
  assertStringIncludes(sql, "(cat_id, 0,");
  assertStringIncludes(sql, "do $$");
});

Deno.test("buildSql throws on invalid data", () => {
  assertThrows(() => buildSql({ categories: [] }), Error, "Invalid dua dataset");
});

Deno.test("buildSql records provenance and defaults to unpublished (pending review)", () => {
  const sql = buildSql(DATASET, { sourceDataset: "Hisn al-Muslim (rn0x/Adhkar-json)" });
  assertStringIncludes(sql, "source_dataset");
  assertStringIncludes(sql, "'Hisn al-Muslim (rn0x/Adhkar-json)'");
  assertStringIncludes(sql, ", false)"); // published defaults to false -> stays pending review
});

Deno.test("toBundledJson matches app shape; title is a string (never null)", () => {
  const ar = toBundledJson(DATASET, "ar") as { categories: Array<Record<string, unknown>> };
  const cat = ar.categories[0];
  assertEquals(cat.name, "دعاء الاستخارة");
  const duas = cat.duas as Array<Record<string, unknown>>;
  assertEquals(duas[0].title, "الاستخارة");
  assertEquals(duas[1].title, ""); // no title -> "" (model is non-optional String)
  assertEquals(duas[1].translation, null); // absent -> null
  assertEquals(duas[0].source, "البخاري");
});

Deno.test("fromHisnAlMuslimAr imports Arabic matn only, attributes حصن المسلم", () => {
  const src: HisnArCategory[] = [
    { id: 1, category: "أذكار الصباح", array: [{ id: 1, text: "دعاء أول" }, { id: 2, text: "  " }] },
    { id: 5, category: "دعاء السفر", array: [{ id: 1, text: "دعاء السفر" }] },
    { id: 9, category: "فارغة", array: [] }, // dropped: no usable items
  ];
  const ds = fromHisnAlMuslimAr(src);
  assertEquals(ds.categories.length, 2); // empty category dropped
  assertEquals(ds.categories[0].slug, "hisn-1");
  assertEquals(ds.categories[0].name, { ar: "أذكار الصباح" });
  assertEquals(ds.categories[0].items.length, 1); // blank item dropped
  assertEquals(ds.categories[0].items[0].arabic, "دعاء أول");
  assertEquals(ds.categories[0].items[0].source, "حصن المسلم");
  // No translation/transliteration pulled (licensing).
  assertEquals(ds.categories[0].items[0].translation, undefined);
  assertEquals(ds.categories[1].slug, "hisn-5");
  assertEquals(validate(ds), []);
});
