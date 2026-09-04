import { assertEquals } from "jsr:@std/assert@1";
import {
  CachingEmbeddingProvider,
  type EmbeddingCacheRepo,
  questionHash,
} from "../functions/api/ai_search/embedding_cache.ts";
import type { EmbeddingProvider } from "../functions/api/ai_search/providers.ts";

const APP = "00000000-0000-4000-a000-000000000001";

class FakeCache implements EmbeddingCacheRepo {
  readonly store = new Map<string, number[]>();
  writes = 0;
  failReads = false;
  failWrites = false;

  getMany(_appId: string, hashes: string[], model: string): Promise<Map<string, number[]>> {
    if (this.failReads) return Promise.reject(new Error("cache down"));
    const out = new Map<string, number[]>();
    for (const h of hashes) {
      const hit = this.store.get(`${model}:${h}`);
      if (hit) out.set(h, hit);
    }
    return Promise.resolve(out);
  }

  put(_appId: string, hash: string, model: string, embedding: number[]): Promise<void> {
    if (this.failWrites) return Promise.reject(new Error("cache down"));
    this.writes++;
    this.store.set(`${model}:${hash}`, embedding);
    return Promise.resolve();
  }
}

/** Counts calls and returns a vector derived from the text, so a wrong-order
 *  result is detectable rather than merely suspicious. */
class CountingProvider implements EmbeddingProvider {
  calls = 0;
  embeddedTexts: string[][] = [];
  readonly dimensions = 2;
  readonly id = "test-model";

  embed(texts: string[]): Promise<number[][]> {
    this.calls++;
    this.embeddedTexts.push(texts);
    return Promise.resolve(texts.map((t) => [t.length, t.charCodeAt(0)]));
  }
}

Deno.test("second ask of the same question never reaches the provider", async () => {
  const inner = new CountingProvider();
  const cache = new FakeCache();
  const provider = new CachingEmbeddingProvider(inner, cache, APP);

  const first = await provider.embed(["ما حكم صلاة الجماعة؟"]);
  const second = await provider.embed(["ما حكم صلاة الجماعة؟"]);

  assertEquals(first, second);
  assertEquals(inner.calls, 1, "the provider should have been called exactly once");
  assertEquals(cache.writes, 1);
});

Deno.test("questions differing only in normalisation share one cache entry", async () => {
  const inner = new CountingProvider();
  const provider = new CachingEmbeddingProvider(inner, new FakeCache(), APP);

  await provider.embed(["ما حكم صلاة الجماعة"]);
  // Extra whitespace — normalizeArabic collapses it, so this must hit.
  await provider.embed(["ما   حكم  صلاة الجماعة"]);

  assertEquals(inner.calls, 1);
});

Deno.test("a partial hit embeds only the misses, and keeps input order", async () => {
  const inner = new CountingProvider();
  const cache = new FakeCache();
  const provider = new CachingEmbeddingProvider(inner, cache, APP);

  await provider.embed(["bbbb"]);
  const out = await provider.embed(["aaa", "bbbb", "ccccc"]);

  // Only the two misses went to the provider...
  assertEquals(inner.embeddedTexts[1], ["aaa", "ccccc"]);
  // ...and the results still line up with the caller's order, which is the
  // contract `embed` has and the thing an index-juggling merge can break.
  assertEquals(out, [[3, 97], [4, 98], [5, 99]]);
});

Deno.test("a different model misses rather than serving another model's vectors", async () => {
  const cache = new FakeCache();
  const a = new CountingProvider();
  await new CachingEmbeddingProvider(a, cache, APP).embed(["x"]);

  const b = new CountingProvider();
  Object.defineProperty(b, "id", { value: "other-model" });
  await new CachingEmbeddingProvider(b, cache, APP).embed(["x"]);

  assertEquals(b.calls, 1, "vectors are not comparable across models — must not be reused");
});

Deno.test("a broken cache degrades to slow, never to broken", async () => {
  const inner = new CountingProvider();
  const cache = new FakeCache();
  cache.failReads = true;
  cache.failWrites = true;
  const provider = new CachingEmbeddingProvider(inner, cache, APP);

  const out = await provider.embed(["x"]);

  assertEquals(out, [[1, 120]]);
  assertEquals(inner.calls, 1);
});

Deno.test("questionHash is stable and normalisation-insensitive", async () => {
  assertEquals(await questionHash("سؤال"), await questionHash("  سؤال  "));
  assertEquals((await questionHash("سؤال")).length, 64);
});
