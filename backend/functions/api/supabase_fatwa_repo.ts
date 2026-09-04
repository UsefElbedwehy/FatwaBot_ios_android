import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import type { AppContext } from "./types.ts";
import type { AnswerLogInput, FatwaSearchRepo, RetrievedChunk } from "./fatwa_types.ts";
import type { EmbeddingCacheRepo } from "./ai_search/embedding_cache.ts";

/** Snake-case row shape shared by all three of fatwa.search_vector /
 *  fatwa.search_fts / fatwa.search_trigram (0042_fatwa_schema.sql) — each
 *  already enforces license_status='granted' + active in SQL. */
interface SearchRow {
  chunk_id: string;
  document_id: string;
  source_id: string;
  scholar_id: string;
  chunk_text: string;
  page_number: number | null;
  video_timestamp: number | null;
  source_title: string;
  source_category: string | null;
  scholar_name: Record<string, string>;
  score: number;
}

function toRetrievedChunk(row: SearchRow): RetrievedChunk {
  return {
    chunkId: row.chunk_id,
    documentId: row.document_id,
    sourceId: row.source_id,
    scholarId: row.scholar_id,
    text: row.chunk_text,
    pageNumber: row.page_number,
    videoTimestamp: row.video_timestamp,
    sourceTitle: row.source_title,
    sourceCategory: row.source_category,
    scholarName: row.scholar_name,
    score: row.score,
  };
}

export class SupabaseFatwaSearchRepo implements FatwaSearchRepo {
  constructor(private readonly db: SupabaseClient) {}

  async vectorSearch(ctx: AppContext, embedding: number[], matchCount: number): Promise<RetrievedChunk[]> {
    const { data, error } = await this.db.schema("fatwa").rpc("search_vector", {
      p_app_id: ctx.appId,
      p_query_embedding: embedding,
      p_match_count: matchCount,
    });
    if (error) throw error;
    return ((data ?? []) as SearchRow[]).map(toRetrievedChunk);
  }

  async ftsSearch(ctx: AppContext, query: string, matchCount: number): Promise<RetrievedChunk[]> {
    const { data, error } = await this.db.schema("fatwa").rpc("search_fts", {
      p_app_id: ctx.appId,
      p_query: query,
      p_match_count: matchCount,
    });
    if (error) throw error;
    return ((data ?? []) as SearchRow[]).map(toRetrievedChunk);
  }

  async trigramSearch(
    ctx: AppContext,
    query: string,
    matchCount: number,
    minSimilarity?: number,
  ): Promise<RetrievedChunk[]> {
    const { data, error } = await this.db.schema("fatwa").rpc("search_trigram", {
      p_app_id: ctx.appId,
      p_query: query,
      p_match_count: matchCount,
      ...(minSimilarity !== undefined ? { p_min_similarity: minSimilarity } : {}),
    });
    if (error) throw error;
    return ((data ?? []) as SearchRow[]).map(toRetrievedChunk);
  }

  async logAnswer(ctx: AppContext, entry: AnswerLogInput): Promise<void> {
    const { error } = await this.db.schema("fatwa").from("answers_log").insert({
      app_id: ctx.appId,
      user_id: entry.userId,
      mode: entry.mode,
      question: entry.question,
      retrieved_chunk_ids: entry.retrievedChunkIds,
      citations: entry.citations,
      answer: entry.answer,
      refused: entry.refused,
      model: entry.model,
    });
    if (error) throw error;
  }
}

/** Postgres-backed query-embedding cache (0044_query_embedding_cache.sql). */
export class SupabaseEmbeddingCacheRepo implements EmbeddingCacheRepo {
  constructor(private readonly db: SupabaseClient) {}

  async getMany(appId: string, hashes: string[], model: string): Promise<Map<string, number[]>> {
    if (hashes.length === 0) return new Map();
    const { data, error } = await this.db
      .schema("fatwa")
      .from("query_embeddings")
      .select("question_hash, embedding")
      .eq("app_id", appId)
      .eq("model", model)
      .in("question_hash", hashes);
    if (error) throw error;

    const out = new Map<string, number[]>();
    for (const row of (data ?? []) as { question_hash: string; embedding: string | number[] }[]) {
      // pgvector comes back over PostgREST as its text form ("[1,2,3]"), not as
      // a JSON array — parse it rather than handing a string to the searcher,
      // which would fail far away from here with a confusing type error.
      const vector = typeof row.embedding === "string"
        ? JSON.parse(row.embedding) as number[]
        : row.embedding;
      out.set(row.question_hash, vector);
    }
    return out;
  }

  async put(appId: string, hash: string, model: string, embedding: number[]): Promise<void> {
    // Upsert, not insert: two requests can miss on the same question at the same
    // moment and both try to write it. That is a race worth winning quietly.
    const { error } = await this.db
      .schema("fatwa")
      .from("query_embeddings")
      .upsert({
        app_id: appId,
        question_hash: hash,
        model,
        embedding: JSON.stringify(embedding),
        last_used_at: new Date().toISOString(),
      }, { onConflict: "app_id,question_hash,model" });
    if (error) throw error;
  }
}
