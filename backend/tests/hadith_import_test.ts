import { assert, assertEquals, assertStringIncludes, assertThrows } from "jsr:@std/assert@1";
import {
  buildSql,
  fromFawazEdition,
  type HadithDataset,
  jsonbLiteral,
  sqlString,
  validate,
} from "../scripts/hadith_import.ts";

const SAMPLE: HadithDataset = {
  collection: {
    slug: "nawawi40",
    name: { ar: "الأربعون النووية", en: "The Forty Hadith" },
    description: { ar: "وصف", en: "desc" },
    sortOrder: 1,
  },
  entries: [
    { number: 1, arabic: "إنما الأعمال بالنيّات", translation: { en: "Actions are by intentions" }, grading: "صحيح", source: "البخاري" },
    { number: 2, arabic: "بينما نحن جلوسٌ", grading: "صحيح" },
  ],
};

Deno.test("sqlString doubles single quotes (injection-safe)", () => {
  assertEquals(sqlString("it's"), "'it''s'");
  assertEquals(sqlString("'; drop table x; --"), "'''; drop table x; --'");
  assertEquals(sqlString("قال: «كذا»"), "'قال: «كذا»'");
});

Deno.test("jsonbLiteral is stable (sorted keys) and quote-safe", () => {
  const a = jsonbLiteral({ en: "b", ar: "a" });
  const b = jsonbLiteral({ ar: "a", en: "b" });
  assertEquals(a, b); // key order doesn't change the output
  assertStringIncludes(a, "::jsonb");
  // An apostrophe inside the value stays escaped for the surrounding literal.
  assertStringIncludes(jsonbLiteral({ en: "don't" }), "don''t");
});

Deno.test("validate accepts a good dataset and rejects bad ones", () => {
  assertEquals(validate(SAMPLE), []);

  assertEquals(validate({ ...SAMPLE, collection: { ...SAMPLE.collection, slug: "BAD SLUG!" } }).length, 1);

  const noArabicName = validate({ ...SAMPLE, collection: { slug: "x", name: { en: "only english" } } });
  assert(noArabicName.some((e) => e.includes("name.ar")));

  const dupNumbers = validate({
    ...SAMPLE,
    entries: [{ number: 1, arabic: "a" }, { number: 1, arabic: "b" }],
  });
  assert(dupNumbers.some((e) => e.includes("duplicated")));

  const emptyArabic = validate({ ...SAMPLE, entries: [{ number: 1, arabic: "   " }] });
  assert(emptyArabic.some((e) => e.includes("arabic is required")));

  assert(validate({ ...SAMPLE, entries: [] }).some((e) => e.includes("non-empty")));
});

Deno.test("buildSql throws on an invalid dataset rather than emitting bad SQL", () => {
  assertThrows(() => buildSql({ ...SAMPLE, entries: [] }), Error, "Invalid hadith dataset");
});

Deno.test("buildSql is idempotent (upsert) and wires the collection FK", () => {
  const sql = buildSql(SAMPLE);
  // Collection upsert
  assertStringIncludes(sql, "insert into content.hadith_collections");
  assertStringIncludes(sql, "on conflict (app_id, slug) do update set");
  assertStringIncludes(sql, "returning id into col_id");
  // Entries upsert, referencing the captured id
  assertStringIncludes(sql, "insert into content.hadith_entries");
  assertStringIncludes(sql, "(col_id, 1,");
  assertStringIncludes(sql, "on conflict (app_id, collection_id, number) do update set");
  // Wrapped in a DO block so col_id is in scope
  assertStringIncludes(sql, "do $$");
  assertStringIncludes(sql, "end $$;");
});

Deno.test("buildSql respects the published flag (default false)", () => {
  assertStringIncludes(buildSql(SAMPLE), ", false)"); // collection row ends unpublished
  const published = buildSql(SAMPLE, { published: true });
  assertStringIncludes(published, ", true)");
  assert(!published.includes(", false)"));
});

Deno.test("buildSql chunks large entry sets into multiple inserts", () => {
  const many: HadithDataset = {
    collection: SAMPLE.collection,
    entries: Array.from({ length: 1200 }, (_, i) => ({ number: i + 1, arabic: `نص ${i + 1}` })),
  };
  const sql = buildSql(many, { chunkSize: 500 });
  // 1200 / 500 -> 3 insert statements
  const inserts = sql.match(/insert into content\.hadith_entries/g) ?? [];
  assertEquals(inserts.length, 3);
  assertStringIncludes(sql, "نص 1200");
});

Deno.test("fromFawazEdition merges the English edition as translation, keeps grades", () => {
  const ds = fromFawazEdition(
    "bukhari",
    { ar: "صحيح البخاري", en: "Sahih al-Bukhari" },
    {
      hadiths: [
        { hadithnumber: 1, text: "إنما الأعمال بالنيات", grades: [{ grade: "Sahih" }] },
        { hadithnumber: 2, text: "  ", grades: [] }, // skipped: empty arabic
      ],
    },
    { hadiths: [{ hadithnumber: 1, text: "Actions are by intentions" }] },
    { sortOrder: 1 },
  );
  assertEquals(ds.collection.slug, "bukhari");
  assertEquals(ds.entries.length, 1); // the blank one is dropped
  assertEquals(ds.entries[0].number, 1);
  assertEquals(ds.entries[0].translation, { en: "Actions are by intentions" });
  assertEquals(ds.entries[0].grading, "Sahih");
  // Output of the adapter validates cleanly.
  assertEquals(validate(ds), []);
});
