// Whole-answer cache (0046_answer_cache.sql).
//
// 0044 cached the query embedding, removing ~240ms of a ~15s request. This
// caches the finished response, removing the other ~14s: retrieval and the
// answer model both drop out, and a repeat becomes one indexed lookup.
//
// Correctness rests on the key and the generation, not on a TTL:
//   - (app, question hash, mode, model) — a different mode is a different
//     prompt, a different model is a different voice.
//   - corpus_generation — bumped by the ingester, so ingesting the book that
//     answers a previously-refused question invalidates that refusal at once
//     rather than whenever a timer happened to be set for.
import type { AppContext } from "../types.ts";

export interface CachedAnswer {
  response: unknown;
  corpusGeneration: number;
}

export interface AnswerCacheRepo {
  /** The cached response for this key, or null. Implementations must treat a
   *  generation mismatch as a miss — a stale answer is worse than a slow one. */
  get(ctx: AppContext, questionHash: string, mode: string, model: string): Promise<unknown | null>;
  put(
    ctx: AppContext,
    questionHash: string,
    mode: string,
    model: string,
    response: unknown,
  ): Promise<void>;
}
