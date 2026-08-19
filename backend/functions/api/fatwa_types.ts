// Shared domain types for AI fatwa search (docs/features/ai-search-m5.0-spec.md).
// Kept separate from ai_search/providers.ts and ai_search/retrieval.ts so both
// can depend on these without a circular import.
import type { AppContext } from "./types.ts";

export type FatwaMode = "fatwa" | "hadith" | "general";

/** One hybrid-search hit — the shape all three of vector/FTS/trigram search
 *  return, so retrieval.ts can RRF-merge them without caring which one a row
 *  came from. `score` is provider-specific (cosine similarity / ts_rank_cd /
 *  pg_trgm similarity) — only meaningful for ranking *within* one source,
 *  never compared across sources directly (that's what RRF is for). */
export interface RetrievedChunk {
  chunkId: string;
  documentId: string;
  sourceId: string;
  scholarId: string;
  text: string;
  pageNumber: number | null;
  videoTimestamp: number | null;
  sourceTitle: string;
  sourceCategory: string | null;
  scholarName: Record<string, string>;
  score: number;
}

export interface AnswerCitation {
  chunkId: string;
  scholar: string;
  sourceTitle: string;
  pageNumber?: number;
  videoTimestamp?: number;
  quotedText: string;
}

export interface AnswerResult {
  answer: string;
  citations: AnswerCitation[];
  refused: boolean;
  model: string;
}

export interface AnswerLogInput {
  userId: string;
  mode: FatwaMode;
  question: string;
  retrievedChunkIds: string[];
  citations: AnswerCitation[];
  answer: string;
  refused: boolean;
  model: string;
}

/** Read-side hybrid search over fatwa.chunks (vector/FTS/trigram — each
 *  enforces license_status='granted' + active in SQL, not just here), plus
 *  the answers_log write used for QA/abuse monitoring. Implemented by
 *  SupabaseFatwaSearchRepo (production) and InMemoryFatwaSearchRepo (tests). */
export interface FatwaSearchRepo {
  vectorSearch(ctx: AppContext, embedding: number[], matchCount: number): Promise<RetrievedChunk[]>;
  ftsSearch(ctx: AppContext, query: string, matchCount: number): Promise<RetrievedChunk[]>;
  trigramSearch(
    ctx: AppContext,
    query: string,
    matchCount: number,
    minSimilarity?: number,
  ): Promise<RetrievedChunk[]>;
  logAnswer(ctx: AppContext, entry: AnswerLogInput): Promise<void>;
}
