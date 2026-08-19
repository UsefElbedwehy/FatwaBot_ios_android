import { assert, assertEquals, assertStringIncludes, assertThrows } from "jsr:@std/assert@1";
import {
  AWRAD_VERSION,
  buildSql,
  TEMPLATES,
  toBundledJson,
  validate,
  type WirdTemplateInput,
} from "../scripts/build_awrad.ts";
import { deterministicUuid } from "../scripts/import_common.ts";

Deno.test("the curated set is valid and uses only app-understood vocabulary", () => {
  assertEquals(validate(TEMPLATES), []);
  // frequency must stay daily (the only cadence the apps drive)
  assert(TEMPLATES.every((t) => t.frequency === "daily"), "all templates must be daily");
  // exactly the two special tokens exist somewhere so the stat wiring is exercised
  assert(TEMPLATES.some((t) => t.type === "salawat"), "expected a salawat template");
  assert(TEMPLATES.some((t) => t.unit === "pages"), "expected a Qur'an-pages template");
  // no duplicate slugs
  assertEquals(new Set(TEMPLATES.map((t) => t.slug)).size, TEMPLATES.length);
});

Deno.test("validate rejects bad templates", () => {
  assert(validate([]).length > 0);
  assert(validate([{ slug: "BAD X", type: "dhikr", target: 1, unit: "times", frequency: "daily", name: { ar: "س" }, description: {} }]).some((e) => e.includes("slug")));
  assert(validate([{ slug: "x", type: "dhikr", target: 0, unit: "times", frequency: "daily", name: { ar: "س" }, description: {} }]).some((e) => e.includes("target")));
  assert(validate([{ slug: "x", type: "dhikr", target: 1, unit: "times", frequency: "daily", name: { en: "no arabic" }, description: {} }]).some((e) => e.includes("name.ar")));
});

Deno.test("buildSql is idempotent (upsert on the primary key) and bumps version", () => {
  const sql = buildSql(TEMPLATES);
  assertStringIncludes(sql, "insert into content.wird_templates");
  assertStringIncludes(sql, "on conflict (id) do update set");
  assertStringIncludes(sql, "version = excluded.version");
  // explicit deterministic id (matches the bundle) rather than gen_random_uuid
  assertStringIncludes(sql, `'${deterministicUuid("wird:salawat")}'`);
  // published + version 2 present
  assertStringIncludes(sql, `, ${AWRAD_VERSION}, true)`);
});

Deno.test("buildSql throws on invalid input rather than emitting broken SQL", () => {
  assertThrows(() => buildSql([] as WirdTemplateInput[]), Error, "Invalid awrad templates");
});

Deno.test("toBundledJson matches the WirdTemplatesCollection API shape and localises", () => {
  const ar = toBundledJson(TEMPLATES, "ar") as { version: number; templates: Array<Record<string, unknown>> };
  assertEquals(ar.version, AWRAD_VERSION);
  const salawat = ar.templates.find((t) => t.type === "salawat")!;
  assertEquals(salawat.defaultTarget, 100);
  assertEquals(salawat.defaultUnit, "times");
  assertEquals(salawat.defaultFrequency, "daily");
  assertEquals(salawat.name, "الصلاة على النبي ﷺ");
  const en = toBundledJson(TEMPLATES, "en") as { templates: Array<Record<string, unknown>> };
  const salawatEn = en.templates.find((t) => t.type === "salawat")!;
  assertEquals(salawatEn.name, "Salawat upon the Prophet ﷺ");
  // ids stable + identical across locales (so bundle ↔ API and ar/en stay aligned)
  assertEquals(salawat.id, salawatEn.id);
  assertEquals(salawat.id, deterministicUuid("wird:salawat"));
});
