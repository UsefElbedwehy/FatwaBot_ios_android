import type { AppContext } from "../functions/api/types.ts";
import type { AnswerLogInput, FatwaSearchRepo, RetrievedChunk } from "../functions/api/fatwa_types.ts";

export interface SeedChunk {
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
  embedding: number[];
  /** Defaults to true — set false to exercise the license/active filter. */
  licenseGranted?: boolean;
  sourceActive?: boolean;
  scholarActive?: boolean;
}

function cosineSimilarity(a: number[], b: number[]): number {
  let dot = 0, normA = 0, normB = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  if (normA === 0 || normB === 0) return 0;
  return dot / (Math.sqrt(normA) * Math.sqrt(normB));
}

function words(text: string): string[] {
  return text.split(/\s+/).filter((w) => w.length > 0);
}

/** Word-overlap approximation of Postgres FTS's ts_rank_cd — good enough to
 *  exercise RRF fusion in tests, not a real search engine. */
function ftsScore(query: string, text: string): number {
  const queryWords = new Set(words(query));
  if (queryWords.size === 0) return 0;
  const textWords = new Set(words(text));
  let hits = 0;
  for (const w of queryWords) if (textWords.has(w)) hits++;
  return hits / queryWords.size;
}

function trigrams(text: string): Set<string> {
  const padded = `  ${text}  `;
  const grams = new Set<string>();
  for (let i = 0; i < padded.length - 2; i++) grams.add(padded.slice(i, i + 3));
  return grams;
}

/** Jaccard similarity over character trigrams — approximates pg_trgm's
 *  `similarity()` closely enough for RRF-fusion and threshold tests. */
function trigramScore(query: string, text: string): number {
  const a = trigrams(query);
  const b = trigrams(text);
  if (a.size === 0 || b.size === 0) return 0;
  let intersection = 0;
  for (const g of a) if (b.has(g)) intersection++;
  const union = a.size + b.size - intersection;
  return union === 0 ? 0 : intersection / union;
}

function toRetrievedChunk(seed: SeedChunk, score: number): RetrievedChunk {
  return {
    chunkId: seed.chunkId,
    documentId: seed.documentId,
    sourceId: seed.sourceId,
    scholarId: seed.scholarId,
    text: seed.text,
    pageNumber: seed.pageNumber,
    videoTimestamp: seed.videoTimestamp,
    sourceTitle: seed.sourceTitle,
    sourceCategory: seed.sourceCategory,
    scholarName: seed.scholarName,
    score,
  };
}

export class InMemoryFatwaSearchRepo implements FatwaSearchRepo {
  private chunks: SeedChunk[] = [];
  readonly loggedAnswers: (AnswerLogInput & { appId: string })[] = [];

  seed(chunks: SeedChunk[]): void {
    this.chunks.push(...chunks);
  }

  private eligible(): SeedChunk[] {
    return this.chunks.filter(
      (c) => (c.licenseGranted ?? true) && (c.sourceActive ?? true) && (c.scholarActive ?? true),
    );
  }

  vectorSearch(_ctx: AppContext, embedding: number[], matchCount: number): Promise<RetrievedChunk[]> {
    const ranked = this.eligible()
      .map((c) => ({ c, score: cosineSimilarity(embedding, c.embedding) }))
      .sort((a, b) => b.score - a.score)
      .slice(0, matchCount);
    return Promise.resolve(ranked.map(({ c, score }) => toRetrievedChunk(c, score)));
  }

  ftsSearch(_ctx: AppContext, query: string, matchCount: number): Promise<RetrievedChunk[]> {
    const ranked = this.eligible()
      .map((c) => ({ c, score: ftsScore(query, c.text) }))
      .filter((r) => r.score > 0)
      .sort((a, b) => b.score - a.score)
      .slice(0, matchCount);
    return Promise.resolve(ranked.map(({ c, score }) => toRetrievedChunk(c, score)));
  }

  trigramSearch(
    _ctx: AppContext,
    query: string,
    matchCount: number,
    minSimilarity = 0.15,
  ): Promise<RetrievedChunk[]> {
    const ranked = this.eligible()
      .map((c) => ({ c, score: trigramScore(query, c.text) }))
      .filter((r) => r.score >= minSimilarity)
      .sort((a, b) => b.score - a.score)
      .slice(0, matchCount);
    return Promise.resolve(ranked.map(({ c, score }) => toRetrievedChunk(c, score)));
  }

  logAnswer(ctx: AppContext, entry: AnswerLogInput): Promise<void> {
    this.loggedAnswers.push({ ...entry, appId: ctx.appId });
    return Promise.resolve();
  }
}
