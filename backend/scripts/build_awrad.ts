// Awrad (wird templates) curation (docs/features/awrad.md). Unlike azkar/dua/
// hadith there is no public dataset — wird templates are a small, hand-curated
// starter set of well-known daily awrad. This script holds that set and emits
// both the idempotent seed SQL and the apps' bundled offline JSON, so the two
// stay in lockstep (same deterministic ids).
//
// App semantics that constrain the vocabulary (see AwradFeature / :feature:awrad):
//   - unit "pages"  → counts toward the Qur'an-pages stat
//   - type "salawat" → counts toward the salawat stat
//   - everything else is passthrough display; frequency is always "daily".
// Templates are grouped by `type` in the picker, so we use a few meaningful
// types (salawat / dhikr / quran_reading) rather than a unique type each.

import {
  deterministicUuid,
  generatedHeader,
  jsonbLiteral,
  resolveLocale,
  sqlString,
  type Translations,
} from "./import_common.ts";

export interface WirdTemplateInput {
  slug: string;
  type: string;
  target: number;
  unit: string;
  frequency: string;
  name: Translations;
  description: Translations;
}

// Bumped from the original 3-template v1 seed so existing installs (which cached
// or bundled v1) re-sync instead of getting "up to date".
export const AWRAD_VERSION = 2;

// The curated set. Virtues in the descriptions are from well-known authentic
// reports (Bukhari/Muslim unless noted); descriptions are practice guidance, not
// hadith matn.
export const TEMPLATES: WirdTemplateInput[] = [
  {
    slug: "salawat",
    type: "salawat",
    target: 100,
    unit: "times",
    frequency: "daily",
    name: { ar: "الصلاة على النبي ﷺ", en: "Salawat upon the Prophet ﷺ" },
    description: {
      ar: "«من صلى عليَّ صلاةً صلى الله عليه بها عشراً». وِرد يومي مئة مرة.",
      en: "“Whoever sends blessings upon me once, Allah sends ten upon him.” A daily wird of 100.",
    },
  },
  {
    slug: "istighfar",
    type: "dhikr",
    target: 100,
    unit: "times",
    frequency: "daily",
    name: { ar: "أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ", en: "Istighfar — Seeking Forgiveness" },
    description: {
      ar: "كان النبي ﷺ يستغفر الله في اليوم أكثر من سبعين مرة. وِرد مئة مرة.",
      en: "The Prophet ﷺ sought Allah's forgiveness more than seventy times a day. A wird of 100.",
    },
  },
  {
    slug: "tasbih-hamd",
    type: "dhikr",
    target: 100,
    unit: "times",
    frequency: "daily",
    name: { ar: "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ", en: "Subhan Allah wa bi-hamdihi" },
    description: {
      ar: "«من قالها مئة مرة في اليوم حُطَّت خطاياه وإن كانت مثل زبد البحر». رواه مسلم.",
      en:
        "“Whoever says it 100 times a day, his sins are wiped away even if like the foam of the sea.” (Muslim)",
    },
  },
  {
    slug: "tahlil",
    type: "dhikr",
    target: 100,
    unit: "times",
    frequency: "daily",
    name: { ar: "لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ", en: "Tahlil — Declaring Allah's Oneness" },
    description: {
      ar: "قولها مئة مرة تعدل عتق عشر رقاب، وتُكتب مئة حسنة، وتُمحى مئة سيئة. متفق عليه.",
      en:
        "Said 100 times: equals freeing ten slaves, a hundred good deeds recorded, a hundred sins erased. (Bukhari & Muslim)",
    },
  },
  {
    slug: "two-phrases",
    type: "dhikr",
    target: 100,
    unit: "times",
    frequency: "daily",
    name: { ar: "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ", en: "Two phrases beloved to the Most Merciful" },
    description: {
      ar: "«كلمتان خفيفتان على اللسان، ثقيلتان في الميزان، حبيبتان إلى الرحمن». متفق عليه.",
      en:
        "“Two phrases light on the tongue, heavy on the scale, beloved to the Most Merciful.” (Bukhari & Muslim)",
    },
  },
  {
    slug: "hawqala",
    type: "dhikr",
    target: 100,
    unit: "times",
    frequency: "daily",
    name: { ar: "لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ", en: "La hawla wa la quwwata illa billah" },
    description: {
      ar: "«كنزٌ من كنوز الجنة». متفق عليه. وِرد يومي.",
      en: "“A treasure from the treasures of Paradise.” (Bukhari & Muslim) A daily wird.",
    },
  },
  {
    slug: "quran-daily",
    type: "quran_reading",
    target: 5,
    unit: "pages",
    frequency: "daily",
    name: { ar: "وِرد القرآن اليومي", en: "Daily Qur'an Reading" },
    description: {
      ar: "خمس صفحات كل يوم للمداومة على تلاوة القرآن.",
      en: "Five pages each day to keep a steady share of the Qur'an.",
    },
  },
  {
    slug: "quran-juz",
    type: "quran_reading",
    target: 20,
    unit: "pages",
    frequency: "daily",
    name: { ar: "جزء من القرآن يومياً", en: "One Juz' a Day" },
    description: {
      ar: "جزء (نحو عشرين صفحة) يومياً لختم القرآن في شهر.",
      en: "About twenty pages daily — a complete Qur'an in a month.",
    },
  },
  {
    slug: "surah-mulk",
    type: "quran_reading",
    target: 1,
    unit: "times",
    frequency: "daily",
    name: { ar: "تلاوة سورة الملك", en: "Recite Surah al-Mulk" },
    description: {
      ar: "سورة تشفع لصاحبها حتى يُغفر له، تُقرأ كل ليلة.",
      en: "A surah that intercedes for its reciter until he is forgiven; read each night.",
    },
  },
];

