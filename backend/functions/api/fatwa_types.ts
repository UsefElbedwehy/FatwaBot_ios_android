// Shared domain types for AI fatwa search (docs/features/ai-search-m5.0-spec.md).
// Kept separate from ai_search/providers.ts and ai_search/retrieval.ts so both
// can depend on these without a circular import.
import type { AppContext } from "./types.ts";

export type FatwaMode = "fatwa" | "hadith" | "general";

/** One hybrid-search hit — the shape both of vector/FTS search
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
  /** `book` | `video` | `website` — what this source *is*, so the client can
   *  state where an answer is available without asking the model to guess. */
  sourceKind: string;
  sourceUrl: string | null;
  scholarName: Record<string, string>;
  score: number;
  /** True when the chunk carries the OCR-shattering signature (three or more
   *  consecutive isolated letters — see 0050). Retrieval ranks such a chunk
   *  below a readable one; nothing downstream refuses it outright, because a
   *  shattered line at the top of a page does not make the rest unreadable. */
  ocrShattered: boolean;
}

export interface AnswerCitation {
  chunkId: string;
  scholar: string;
  sourceTitle: string;
  pageNumber?: number;
  videoTimestamp?: number;
  quotedText: string;
}

/** The five-fold fiqh scale, plus a general "permitted" and an explicit
 *  "no ruling applies". `none` is not a synonym for uncertainty — it means the
 *  question has none to give (a hadith's grading, a du'a's wording), and the
 *  client shows no status dot at all. */
export type Ruling = "wajib" | "mustahabb" | "halal" | "mubah" | "makruh" | "haram" | "none";

/** One scholar's position, rendered as its own card. Citations are NOT nested
 *  here: they stay one flat list on AnswerResult so verification can check them
 *  exhaustively, and each already names its scholar for the client to group by. */
export interface ScholarAnswer {
  scholar: string;
  answer: string;
  evidence?: string;
}

/** Hadith mode's takhrij fields, laid out as separate rows rather than one
 *  paragraph. Absent in the other modes. */
export interface HadithVerdict {
  text: string;
  grade: string;
  source?: string;
  scholarVerdicts?: string;
}

export interface AnswerResult {
  answer: string;
  citations: AnswerCitation[];
  refused: boolean;
  model: string;
  summary?: string;
  ruling?: Ruling;
  scholarAnswers?: ScholarAnswer[];
  hadith?: HadithVerdict;
}

/** Why a search refused, for the log. Distinguishes the model declining on
 *  its own from the verifier blanking an answer whose every citation failed —
 *  the two look identical to the user and mean opposite things to whoever is
 *  tuning the pipeline. */
export type RefusalReason = "model_refused" | "all_citations_dropped" | "no_chunks";

export interface AnswerLogInput {
  userId: string;
  mode: FatwaMode;
  question: string;
  retrievedChunkIds: string[];
  citations: AnswerCitation[];
  /** Citations the model produced that verification rejected. */
  droppedCitations: AnswerCitation[];
  answer: string;
  refused: boolean;
  refusalReason: RefusalReason | null;
  model: string;
}

/** Read-side hybrid search over fatwa.chunks (vector/FTS — each
 *  enforces license_status='granted' + active in SQL, not just here), plus
 *  the answers_log write used for QA/abuse monitoring. Implemented by
 *  SupabaseFatwaSearchRepo (production) and InMemoryFatwaSearchRepo (tests). */
export interface FatwaSearchRepo {
  vectorSearch(ctx: AppContext, embedding: number[], matchCount: number): Promise<RetrievedChunk[]>;
  ftsSearch(ctx: AppContext, query: string, matchCount: number): Promise<RetrievedChunk[]>;
  /** Hadith mode's leg: normalised FTS over content.hadith_entries (0050),
   *  returned in the same shape so nothing downstream needs a second path. */
  hadithSearch(ctx: AppContext, query: string, matchCount: number): Promise<RetrievedChunk[]>;
  logAnswer(ctx: AppContext, entry: AnswerLogInput): Promise<void>;
}
