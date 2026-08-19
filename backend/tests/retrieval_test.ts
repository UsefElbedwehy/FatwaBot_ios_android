import { assert, assertAlmostEquals, assertEquals } from "jsr:@std/assert@1";
import { hybridRetrieve, reciprocalRankFusion } from "../functions/api/ai_search/retrieval.ts";
import { DevStubEmbeddingProvider } from "../functions/api/ai_search/providers.ts";
import { InMemoryFatwaSearchRepo, type SeedChunk } from "./in_memory_fatwa_repo.ts";
import type { AppContext } from "../functions/api/types.ts";
import type { RetrievedChunk } from "../functions/api/fatwa_types.ts";

const CTX: AppContext = { appId: "app-1", platform: "all", appVersion: null, locale: "ar" };

function retrieved(chunkId: string, score: number, over: Partial<RetrievedChunk> = {}): RetrievedChunk {
  return {
    chunkId,
    documentId: "doc",
    sourceId: "source",
    scholarId: "scholar",
    text: "نص",
    pageNumber: 1,
    videoTimestamp: null,
    sourceTitle: "كتاب",
    sourceCategory: null,
    scholarName: { ar: "عالم" },
    score,
    ...over,
  };
}

function seed(over: Partial<SeedChunk>): SeedChunk {
  return {
    chunkId: "chunk",
    documentId: "doc",
    sourceId: "source",
    scholarId: "scholar",
    text: "نص",
    pageNumber: 1,
    videoTimestamp: null,
    sourceTitle: "كتاب",
    sourceCategory: null,
    scholarName: { ar: "عالم" },
    embedding: [0, 0, 0],
    ...over,
  };
}

// --- reciprocalRankFusion (pure) ---

Deno.test("a single list keeps its rank order with the standard RRF scores", () => {
  const list = [retrieved("a", 0.9), retrieved("b", 0.5), retrieved("c", 0.1)];
  const fused = reciprocalRankFusion([list], 60);
  assertEquals(fused.map((c) => c.chunkId), ["a", "b", "c"]);
  assertAlmostEquals(fused[0].score, 1 / 61);
  assertAlmostEquals(fused[1].score, 1 / 62);
  assertAlmostEquals(fused[2].score, 1 / 63);
});

Deno.test("a chunk ranked in multiple lists outranks one found in only a single list", () => {
  // "b" is #2 in both lists; "a" is #1 in only the first list.
  const listA = [retrieved("a", 1), retrieved("b", 0.5)];
  const listB = [retrieved("c", 1), retrieved("b", 0.5)];
  const fused = reciprocalRankFusion([listA, listB], 60);

  const byId = new Map(fused.map((c) => [c.chunkId, c.score]));
  assertAlmostEquals(byId.get("b")!, 1 / 62 + 1 / 62);
  assertAlmostEquals(byId.get("a")!, 1 / 61);
  assertAlmostEquals(byId.get("c")!, 1 / 61);
  // "b" appeared in both lists, so it should be fused-ranked above either
  // single-list-only chunk despite never being #1 anywhere.
  assertEquals(fused[0].chunkId, "b");
});

Deno.test("reciprocalRankFusion overwrites each chunk's raw per-list score with the fused score", () => {
  const fused = reciprocalRankFusion([[retrieved("a", 999)]], 60);
  assertAlmostEquals(fused[0].score, 1 / 61);
});

Deno.test("reciprocalRankFusion of no lists returns nothing", () => {
  assertEquals(reciprocalRankFusion([]), []);
});

// --- hybridRetrieve (integration, in-memory repo + dev-stub embedder) ---

Deno.test("hybridRetrieve only ever returns license-granted, active chunks", async () => {
  const repo = new InMemoryFatwaSearchRepo();
  const embedder = new DevStubEmbeddingProvider(16);
  const [q] = await embedder.embed(["ما حكم الصلاة"]);

  repo.seed([
    seed({ chunkId: "granted", text: "ما حكم الصلاة في السفر", embedding: q }),
    seed({
      chunkId: "not-granted",
      text: "ما حكم الصلاة في السفر",
      embedding: q,
      licenseGranted: false,
    }),
    seed({
      chunkId: "inactive-source",
      text: "ما حكم الصلاة في السفر",
      embedding: q,
      sourceActive: false,
    }),
  ]);

  const results = await hybridRetrieve(CTX, repo, embedder, "ما حكم الصلاة", "general");
  const ids = results.map((r) => r.chunkId);
  assert(ids.includes("granted"));
  assert(!ids.includes("not-granted"), "a pending/ungranted source must never be retrievable");
  assert(!ids.includes("inactive-source"), "an inactive source must never be retrievable");
});

Deno.test("only mode 'hadith' adds trigram search to the fusion", async () => {
  const repo = new InMemoryFatwaSearchRepo();
  const embedder = new DevStubEmbeddingProvider(16);
  // Deliberately dissimilar embedding, and every word carries different
  // tashkeel than the query so the (exact-string) FTS approximation scores
  // it 0 — but the underlying letters are unchanged, so char-trigram
  // similarity stays high. This is exactly mode 2's use case: a hadith
  // recalled with slightly different wording/vowelling than the source.
  const query = "الحديث بلفظ مقارب لما يحفظه السائل تقريبا";
  const trigramOnlyText = "الحديثِ بلفظٍ مقاربٍ لَما يحفظهُ السائلُ تقريباً";

  const [q] = await embedder.embed([query]);
  repo.seed([
    // Occupies vector search's only slot below, so the trigram-only chunk
    // can't slip in through vector search just because it's the only other
    // chunk in the (small, unrealistic) test corpus — vectorSearch has no
    // similarity floor and always returns its top-K, exactly like real
    // pgvector's `ORDER BY distance LIMIT N`.
    seed({ chunkId: "vector-decoy", text: "نص لا علاقة له بالسؤال إطلاقاً", embedding: q }),
    seed({
      chunkId: "trigram-only",
      text: trigramOnlyText,
      embedding: new Array(16).fill(-1), // maximally dissimilar to any real query embedding
    }),
  ]);

  const searchOpts = { vectorTopK: 1, ftsTopK: 1 };
  const hadithResults = await hybridRetrieve(CTX, repo, embedder, query, "hadith", searchOpts);
  const generalResults = await hybridRetrieve(CTX, repo, embedder, query, "general", searchOpts);

  assert(
    hadithResults.some((r) => r.chunkId === "trigram-only"),
    "mode 'hadith' should surface a trigram-only match",
  );
  assert(
    !generalResults.some((r) => r.chunkId === "trigram-only"),
    "mode 'general' must not run trigram search, so this chunk should be unreachable",
  );
});

Deno.test("hybridRetrieve truncates to finalTopN after fusion", async () => {
  const repo = new InMemoryFatwaSearchRepo();
  const embedder = new DevStubEmbeddingProvider(8);
  const [q] = await embedder.embed(["سؤال"]);

  repo.seed(
    Array.from({ length: 10 }, (_, i) =>
      seed({
        chunkId: `chunk-${i}`,
        text: `نص يحتوي على كلمة سؤال رقم ${i}`,
        embedding: q,
      })),
  );

  const results = await hybridRetrieve(CTX, repo, embedder, "سؤال", "general", { finalTopN: 3 });
  assertEquals(results.length, 3);
});
