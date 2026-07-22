import { assert, assertEquals, assertStringIncludes, assertThrows } from "jsr:@std/assert@1";
import {
  buildSql,
  collectionsIndex,
  type FawazEdition,
  fromFawazEdition,
  type HadithDataset,
  jsonbLiteral,
  sqlString,
  toBundledJson,
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
  // Wrapped in a DO block (tagged $fb$, not $$, so matn containing "$$" is safe)
  assertStringIncludes(sql, "do $fb$");
  assertStringIncludes(sql, "end $fb$;");
});

Deno.test("buildSql uses a $fb$ dollar-quote so matn containing '$$' can't close the block early", () => {
  const withDollars: HadithDataset = {
    collection: { slug: "x", name: { ar: "س" } },
    entries: [{ number: 1, arabic: "نص فيه $$ علامة" }],
  };
  const sql = buildSql(withDollars);
  assert(!sql.includes("do $$"), "must not use the bare $$ tag");
  assertStringIncludes(sql, "نص فيه $$ علامة"); // the literal $$ survives inside the block
});

Deno.test("buildSql respects the published flag (default false)", () => {
  assertStringIncludes(buildSql(SAMPLE), ", false)"); // collection row ends unpublished
  const published = buildSql(SAMPLE, { published: true });
  assertStringIncludes(published, ", true)");
  assert(!published.includes(", false)"));
});

Deno.test("buildSql records provenance in source_dataset (both the row and the do-update-set)", () => {
  const sql = buildSql(SAMPLE, { sourceDataset: "fawazahmed0 ara-bukhari" });
  assertStringIncludes(sql, "source_dataset");
  assertStringIncludes(sql, "'fawazahmed0 ara-bukhari'");
  assertStringIncludes(sql, "source_dataset = excluded.source_dataset"); // carried on re-import
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

Deno.test("fromFawazEdition keys on the integer hadithnumber (drops fractional + duplicate variants)", () => {
  const edition: FawazEdition = {
    hadiths: [
      { hadithnumber: 402, text: "الحديث الأصلي" },
      { hadithnumber: 402.2, text: "رواية ثانية" }, // fractional secondary narration -> skipped
      { hadithnumber: 403, text: "حديث آخر" },
      { hadithnumber: 403, text: "مكرر" }, // duplicate integer number -> skipped
    ],
  };
  const ds = fromFawazEdition("bukhari", { ar: "صحيح البخاري" }, edition);
  assertEquals(ds.entries.map((e) => e.number), [402, 403]);
  assertEquals(ds.entries[0].arabic, "الحديث الأصلي"); // the primary narration is kept
  assertEquals(validate(ds), []);
});

Deno.test("published rows carry an approved review state (satisfies the 0014 constraint)", () => {
  // Unpublished import stays pending, no reviewer.
  const pending = buildSql(SAMPLE);
  assertStringIncludes(pending, "'pending', null, null, false)");
  // Publishing must stamp approved + reviewer, else the check constraint rejects it.
  const live = buildSql(SAMPLE, { published: true });
  assertStringIncludes(live, "'approved', 'auto:trusted-import', now(), true)");
  assertStringIncludes(live, "review_status = excluded.review_status");
  // An explicit reviewer overrides the default.
  const custom = buildSql(SAMPLE, { published: true, reviewedBy: "sheikh-x" });
  assertStringIncludes(custom, "'approved', 'sheikh-x', now(), true)");
});

Deno.test("toBundledJson matches the app's hadith detail shape and localises", () => {
  const ar = toBundledJson(SAMPLE, "ar") as {
    version: number;
    slug: string;
    name: string;
    entries: Array<Record<string, unknown>>;
  };
  assertEquals(ar.version, 1);
  assertEquals(ar.slug, "nawawi40");
  assertEquals(ar.name, "الأربعون النووية");
  assertEquals(ar.entries[0].number, 1);
  assertEquals(ar.entries[0].arabicText, "إنما الأعمال بالنيّات");
  assertEquals(ar.entries[0].translation, "Actions are by intentions"); // en fallback
  assertEquals(ar.entries[1].translation, null); // no translation -> null, not ""
  assertEquals(ar.entries[0].benefitNote, null); // matn-only import

  const en = toBundledJson(SAMPLE, "en") as { name: string; entries: Array<Record<string, unknown>> };
  assertEquals(en.name, "The Forty Hadith");
  // Ids are stable + identical across locales so ar/en stay aligned.
  assertEquals((ar.entries[0] as Record<string, unknown>).id, en.entries[0].id);
});

Deno.test("collectionsIndex summarises every collection with a stable id + entryCount", () => {
  const other: HadithDataset = {
    collection: { slug: "qudsi40", name: { ar: "الأربعون القدسية", en: "Forty Hadith Qudsi" } },
    entries: [{ number: 1, arabic: "نص" }],
  };
  const idx = collectionsIndex([SAMPLE, other], "en") as {
    collections: Array<Record<string, unknown>>;
  };
  assertEquals(idx.collections.length, 2);
  assertEquals(idx.collections[0].slug, "nawawi40");
  assertEquals(idx.collections[0].name, "The Forty Hadith");
  assertEquals(idx.collections[0].entryCount, 2);
  assertEquals(idx.collections[1].entryCount, 1);
  // Index id for a collection matches the detail file's id for the same slug.
  const detail = toBundledJson(SAMPLE, "en") as Record<string, unknown>;
  // detail has no top-level id; index id is derived from slug — assert it's UUID-shaped + stable
  assert(/^[0-9a-f-]{36}$/.test(idx.collections[0].id as string));
  assertEquals(idx.collections[0].id, (collectionsIndex([SAMPLE], "ar") as { collections: Array<Record<string, unknown>> }).collections[0].id);
  void detail;
});
