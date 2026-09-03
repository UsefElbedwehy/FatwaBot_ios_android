// A read-through cache in front of an EmbeddingProvider (0044_query_embedding_cache.sql).
//
// Query embeddings are the one provider call on the hot path that is trivially
// cacheable: the same question always produces the same vector for a given
// model. On the free Voyage tier that call is 238ms cold and ~56s when the rate
// limit bites, so a hit is the difference between a fast search and a minute of
// waiting.
import type { EmbeddingProvider } from "./providers.ts";
import { normalizeArabic } from "./text_normalize.ts";

export interface EmbeddingCacheRepo {
  /** Vectors for the hashes that are cached, keyed by hash. Missing keys are
   *  simply absent — a partial hit is normal and useful. */
  getMany(appId: string, hashes: string[], model: string): Promise<Map<string, number[]>>;
  put(appId: string, hash: string, model: string, embedding: number[]): Promise<void>;
}

/** SHA-256 of the normalised text. Normalising first means the same question
 *  with different spacing, tatweel or diacritics is one cache entry rather than
 *  several — the same normalisation the citation verifier already relies on. */
export async function questionHash(text: string): Promise<string> {
  const bytes = new TextEncoder().encode(normalizeArabic(text));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/**
 * Wraps a provider so repeated questions never reach it.
 *
 * Deliberately fail-open: a cache that is down must not take search down with
 * it. Every cache error is logged and then swallowed, and the call falls
 * through to the real provider — slower, never broken.
 */
export class CachingEmbeddingProvider implements EmbeddingProvider {
  constructor(
    private readonly inner: EmbeddingProvider,
    private readonly cache: EmbeddingCacheRepo,
    private readonly appId: string,
  ) {}

  get dimensions(): number {
    return this.inner.dimensions;
  }

  get id(): string {
    return this.inner.id;
  }

  async embed(texts: string[]): Promise<number[][]> {
    const hashes = await Promise.all(texts.map(questionHash));

    let cached = new Map<string, number[]>();
    try {
      cached = await this.cache.getMany(this.appId, hashes, this.inner.id);
    } catch (err) {
      console.warn("embedding_cache_read_failed", err instanceof Error ? err.message : err);
    }

    // Which texts still need the provider. Indices are tracked so the results
    // can be put back in the caller's original order — `embed` is contractually
    // positional, and a hybrid of hits and misses must not scramble it.
    const missIndices: number[] = [];
    for (let i = 0; i < texts.length; i++) {
      if (!cached.has(hashes[i])) missIndices.push(i);
    }

    let fresh: number[][] = [];
    if (missIndices.length > 0) {
      fresh = await this.inner.embed(missIndices.map((i) => texts[i]));
    }

    const out: number[][] = new Array(texts.length);
    for (let i = 0; i < texts.length; i++) {
      const hit = cached.get(hashes[i]);
      if (hit) out[i] = hit;
    }
    missIndices.forEach((originalIndex, k) => {
      out[originalIndex] = fresh[k];
    });

    // Written after the response is assembled, and never awaited into the
    // failure path: a cache write that fails has cost the user nothing, and
    // should not turn a successful embedding into an error.
    await Promise.all(missIndices.map(async (originalIndex, k) => {
      try {
        await this.cache.put(this.appId, hashes[originalIndex], this.inner.id, fresh[k]);
      } catch (err) {
        console.warn("embedding_cache_write_failed", err instanceof Error ? err.message : err);
      }
    }));

    return out;
  }
}
