// Citation verification (docs/features/ai-search-m5.0-spec.md §Citation
// verification) — the enforcement half of "no fabrication". Every
// AnswerProvider citation's quotedText must be a normalized substring of the
// real fatwa.chunks.text it claims to quote. This is checked here, in code,
// not left to the model to have followed the prompt — a citation that fails
// is dropped, and if it was the answer's only support, the whole response
// flips to a refusal rather than shipping an unverifiable claim.
//
// Since 0050 a quote that is *nearly* a substring is repaired rather than
// dropped: see `repairQuote`. The corpus is OCR'd text with roughly one error
// per line, and a model told to copy verbatim will silently correct «محرعٌ» to
// «محرم» — an exact-substring gate then rejected honest citations by the
// dozen, and each rejection of a sole citation was a refusal the user saw.
import type { AnswerResult, HadithVerdict, RetrievedChunk } from "../fatwa_types.ts";
import { normalizeArabic } from "./text_normalize.ts";

/** The takhrij card from a content.search_hadith row (0050), whose text is
 *  the matn followed by «الدرجة: …» and «المصدر: …» lines. Null for anything
 *  else — a fatwa chunk that mentions a hadith is commentary, not an entry. */
export function hadithFromChunk(chunk: RetrievedChunk): HadithVerdict | null {
  if (chunk.sourceCategory !== "hadith") return null;
  const grade = /^الدرجة: (.+)$/mu.exec(chunk.text)?.[1]?.trim();
  const source = /^المصدر: (.+)$/mu.exec(chunk.text)?.[1]?.trim();
  const text = chunk.text.split(/\n\nالدرجة: /u)[0].trim();
  if (!grade || text.length === 0) return null;
  return { text, grade, ...(source ? { source } : {}) };
}

export interface VerifiedAnswer extends AnswerResult {
  /** Citations the model produced that failed verification (missing chunk,
   *  or quotedText not actually found in that chunk's text) — surfaced for
   *  logging/QA, never shown to the user. */
  droppedCitations: AnswerResult["citations"];
  /** How many surviving citations had their quote replaced by the longest
   *  run of the chunk they actually match. Logged, so the repair rate is
   *  visible; a rising number says the prompt's "copy verbatim" is slipping. */
  repairedCitations: number;
}

/** A repaired quote must be at least this many words and cover at least this
 *  share of the model's quote. The floor is what makes repair safe: six
 *  consecutive words each within one edit of the source, in order, cannot be
 *  produced by fabrication — only by reading the chunk. The share stops a
 *  long invented quote riding on a short genuine fragment inside it.
 *
 *  Six, not more: measured on the dropped citations of the first 0050 run,
 *  the longest *exact* run between an honest quote and its OCR'd source was
 *  4-5 words, because the scan carries an error roughly every fifth word
 *  (خلق for حلق, «كيه» for ﷺ). Word-level tolerance is what lets a floor
 *  exist at all. */
const REPAIR_MIN_WORDS = 6;
const REPAIR_MIN_SHARE = 0.4;

interface Token {
  raw: string;
  norm: string;
}

/** Splits on whitespace, keeping each word's original form beside its
 *  normalized one. Tokens that normalize to nothing (a stray diacritic the OCR
 *  left standing alone, a lone «»») are dropped. Punctuation is stripped from
 *  `norm` only, so «حرم؛» compares as «حرم» while the displayed run keeps its
 *  marks. */
function tokenize(text: string): Token[] {
  const out: Token[] = [];
  for (const raw of text.split(/\s+/)) {
    const norm = normalizeArabic(raw).replace(/[^\p{L}\p{N}]/gu, "");
    if (norm.length > 0) out.push({ raw, norm });
  }
  return out;
}

/** Levenshtein distance, capped: returns `max + 1` as soon as the distance
 *  cannot stay within `max`, so the common case (different words) exits on
 *  the first row. Words, not sentences — a dozen letters each. */
function editDistanceWithin(a: string, b: string, max: number): number {
  if (Math.abs(a.length - b.length) > max) return max + 1;
  let prev = Array.from({ length: b.length + 1 }, (_, j) => j);
  for (let i = 1; i <= a.length; i++) {
    const cur = [i];
    let rowMin = i;
    for (let j = 1; j <= b.length; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost);
      rowMin = Math.min(rowMin, cur[j]);
    }
    if (rowMin > max) return max + 1;
    prev = cur;
  }
  return prev[b.length];
}

