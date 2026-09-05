import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { buildMigration, validate } from "../scripts/import_hadith_translations.ts";

Deno.test("accepts a well-formed file", () => {
  const { rows, errors } = validate([
    { slug: "bulugh_almaram", number: 1, text: "Actions are but by intentions." },
  ]);
  assertEquals(errors, []);
  assertEquals(rows.length, 1);
});

Deno.test("rejects a duplicate entry rather than silently taking one", () => {
  const { errors } = validate([
    { slug: "bulugh_almaram", number: 5, text: "first" },
    { slug: "bulugh_almaram", number: 5, text: "second" },
  ]);
  assertEquals(errors.length, 1);
  assertStringIncludes(errors[0], "duplicate");
});

Deno.test("rejects empty text — a blank translation is worse than none", () => {
  const { errors } = validate([{ slug: "bulugh_almaram", number: 2, text: "   " }]);
  assertEquals(errors.length, 1);
  assertStringIncludes(errors[0], "empty text");
});

Deno.test("rejects a bad slug or number instead of guessing", () => {
  const { errors } = validate([
    { slug: "Bulugh Al Maram!", number: 1, text: "x" },
    { slug: "bulugh_almaram", number: 0, text: "x" },
    { slug: "bulugh_almaram", number: 1.5, text: "x" },
  ]);
  assertEquals(errors.length, 3);
});

Deno.test("keys on slug and number, never on entry id", () => {
  // 0029 shipped an id-keyed migration that updated zero rows on any database
  // other than the one it was generated from. This pins the lesson.
  const sql = buildMigration(
    [{ slug: "bulugh_almaram", number: 1, text: "x" }],
    "en",
  );
  assertStringIncludes(sql, "e.number = v.number");
  assertStringIncludes(sql, "c.slug = v.slug");
  assertEquals(sql.includes("::uuid"), false);
});

Deno.test("merges the locale instead of replacing the column", () => {
  const sql = buildMigration([{ slug: "x_y", number: 1, text: "t" }], "en");
  // `||` merge: importing English must not drop a translation in another language.
  assertStringIncludes(sql, "|| jsonb_build_object('en'");
  assertStringIncludes(sql, "coalesce(e.translation_translations, '{}'::jsonb)");
});

Deno.test("escapes quotes in the translated text", () => {
  const sql = buildMigration(
    [{ slug: "x_y", number: 1, text: "the Prophet's words" }],
    "en",
  );
  assertStringIncludes(sql, "'the Prophet''s words'");
});
