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

/** The version of the response body's *shape*, bumped whenever the contract
 *  changes. Part of the cache key (0049).
 *
 *  The rest of the key covers what changes an answer's content — question,
 *  mode, model, corpus generation. None of that moves when the response schema
 *  does, so without this a contract change serves stored bodies in the old
 *  shape to clients expecting the new one. Observed: the M5.1 structured
 *  deploy's first request returned the flat pre-M5.1 body in 0.96s.
 *
 *  1 = flat { answer, citations, refused, mode }
 *  2 = M5.1 structured { + summary, ruling, scholar_answers, hadith, resources }
 *  3 = 0050: summary/scholar_answers guaranteed on a non-refusal, locators from
 *      the chunk. Bumped to evict the bodies one broken deploy cached — a
 *      non-refusal with an empty summary was stored as a valid answer. */
export const RESPONSE_CONTRACT_VERSION = 3;

export interface CachedAnswer {
  response: unknown;
  corpusGeneration: number;
}

/** Implementations key on RESPONSE_CONTRACT_VERSION as well as the arguments
 *  below; it is a module constant rather than a parameter so a call site cannot
 *  forget it. */
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
