// Hybrid retrieval (docs/features/ai-search-m5.0-spec.md §Retrieval): embed
// the question, run vector ∥ FTS in parallel, merge with Reciprocal Rank
// Fusion, return the top N. Both searches enforce license_status='granted' +
// active in SQL — this module trusts that and never re-checks it.
//
// Mode matters again since 0050: hadith mode adds a leg over
// content.hadith_entries (docs/features/search-quality-m5.2.md). The fatwa
// corpus is a shelf of one scholar's books, not a hadith collection, and
// asking it to grade a hadith refused seven of the first nine attempts. The
// other two modes are unchanged.
import type { AppContext } from "../types.ts";
import type { FatwaMode, FatwaSearchRepo, RetrievedChunk } from "../fatwa_types.ts";
import type { EmbeddingProvider } from "./providers.ts";
import { normalizeArabic } from "./text_normalize.ts";

export interface RetrievalOptions {
  mode?: FatwaMode;
  vectorTopK?: number;
  ftsTopK?: number;
  /** Hadith mode only: how many hadith hits lead the result. */
  hadithTopK?: number;
  finalTopN?: number;
  /** RRF's smoothing constant — 60 is the standard default from the
   *  original Reciprocal Rank Fusion paper, dampening the influence of any
   *  single list's exact rank while still rewarding being ranked at all. */
  rrfK?: number;
  /** Multiplier on the fused score of an OCR-shattered chunk (0050). 0.5 means
   *  a wrecked chunk has to be found by *both* legs at rank 1 to tie with a
   *  readable chunk found by one — it is penalised, not excluded, because a
   *  shattered header does not make the page under it unreadable. */
  shatteredPenalty?: number;
}

const DEFAULTS: Required<Omit<RetrievalOptions, "mode">> = {
  // Wider than the 20 they were: the penalty below needs readable candidates
  // to promote, and in a corpus that is 85% shattered the top 20 of one leg
  // may hold three.
  vectorTopK: 30,
  ftsTopK: 30,
  hadithTopK: 3,
  // Six, down from eight (M5.2 speed pass). The answer step is the request's
  // cost and scales with what the model reads; measured live, the sixth chunk
  // and beyond had never carried a surviving citation.
  finalTopN: 6,
  rrfK: 60,
  shatteredPenalty: 0.5,
};

/** Words that frame a question rather than name its subject. FTS ANDs every
 *  token, and «حكم» appears in most of a fatwa corpus, so «ما حكم حلق اللحية»
 *  was gated on the wrong word: 34 chunks matched with the frame, 61 without.
 *  Content words still AND — this is not a switch to OR, which ranks
 *  tables of contents first because ts_rank_cd has no notion of IDF.
 *  Normalised forms, matched after `normalizeArabic`. Deliberately short, and
 *  no prepositions: «في» and «من» are in every chunk and gate nothing. */
const QUESTION_FRAME_WORDS = new Set(
  [
    "ما",
    "ماذا",
    "هل",
    "حكم",
    "صحة",
    "صحه",
    "درجة",
    "درجه",
    "تخريج",
    "معنى",
    "معني",
    "شرح",
    "يجوز",
    "يصح",
    "حديث",
    "الحديث",
    "سؤال",
    "أريد",
    "اريد",
    "أرجو",
    "ارجو",
  ].map(normalizeArabic),
);

/** The question with its frame words removed, for the FTS legs. Falls back to
 *  the original when nothing else is left — «ما حكم؟» is a bad question, not
 *  an empty one. Pure; exported for tests. */
export function stripQuestionFrame(question: string): string {
  const kept = question
    .split(/\s+/)
    .filter((w) => w.length > 0)
    .filter((w) => !QUESTION_FRAME_WORDS.has(normalizeArabic(w).replace(/[؟?!.،,]/g, "")));
  return kept.length > 0 ? kept.join(" ") : question;
}

/** Merges any number of independently-ranked result lists into one, scoring
 *  each chunk by the sum of 1/(k + rank) across every list it appears in
 *  (1-indexed rank). A chunk found by more than one search method — e.g.
 *  both vector and FTS — accumulates score from each, which is the point:
 *  agreement across retrieval methods is a stronger signal than any single
 *  method's raw score (which isn't comparable across methods to begin with —
 *  cosine similarity and ts_rank_cd live on different scales). The returned
 *  chunks carry the *fused* RRF score in `.score`, replacing whichever raw
 *  per-list score they arrived with. Pure — no I/O — so this is unit-tested
 *  directly, without a repo or embedder. */
export function reciprocalRankFusion(lists: RetrievedChunk[][], k: number = DEFAULTS.rrfK): RetrievedChunk[] {
  const fused = new Map<string, { chunk: RetrievedChunk; score: number }>();
  for (const list of lists) {
    list.forEach((chunk, index) => {
      const rank = index + 1;
      const contribution = 1 / (k + rank);
      const existing = fused.get(chunk.chunkId);
      if (existing) {
        existing.score += contribution;
      } else {
        fused.set(chunk.chunkId, { chunk, score: contribution });
      }
    });
  }
  return [...fused.values()]
    .sort((a, b) => b.score - a.score)
    .map(({ chunk, score }) => ({ ...chunk, score }));
}

