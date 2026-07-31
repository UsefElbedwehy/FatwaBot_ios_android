// Extracts the takhrij / grading clause out of a hadith's matn into the
// structured `grading` column (docs/features/hadith-import.md).
//
// ## Why this is extraction and not authorship
// In بلوغ المرام the grading is already *in* the text — ibn Hajr closes each
// hadith with who narrated it and how it was judged ("أخرجه الأربعة... وصححه ابن
// خزيمة"). The import kept the matn verbatim and left `grading` empty, so the
// information exists but cannot be displayed, filtered or searched separately.
// This lifts a copy of that clause into its own field.
//
// ## Two rules that matter more than coverage
//  1. `arabic_text` is NEVER modified. The clause is copied, not moved: the
//     matn as printed includes its takhrij, and mutating scripture-adjacent text
//     to populate a convenience field is not a trade worth making. A wrong
//     extraction is then cosmetic, never destructive.
//  2. When the shape is not clearly a takhrij, the result is empty. An empty
//     grading is honest; a confidently wrong one attributes a ruling to ibn
//     Hajr that he did not make.
//
// Exported pure for testing; the CLI at the bottom runs only when executed
// directly, matching hadith_import.ts.

/** Openers of a takhrij clause, matched on diacritic-stripped text. */
const OPENERS =
  /(متفق علي|رواه|رواها|رواهما|اخرجه|اخرجها|اخرجاه|اخرجهما)/g;

/**
 * Sentence openers that *continue* a takhrij once one has started — a verdict,
 * a wording note, an isnad remark. Anything else ends the clause, which is what
 * keeps ibn Hajr's commentary ("وهو أقوى من حديث وائل") out of the field.
 */
const CONTINUATIONS = [
  "وصححه",
  "وصححها",
  "وصححاه",
  "وضعفه",
  "وحسنه",
  "واللفظ",
  "وهو حسن",
  "وهو صحيح",
  "وهو موقوف",
  "واسناده",
  "ورجاله",
  "وفي اسناده",
  "واخرجه",
  "ورواه",
  "وقال",
];

const FOLD: Record<string, string> = { "أ": "ا", "إ": "ا", "آ": "ا", "ى": "ي" };

/**
 * Diacritic-stripped text plus, for each output character, its index in the
 * input.
 *
 * The map is the whole point: stripping combining marks changes the string's
 * length, so a match offset in the normalized text does not address the same
 * character in the original. Slicing the original with a normalized offset
 * silently cuts mid-word — it looks plausible and is wrong.
 */
export function normalizeWithMap(text: string): { normalized: string; map: number[] } {
  const out: string[] = [];
  const map: number[] = [];
  for (let i = 0; i < text.length; i++) {
    const decomposed = text[i].normalize("NFD");
    for (const ch of decomposed) {
      // Combining marks (harakat) carry no matching value and are dropped.
      if (/\p{M}/u.test(ch)) continue;
      const folded = FOLD[ch] ?? ch;
      out.push(folded);
      map.push(i);
    }
  }
  return { normalized: out.join(""), map };
}

function startsWithTakhrij(sentence: string): boolean {
  const { normalized } = normalizeWithMap(sentence);
  const trimmed = normalized.replace(/^[«»\s]+/, "");
  if (CONTINUATIONS.some((c) => trimmed.startsWith(c))) return true;
  return new RegExp(`^(${OPENERS.source.slice(1, -1)})`).test(trimmed);
}

/**
 * Returns the takhrij clause found at the end of `matn`, or "" when there is
 * none to extract.
 *
 * Anchors on the **last** opener rather than the first: a hadith body can
 * mention a narration mid-text, and only the closing attribution is the ruling
 * on this hadith.
 */
/**
 * Rejects clauses that look like an attribution but are not one.
 *
 * Both rules were derived from real misfires over the 1,978-entry corpus, and
 * both fire on exactly one entry each with no false rejections:
 *
 *  - An unbalanced closing quote means the anchor landed *inside* the matn's
 *    quotation. العمدة 173 ends "...فَلَا أَزَالُ أُخْرِجُهُ كَمَا كُنْتُ أُخْرِجُهُ »" —
 *    أخرجه there is Abu Sa'id's verb, not a takhrij. A takhrij that legitimately
 *    quotes an alternate wording («...») has its quotes balanced.
 *  - A colon *immediately* after رواه introduces the companions who narrated it,
 *    not the collectors who recorded it: العمدة 191 reads
 *    "رَوَاهُ: أَبُو هُرَيْرَةَ، وَعَائِشَةُ، وَأَنَسُ بْنُ مَالِكٍ". A real takhrij names its
 *    collector first ("رَوَاهُ الْبَيْهَقِيُّ: عَنْ عَلِيٍّ..."), so the colon never comes first.
 */
function isFalsePositive(clause: string): boolean {
  const closing = (clause.match(/»/g) ?? []).length;
  const opening = (clause.match(/«/g) ?? []).length;
  if (closing > opening) return true;

  const { normalized } = normalizeWithMap(clause);
  return /^(رواه|رواها|رواهما)\s*:/.test(normalized.replace(/^[«»\s]+/, ""));
}

export function extractGrading(matn: string): string {
  const text = matn.split(/\s+/).join(" ").trim();
  const { normalized, map } = normalizeWithMap(text);

  const matches = [...normalized.matchAll(OPENERS)];
  if (matches.length === 0) return "";
  const start = map[matches[matches.length - 1].index!];

  const tail = text.slice(start);
  const sentences = tail.split(/(?<=\.)\s+/).filter((s) => s.trim().length > 0);
  if (sentences.length === 0) return "";

  const kept = [sentences[0]];
  for (const sentence of sentences.slice(1)) {
    if (!startsWithTakhrij(sentence)) break;
    kept.push(sentence);
  }
  const clause = kept.join(" ").trim();
  return isFalsePositive(clause) ? "" : clause;
}

// MARK: - CLI

if (import.meta.main) {
  const [entriesPath] = Deno.args;
  if (!entriesPath) {
    console.error("usage: extract_hadith_grading.ts <entries.json>");
    Deno.exit(2);
  }
  const entries = JSON.parse(await Deno.readTextFile(entriesPath)) as Array<
    { id: string; number: number; arabicText: string }
  >;

  const updates: string[] = [];
  for (const e of entries) {
    const grading = extractGrading(e.arabicText);
    if (!grading) continue;
    updates.push(
      `  ('${e.id}'::uuid, '${grading.replaceAll("'", "''")}')`,
    );
  }
  console.error(`extracted ${updates.length}/${entries.length}`);
  console.log(updates.join(",\n"));
}