/** Two words are "the same" if they match exactly, or differ by one edit at
 *  three letters or more (خلق/حلق — one dot), or by two at seven or more.
 *  Below three letters an edit is a different word (من/في), not a scan error. */
function sameWord(a: string, b: string): boolean {
  if (a === b) return true;
  const n = Math.min(a.length, b.length);
  if (n < 3) return false;
  return editDistanceWithin(a, b, n >= 7 ? 2 : 1) <= (n >= 7 ? 2 : 1);
}

/** The longest run of consecutive words shared by `quote` and `chunk`,
 *  returned as the chunk's own original words — so what the user reads is the
 *  source's text, diacritics, scan errors and all, not the model's version of
 *  it. Null when no run clears the floor. Classic O(n·m) common-substring DP
 *  over words; the inputs are one quote and one chunk, a few hundred tokens. */
export function repairQuote(quote: string, chunk: string): string | null {
  const q = tokenize(quote);
  const c = tokenize(chunk);
  if (q.length === 0 || c.length === 0) return null;

  let best = 0;
  let bestEnd = -1;
  let prev = new Array<number>(c.length + 1).fill(0);
  for (let i = 1; i <= q.length; i++) {
    const cur = new Array<number>(c.length + 1).fill(0);
    for (let j = 1; j <= c.length; j++) {
      if (sameWord(q[i - 1].norm, c[j - 1].norm)) {
        cur[j] = prev[j - 1] + 1;
        if (cur[j] > best) {
          best = cur[j];
          bestEnd = j;
        }
      }
    }
    prev = cur;
  }

  if (best < REPAIR_MIN_WORDS || best / q.length < REPAIR_MIN_SHARE) return null;
  return c.slice(bestEnd - best, bestEnd).map((t) => t.raw).join(" ");
}

/** `chunkTextById` must contain only the chunks actually retrieved for this
 *  query — a citation pointing at a chunkId absent from the map (the model
 *  inventing an id, or referencing a chunk outside its own context) is
 *  dropped exactly like a genuine substring mismatch.
 *
 *  Citations are checked even on an answer the model already self-refused
 *  (`result.refused === true`) — e.g. hadith mode citing the closest
 *  authentic wording while still refusing the exact quote asked for. An
 *  earlier version skipped verification whenever `refused` was already
 *  true, which meant a self-refusal's citations reached the user
 *  unverified — the one case citation-verify exists to prevent. */
export function verifyCitations(
  result: AnswerResult,
  chunkTextById: ReadonlyMap<string, string>,
): VerifiedAnswer {
  const verified: AnswerResult["citations"] = [];
  const dropped: AnswerResult["citations"] = [];
  let repaired = 0;
  for (const citation of result.citations) {
    const chunkText = chunkTextById.get(citation.chunkId);
    const normalizedQuote = normalizeArabic(citation.quotedText);
    // An empty (or whitespace-only) quote is a substring of everything —
    // guard it explicitly so it can never "verify" without actually quoting.
    if (chunkText === undefined || normalizedQuote.length === 0) {
      dropped.push(citation);
      continue;
    }
    if (normalizeArabic(chunkText).includes(normalizedQuote)) {
      verified.push(citation);
      continue;
    }
    const fixed = repairQuote(citation.quotedText, chunkText);
    if (fixed !== null) {
      verified.push({ ...citation, quotedText: fixed });
      repaired++;
    } else {
      dropped.push(citation);
    }
  }

  // Only force a hard refusal + blanked answer when there WERE citations and
  // every one of them was fabricated — the model's only supporting evidence
  // turned out to be fake, so nothing about the answer can be trusted. A
  // bare self-refusal with no citations at all (or one that already
  // verified) is left as-is, including whatever `answer` text the model
  // wrote — handlers/search.ts decides what to actually show for that.
  if (result.citations.length > 0 && verified.length === 0) {
    // Everything structured goes with the answer, not just `answer` itself.
    // The summary, the per-scholar cards and the hadith grading were all
    // written on the strength of citations that turned out to be fabricated —
    // keeping any of them would leave the fabrication on screen in a different
    // shape, and the ruling would still colour a status dot.
    return {
      answer: "",
      citations: [],
      refused: true,
      model: result.model,
      droppedCitations: dropped,
      repairedCitations: 0,
    };
  }

  return { ...result, citations: verified, droppedCitations: dropped, repairedCitations: repaired };
}
