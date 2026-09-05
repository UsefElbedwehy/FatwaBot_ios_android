// Hybrid retrieval (docs/features/ai-search-m5.0-spec.md §Retrieval): embed
// the question, run vector ∥ FTS in parallel, merge with Reciprocal Rank
// Fusion, return the top N. Both searches enforce license_status='granted' +
// active in SQL — this module trusts that and never re-checks it.
//
// A trigram leg used to run for hadith mode; it was retired in 0047 (see the
// note where the legs are built). Retrieval is therefore mode-independent, and
// no longer takes a mode — only the answer prompt varies by mode now, and a
// parameter kept "just in case" would imply otherwise to the next reader.
import type { AppContext } from "../types.ts";
import type { FatwaSearchRepo, RetrievedChunk } from "../fatwa_types.ts";
import type { EmbeddingProvider } from "./providers.ts";

export interface RetrievalOptions {
  vectorTopK?: number;
  ftsTopK?: number;
  finalTopN?: number;
  /** RRF's smoothing constant — 60 is the standard default from the
   *  original Reciprocal Rank Fusion paper, dampening the influence of any
   *  single list's exact rank while still rewarding being ranked at all. */
  rrfK?: number;
}

const DEFAULTS: Required<RetrievalOptions> = {
  vectorTopK: 20,
  ftsTopK: 20,
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

/** Which half of retrieval failed: the outbound embedding call, or the SQL
 *  search functions — and for the latter, which of the three. */
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
  // three SQL functions; without knowing which, a production failure is a
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

  // Two legs, not three. The trigram leg was retired in the database on
  // 2026-09-04 — whole-chunk similarity had to scan every chunk (30-60s) and
  // returned nothing useful, since similarity between a short question and a
  // multi-paragraph chunk is close to meaningless. Its index (70 MB) was
  // dropped with it, so calling it now would be a guaranteed empty round-trip.
  // Arabic recall is carried instead by `fatwa.normalize_ar` in FTS (0047),
  // which folds diacritics and alef/ya variants — the thing trigram was
  // really being asked to do.
  const named: { name: string; run: Promise<RetrievedChunk[]> }[] = [
    { name: "vector", run: repo.vectorSearch(ctx, embedding, o.vectorTopK) },
    { name: "fts", run: repo.ftsSearch(ctx, question, o.ftsTopK) },
  ];

  // `allSettled`, not `all`. The whole point of fusing three independent
  // searches is that they are independent: if the vector index is slow enough
  // to hit the statement timeout, FTS and trigram have usually already returned
  // perfectly good results, and `Promise.all` threw them away along with the
  // request. Now one failure degrades the ranking instead of ending it, and
  // only an all-three failure is fatal. Which ones failed is recorded either
  // way — a silently degraded search is its own kind of bug.
  const searchStart = performance.now();
  const settled = await Promise.allSettled(named.map((s) => s.run));
  if (timings) timings.searchMs = Math.round(performance.now() - searchStart);
  const results: RetrievedChunk[][] = [];
  const failed: { name: string; reason: unknown }[] = [];
  settled.forEach((outcome, i) => {
    if (outcome.status === "fulfilled") {
      results.push(outcome.value);
    } else {
      failed.push({ name: named[i].name, reason: outcome.reason });
    }
  });
  for (const f of failed) {
    console.error(
      `retrieval_search_failed:${f.name}`,
      f.reason instanceof Error ? f.reason.stack ?? f.reason.message : f.reason,
    );
  }
  if (results.length === 0) {
    throw new RetrievalError("search", failed[0]?.reason, failed.map((f) => f.name));
  }

  return reciprocalRankFusion(results, o.rrfK).slice(0, o.finalTopN);
}
