// Driver: builds the full hadith dataset (docs/features/hadith-import.md) from a
// directory of fawazahmed0/hadith-api Arabic editions (ara-<book>.json).
//
// Emits, for every collection:
//   - <sql-dir>/hadith_<slug>.sql  (Arabic matn + gradings, published+approved as
//     a trusted import — see the review model in content-verification.md)
// and, for the compact BUNDLED collections + the shared catalogue index:
//   - <bundled-dir>/hadith-<slug>.{ar,en}.json
//   - <bundled-dir>/hadith-collections.{ar,en}.json   (ALL collections)
//
// We import the Arabic matn only: the classical matn is public domain, whereas
// the aggregator's English translations have uncertain licensing — so
// `translation` stays null until a reviewed English pass. Large collections are
// catalogued in the index but not bundled (the app fetches their detail on
// demand via sync); the two compact classics are bundled for full offline use.

import {
  buildSql,
  collectionsIndex,
  type FawazEdition,
  fromFawazEdition,
  type HadithDataset,
  toBundledJson,
  type Translations,
} from "./hadith_import.ts";

interface CollectionSpec {
  slug: string;
  edition: string; // fawaz edition file basename, e.g. "ara-bukhari"
  name: Translations;
  description: Translations;
  /** Bundle the full detail offline? (compact classics only.) */
  bundled: boolean;
}

// Order here is the catalogue order (sort_order) the app shows.
const COLLECTIONS: CollectionSpec[] = [
  {
    slug: "nawawi40",
    edition: "ara-nawawi",
    name: { ar: "الأربعون النووية", en: "Forty Hadith of an-Nawawi" },
    description: {
      ar: "أربعون حديثاً جامعة لأصول الدين اختارها الإمام النووي",
      en: "Forty foundational hadith on the essentials of the religion, compiled by Imam an-Nawawi",
    },
    bundled: true,
  },
  {
    slug: "qudsi40",
    edition: "ara-qudsi",
    name: { ar: "الأربعون القدسية", en: "Forty Hadith Qudsi" },
    description: {
      ar: "أربعون حديثاً قدسياً مما رواه النبي ﷺ عن ربه",
      en: "Forty sacred (qudsi) hadith the Prophet ﷺ related from his Lord",
    },
    bundled: true,
  },
  {
    slug: "bukhari",
    edition: "ara-bukhari",
    name: { ar: "صحيح البخاري", en: "Sahih al-Bukhari" },
    description: {
      ar: "الجامع المسند الصحيح المختصر للإمام محمد بن إسماعيل البخاري",
      en: "The rigorously authentic collection of Imam Muhammad al-Bukhari",
    },
    bundled: false,
  },
  {
    slug: "muslim",
    edition: "ara-muslim",
    name: { ar: "صحيح مسلم", en: "Sahih Muslim" },
    description: {
      ar: "المسند الصحيح للإمام مسلم بن الحجاج النيسابوري",
      en: "The authentic collection of Imam Muslim ibn al-Hajjaj",
    },
    bundled: false,
  },
  {
    slug: "abudawud",
    edition: "ara-abudawud",
    name: { ar: "سنن أبي داود", en: "Sunan Abu Dawud" },
    description: {
      ar: "سنن الإمام أبي داود سليمان بن الأشعث السجستاني",
      en: "The Sunan of Imam Abu Dawud as-Sijistani",
    },
    bundled: false,
  },
  {
    slug: "tirmidhi",
    edition: "ara-tirmidhi",
    name: { ar: "جامع الترمذي", en: "Jami' at-Tirmidhi" },
    description: {
      ar: "الجامع للإمام أبي عيسى محمد بن عيسى الترمذي",
      en: "The Jami' of Imam Abu 'Isa at-Tirmidhi",
    },
    bundled: false,
  },
  {
    slug: "nasai",
    edition: "ara-nasai",
    name: { ar: "سنن النسائي", en: "Sunan an-Nasa'i" },
    description: {
      ar: "السنن الصغرى (المجتبى) للإمام أحمد بن شعيب النسائي",
      en: "As-Sunan as-Sughra (al-Mujtaba) of Imam an-Nasa'i",
    },
    bundled: false,
  },
  {
    slug: "ibnmajah",
    edition: "ara-ibnmajah",
    name: { ar: "سنن ابن ماجه", en: "Sunan Ibn Majah" },
    description: {
      ar: "سنن الإمام أبي عبد الله محمد بن يزيد ابن ماجه القزويني",
      en: "The Sunan of Imam Ibn Majah al-Qazwini",
    },
    bundled: false,
  },
];

const LOCALES = ["ar", "en"];

function get(flag: string): string | undefined {
  const i = Deno.args.indexOf(flag);
  return i >= 0 ? Deno.args[i + 1] : undefined;
}

if (import.meta.main) {
  const editionsDir = get("--editions-dir");
  const sqlDir = get("--sql-dir");
  const bundledDir = get("--bundled-dir");
  if (!editionsDir) {
    console.error(
      "Usage: deno run -A scripts/build_hadith.ts --editions-dir <dir> [--sql-dir <dir>] [--bundled-dir <dir>]\n" +
        "  <dir> holds fawazahmed0 Arabic editions named ara-<book>.json.",
    );
    Deno.exit(1);
  }

  const datasets: HadithDataset[] = [];
  for (const [i, spec] of COLLECTIONS.entries()) {
    const edition = JSON.parse(
      await Deno.readTextFile(`${editionsDir}/${spec.edition}.json`),
    ) as FawazEdition;
    const ds = fromFawazEdition(spec.slug, spec.name, edition, undefined, {
      description: spec.description,
      sortOrder: i,
    });
    datasets.push(ds);

    const rawCount = edition.hadiths?.length ?? 0;
    const skipped = rawCount - ds.entries.length;
    if (skipped > 0) {
      console.error(`  ${spec.slug}: skipped ${skipped} fractional/duplicate narration(s) of ${rawCount}`);
    }

    if (sqlDir) {
      const sql = buildSql(ds, {
        published: true,
        sourceDataset: `fawazahmed0 hadith-api (${spec.edition}) — Arabic matn`,
      });
      await Deno.writeTextFile(`${sqlDir}/hadith_${spec.slug}.sql`, sql);
      console.error(`SQL  → hadith_${spec.slug}.sql (${ds.entries.length} entries)`);
    }

    if (bundledDir && spec.bundled) {
      for (const locale of LOCALES) {
        const path = `${bundledDir}/hadith-${spec.slug}.${locale}.json`;
        await Deno.writeTextFile(path, JSON.stringify(toBundledJson(ds, locale), null, 2) + "\n");
        console.error(`JSON → hadith-${spec.slug}.${locale}.json`);
      }
    }
  }

  if (bundledDir) {
    for (const locale of LOCALES) {
      const path = `${bundledDir}/hadith-collections.${locale}.json`;
      await Deno.writeTextFile(path, JSON.stringify(collectionsIndex(datasets, locale), null, 2) + "\n");
      console.error(`JSON → hadith-collections.${locale}.json (${datasets.length} collections)`);
    }
  }

  const total = datasets.reduce((n, d) => n + d.entries.length, 0);
  console.error(`\nDone: ${datasets.length} collections, ${total} hadith total.`);
}