const SLUG_RE = /^[a-z0-9_-]{1,40}$/;

export function validate(templates: WirdTemplateInput[]): string[] {
  const errors: string[] = [];
  if (!Array.isArray(templates) || templates.length === 0) return ["templates must be a non-empty array"];
  const slugs = new Set<string>();
  for (const [i, t] of templates.entries()) {
    if (typeof t.slug !== "string" || !SLUG_RE.test(t.slug)) {
      errors.push(`templates[${i}].slug must match ${SLUG_RE}`);
    } else if (slugs.has(t.slug)) errors.push(`templates[${i}].slug '${t.slug}' is duplicated`);
    else slugs.add(t.slug);
    if (!t.name || typeof t.name.ar !== "string" || t.name.ar.trim() === "") {
      errors.push(`templates[${i}].name.ar is required`);
    }
    if (typeof t.type !== "string" || t.type.trim() === "") errors.push(`templates[${i}].type is required`);
    if (!Number.isInteger(t.target) || t.target < 1) {
      errors.push(`templates[${i}].target must be a positive integer`);
    }
    if (typeof t.unit !== "string" || t.unit.trim() === "") errors.push(`templates[${i}].unit is required`);
    if (typeof t.frequency !== "string" || t.frequency.trim() === "") {
      errors.push(`templates[${i}].frequency is required`);
    }
  }
  return errors;
}

/** Idempotent seed SQL. wird_templates has no natural key, so we insert explicit
 * deterministic ids and upsert on the primary key — re-running updates in place
 * and never duplicates, and the ids match the bundled JSON. */
export function buildSql(templates: WirdTemplateInput[], version = AWRAD_VERSION): string {
  const errors = validate(templates);
  if (errors.length > 0) throw new Error(`Invalid awrad templates:\n - ${errors.join("\n - ")}`);
  const rows = templates.map((t, i) =>
    "  (" +
    [
      sqlString(deterministicUuid(`wird:${t.slug}`)),
      jsonbLiteral(t.name),
      jsonbLiteral(t.description),
      sqlString(t.type),
      String(t.target),
      sqlString(t.unit),
      sqlString(t.frequency),
      String(i),
      String(version),
      "true",
    ].join(", ") + ")"
  ).join(",\n");

  return generatedHeader(`Awrad: ${templates.length} wird templates, version=${version}`) +
    `\ninsert into content.wird_templates
  (id, name_translations, description_translations, type, default_target, default_unit, default_frequency, sort_order, version, published)
values
${rows}
on conflict (id) do update set
  name_translations = excluded.name_translations,
  description_translations = excluded.description_translations,
  type = excluded.type,
  default_target = excluded.default_target,
  default_unit = excluded.default_unit,
  default_frequency = excluded.default_frequency,
  sort_order = excluded.sort_order,
  version = excluded.version,
  published = excluded.published,
  updated_at = now();
`;
}

/** The apps' bundled offline JSON for one locale (resolved single-locale strings,
 * matching the WirdTemplatesCollection API shape). */
export function toBundledJson(
  templates: WirdTemplateInput[],
  locale: string,
  version = AWRAD_VERSION,
): unknown {
  return {
    version,
    templates: templates.map((t) => ({
      id: deterministicUuid(`wird:${t.slug}`),
      type: t.type,
      defaultTarget: t.target,
      defaultUnit: t.unit,
      defaultFrequency: t.frequency,
      name: resolveLocale(t.name, locale),
      description: resolveLocale(t.description, locale),
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
  const sqlOut = get("--sql");
  if (sqlOut) {
    await Deno.writeTextFile(sqlOut, buildSql(TEMPLATES));
    console.error(`Wrote SQL → ${sqlOut} (${TEMPLATES.length} templates, v${AWRAD_VERSION})`);
  }
  const bundledDir = get("--bundled-dir");
  if (bundledDir) {
    for (const locale of ["ar", "en"]) {
      const path = `${bundledDir}/wird-templates.${locale}.json`;
      await Deno.writeTextFile(path, JSON.stringify(toBundledJson(TEMPLATES, locale), null, 2) + "\n");
      console.error(`Wrote bundled → ${path}`);
    }
  }
  if (!sqlOut && !bundledDir) {
    console.error("Usage: deno run -A scripts/build_awrad.ts [--sql <out.sql>] [--bundled-dir <dir>]");
  }
}
