// Hybrid retrieval (docs/features/ai-search-m5.0-spec.md §Retrieval): embed
// the question, run vector ∥ FTS ∥ trigram (mode "hadith" only) searches in
// parallel, merge with Reciprocal Rank Fusion, return the top N. Each of the
// three searches enforces license_status='granted' + active in SQL — this
// module trusts that and never re-checks it.
import type { AppContext } from "../types.ts";
import type { FatwaMode, FatwaSearchRepo, RetrievedChunk } from "../fatwa_types.ts";
import type { EmbeddingProvider } from "./providers.ts";

export interface RetrievalOptions {
  vectorTopK?: number;
  ftsTopK?: number;
  trigramTopK?: number;
  trigramMinSimilarity?: number;
  finalTopN?: number;
  /** RRF's smoothing constant — 60 is the standard default from the
   *  original Reciprocal Rank Fusion paper, dampening the influence of any
   *  single list's exact rank while still rewarding being ranked at all. */
  rrfK?: number;
}

const DEFAULTS: Required<RetrievalOptions> = {
  vectorTopK: 20,
  ftsTopK: 20,
  trigramTopK: 20,
  trigramMinSimilarity: 0.15,
  finalTopN: 8,
  rrfK: 60,
};

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

/** Mode 2 (استخراج الأحاديث) is the only one that adds trigram search — a
 *  user paraphrasing/misremembering a hadith's wording rarely matches FTS's
 *  exact tokens, but shares enough substrings for trigram similarity to
 *  still find it. */
function modeUsesTrigram(mode: FatwaMode): boolean {
  return mode === "hadith";
}

export async function hybridRetrieve(
  ctx: AppContext,
  repo: FatwaSearchRepo,
  embedder: EmbeddingProvider,
  question: string,
  mode: FatwaMode,
  opts: RetrievalOptions = {},
): Promise<RetrievedChunk[]> {
  const o = { ...DEFAULTS, ...opts };
  const [embedding] = await embedder.embed([question]);

  const searches: Promise<RetrievedChunk[]>[] = [
    repo.vectorSearch(ctx, embedding, o.vectorTopK),
    repo.ftsSearch(ctx, question, o.ftsTopK),
  ];
  if (modeUsesTrigram(mode)) {
    searches.push(repo.trigramSearch(ctx, question, o.trigramTopK, o.trigramMinSimilarity));
  }
  const results = await Promise.all(searches);

  return reciprocalRankFusion(results, o.rrfK).slice(0, o.finalTopN);
}
