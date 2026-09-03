import { assert, assertEquals, assertStringIncludes, assertThrows } from "jsr:@std/assert@1";
import {
  type AzkarDataset,
  buildSql,
  fromHisnCategories,
  fromHisnCategory,
  fromSeenArabic,
  type HisnCategoryRaw,
  type SeenArabicItem,
  toBundledJson,
  validate,
} from "../scripts/azkar_import.ts";
import { deterministicUuid } from "../scripts/import_common.ts";

const DATASET: AzkarDataset = {
  categories: [
    {
      slug: "morning",
      name: { ar: "أذكار الصباح", en: "Morning Adhkar" },
      sortOrder: 0,
      items: [
        {
          arabic: "سُبْحَانَ اللَّهِ",
          translation: { en: "Glory be to Allah" },
          transliteration: { en: "Subhan Allah" },
          virtue: { ar: "فضل" },
          source: "مسلم",
          repeatCount: 33,
        },
        { arabic: "الْحَمْدُ لِلَّهِ", source: "البخاري" },
      ],
    },
  ],
};

Deno.test("validate accepts a good dataset, rejects bad slugs/empty arabic/dupes", () => {
  assertEquals(validate(DATASET), []);
  assert(validate({ categories: [] }).length > 0);
  assert(
    validate({ categories: [{ slug: "BAD X", name: { ar: "x" }, items: [{ arabic: "a" }] }] }).some((e) =>
      e.includes("slug")
    ),
  );
  assert(
    validate({ categories: [{ slug: "x", name: { en: "no arabic" }, items: [{ arabic: "a" }] }] }).some((e) =>
      e.includes("name.ar")
    ),
  );
  assert(
    validate({ categories: [{ slug: "x", name: { ar: "x" }, items: [{ arabic: "   " }] }] }).some((e) =>
      e.includes("arabic")
    ),
  );
  const dupe: AzkarDataset = { categories: [DATASET.categories[0], DATASET.categories[0]] };
  assert(validate(dupe).some((e) => e.includes("duplicated")));
});

Deno.test("buildSql upserts the category and rebuilds items (delete-then-insert)", () => {
  const sql = buildSql(DATASET);
  assertStringIncludes(sql, "insert into content.azkar_categories");
  assertStringIncludes(sql, "on conflict (app_id, slug) do update set");
  assertStringIncludes(sql, "returning id into cat_id");
  // Idempotent item rebuild
  assertStringIncludes(sql, "delete from content.azkar_items where category_id = cat_id;");
  assertStringIncludes(sql, "insert into content.azkar_items");
  assertStringIncludes(sql, "(cat_id, 0,"); // first item, sort_order 0
  assertStringIncludes(sql, "33"); // repeat count carried
  assertStringIncludes(sql, "do $$");
  assertStringIncludes(sql, "end $$;");
});

Deno.test("buildSql throws on invalid data instead of emitting broken SQL", () => {
  assertThrows(() => buildSql({ categories: [] }), Error, "Invalid azkar dataset");
});

Deno.test("buildSql records provenance and defaults to unpublished (pending review)", () => {
  const sql = buildSql(DATASET, { sourceDataset: "Seen-Arabic (MIT)" });
  assertStringIncludes(sql, "source_dataset");
  assertStringIncludes(sql, "'Seen-Arabic (MIT)'");
  assertStringIncludes(sql, ", false)"); // published defaults to false -> stays pending review
});

Deno.test("toBundledJson matches the app's ContentKit shape and localises", () => {
  const ar = toBundledJson(DATASET, "ar") as { version: number; categories: Array<Record<string, unknown>> };
  assertEquals(ar.version, 1);
  const cat = ar.categories[0];
  assertEquals(cat.slug, "morning");
  assertEquals(cat.name, "أذكار الصباح"); // ar name
  const items = cat.items as Array<Record<string, unknown>>;
  assertEquals(items[0].arabicText, "سُبْحَانَ اللَّهِ");
  assertEquals(items[0].repeatCount, 33);
  // Missing translation/transliteration -> null, not "".
  assertEquals(items[1].translation, null);
  assertEquals(items[1].transliteration, null);

  const en = toBundledJson(DATASET, "en") as { categories: Array<Record<string, unknown>> };
  assertEquals(en.categories[0].name, "Morning Adhkar"); // en name
  const enItems = en.categories[0].items as Array<Record<string, unknown>>;
  assertEquals(enItems[0].translation, "Glory be to Allah");
  assertEquals(enItems[0].transliteration, "Subhan Allah");
  // ids are stable + identical across locales (so ar/en stay aligned)
  assertEquals((ar.categories[0] as Record<string, unknown>).id, en.categories[0].id);
});