/** Applies the shattered penalty and re-sorts. Pure; exported for tests. */
export function penalizeShattered(chunks: RetrievedChunk[], penalty: number): RetrievedChunk[] {
  return chunks
    .map((c) => (c.ocrShattered ? { ...c, score: c.score * penalty } : c))
    .sort((a, b) => b.score - a.score);
}

/** Which half of retrieval failed: the outbound embedding call, or the SQL
 *  search functions — and for the latter, which of them. */
export class RetrievalError extends Error {
  constructor(
    readonly stage: "embedding" | "search",
    readonly reason: unknown,
    readonly failedSearches: string[] = [],
  ) {
    super(`retrieval failed at the ${stage} stage`);
    this.name = "RetrievalError";
  }
}

export async function hybridRetrieve(
  ctx: AppContext,
  repo: FatwaSearchRepo,
  embedder: EmbeddingProvider,
  question: string,
  opts: RetrievalOptions = {},
  /** Filled in with per-stage wall-clock, when the caller supplies it. The
   *  stages have wildly different cost profiles — an outbound HTTPS call to a
   *  rate-limited provider versus three local index scans — and a single
   *  end-to-end number cannot tell them apart. */
  timings?: { embedMs?: number; searchMs?: number },
): Promise<RetrievedChunk[]> {
  const o = { ...DEFAULTS, ...opts };

  // Tagged by stage. "Retrieval failed" spans an outbound embedding call and
  // the SQL functions; without knowing which, a production failure is a
  // coin flip between an upstream provider and an unapplied migration.
  let embedding: number[];
  const embedStart = performance.now();
  try {
    [embedding] = await embedder.embed([question]);
  } catch (err) {
    throw new RetrievalError("embedding", err);
  } finally {
    if (timings) timings.embedMs = Math.round(performance.now() - embedStart);
  }

  // The vector leg sees the whole question — an embedding model wants the
  // frame, «ما حكم» is what makes it a fatwa question. Only the lexical legs
  // get the stripped form, since for them the frame is noise that gates.
  const lexical = stripQuestionFrame(question);

  // Two legs for the fatwa corpus, not three. The trigram leg was retired in
  // the database on 2026-09-04 — whole-chunk similarity had to scan every
  // chunk (30-60s) and returned nothing useful, since similarity between a
  // short question and a multi-paragraph chunk is close to meaningless. Its
  // index (70 MB) was dropped with it. Arabic recall is carried instead by
  // `fatwa.normalize_ar` in FTS (0047), which folds diacritics and letter
  // variants — the thing trigram was really being asked to do.
  const named: { name: string; run: Promise<RetrievedChunk[]> }[] = [
    { name: "vector", run: repo.vectorSearch(ctx, embedding, o.vectorTopK) },
    { name: "fts", run: repo.ftsSearch(ctx, lexical, o.ftsTopK) },
  ];
  if (o.mode === "hadith") {
    named.push({ name: "hadith", run: repo.hadithSearch(ctx, lexical, o.hadithTopK) });
  }

  // `allSettled`, not `all`. The whole point of fusing independent searches
  // is that they are independent: if the vector index is slow enough to hit
  // the statement timeout, FTS has usually already returned perfectly good
  // results, and `Promise.all` threw them away along with the request. Now
  // one failure degrades the ranking instead of ending it, and only a total
  // failure is fatal. Which ones failed is recorded either way — a silently
  // degraded search is its own kind of bug.
  const searchStart = performance.now();
  const settled = await Promise.allSettled(named.map((s) => s.run));
  if (timings) timings.searchMs = Math.round(performance.now() - searchStart);
  const results: RetrievedChunk[][] = [];
  let hadithHits: RetrievedChunk[] = [];
  const failed: { name: string; reason: unknown }[] = [];
  settled.forEach((outcome, i) => {
    if (outcome.status === "rejected") {
      failed.push({ name: named[i].name, reason: outcome.reason });
    } else if (named[i].name === "hadith") {
      hadithHits = outcome.value;
    } else {
      results.push(outcome.value);
    }
  });
  for (const f of failed) {
    console.error(
      `retrieval_search_failed:${f.name}`,
      f.reason instanceof Error ? f.reason.stack ?? f.reason.message : f.reason,
    );
  }
  if (results.length === 0 && hadithHits.length === 0) {
    throw new RetrievalError("search", failed[0]?.reason, failed.map((f) => f.name));
  }

  const fused = penalizeShattered(reciprocalRankFusion(results, o.rrfK), o.shatteredPenalty);

  // Hadith hits lead rather than fuse. RRF rewards agreement between legs, and
  // a hadith entry can only ever be found by its one leg — fused, an exact
  // matn match would sit below any fatwa chunk two legs agreed on. In hadith
  // mode the matn and its grading are the answer; the scholar's commentary
  // from the fatwa corpus fills the remaining slots as supporting context.
  return [...hadithHits, ...fused].slice(0, o.finalTopN);
}