Deno.test("deterministicUuid is stable and UUID-shaped (v4)", () => {
  const a = deterministicUuid("azkar:morning:0");
  assertEquals(a, deterministicUuid("azkar:morning:0"));
  assert(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(a), a);
  assert(a !== deterministicUuid("azkar:morning:1"));
});

Deno.test("fromHisnCategory maps a Hisn al-Muslim category, Arabic-only + count", () => {
  const cat: HisnCategoryRaw = {
    id: 27,
    category: "الأذكار بعد السلام من الصلاة",
    array: [
      { id: 1, text: "أَسْتَغْفِرُ اللَّهَ", count: 3 },
      { id: 2, text: "سُبْحَانَ اللَّهِ", count: 33 },
      { id: 3, text: "   " }, // blank dropped
    ],
  };
  const out = fromHisnCategory(
    cat,
    "after_prayer",
    { ar: "أذكار بعد السلام من الصلاة", en: "After-Prayer" },
    2,
  );
  assertEquals(out.slug, "after_prayer");
  assertEquals(out.sortOrder, 2);
  assertEquals(out.items.length, 2);
  assertEquals(out.items[0].repeatCount, 3);
  assertEquals(out.items[1].repeatCount, 33);
  assertEquals(out.items[0].source, "حصن المسلم");
  assertEquals(out.items[0].translation, undefined); // no copyrighted translation pulled
  assertEquals(validate({ categories: [out] }), []);
});

Deno.test("fromHisnCategories merges several categories into one, in order", () => {
  const cats: HisnCategoryRaw[] = [
    { id: 95, category: "دعاء الركوب", array: [{ id: 1, text: "بِسْمِ اللَّهِ" }] },
    {
      id: 96,
      category: "دعاء السفر",
      array: [{ id: 1, text: "اللَّهُ أَكْبَرُ", count: 3 }, { id: 2, text: "سُبْحَانَ" }],
    },
  ];
  const out = fromHisnCategories(cats, "travel", { ar: "أذكار السفر", en: "Travel" }, 5);
  assertEquals(out.slug, "travel");
  assertEquals(out.items.length, 3); // 1 + 2, concatenated in order
  assertEquals(out.items[0].arabic, "بِسْمِ اللَّهِ");
  assertEquals(out.items[1].repeatCount, 3);
  assertEquals(out.items.every((i) => i.source === "حصن المسلم"), true);
  assertEquals(validate({ categories: [out] }), []);
});

Deno.test("fromSeenArabic splits by type (0=both,1=morning,2=evening) and merges en", () => {
  const ar: SeenArabicItem[] = [
    { order: 1, content: "ذكر مشترك", type: 0, count: 1, fadl: "فضل", source: "مصدر" },
    { order: 2, content: "ذكر صباح", type: 1, count: 3 },
    { order: 3, content: "ذكر مساء", type: 2 },
  ];
  const en: SeenArabicItem[] = [
    { order: 1, content: "x", type: 0, translation: "shared", transliteration: "dhikr" },
    { order: 2, content: "x", type: 1, translation: "morning" },
    { order: 3, content: "x", type: 2, translation: "evening" },
  ];
  const ds = fromSeenArabic(ar, en);
  const [morning, evening] = ds.categories;
  assertEquals(morning.slug, "morning");
  assertEquals(morning.items.length, 2); // type 0 + 1
  assertEquals(evening.items.length, 2); // type 0 + 2
  assertEquals(morning.items[0].arabic, "ذكر مشترك");
  assertEquals(morning.items[0].translation, { en: "shared" });
  assertEquals(morning.items[0].transliteration, { en: "dhikr" });
  assertEquals(morning.items[0].virtue, { ar: "فضل" });
  assertEquals(morning.items[1].repeatCount, 3);
  assertEquals(validate(ds), []); // adapter output is always valid
});
