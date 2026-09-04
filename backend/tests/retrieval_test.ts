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
    sourceKind: "book",
    sourceUrl: null,
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
    sourceKind: "book",
    sourceUrl: null,
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

  const results = await hybridRetrieve(CTX, repo, embedder, "ما حكم الصلاة");
  const ids = results.map((r) => r.chunkId);
  assert(ids.includes("granted"));
  assert(!ids.includes("not-granted"), "a pending/ungranted source must never be retrievable");
  assert(!ids.includes("inactive-source"), "an inactive source must never be retrievable");
});

Deno.test("retrieval issues exactly two searches — the trigram leg is retired", async () => {
  const repo = new InMemoryFatwaSearchRepo();
  const embedder = new DevStubEmbeddingProvider(16);
  const query = "الحديث بلفظ مقارب لما يحفظه السائل تقريبا";

  // Asserts on which legs ran rather than on which chunks came back: the point
  // is that there is no third round-trip, not what it would have returned.
  const calls: string[] = [];
  const [q] = await embedder.embed([query]);
  repo.seed([seed({ chunkId: "only", text: query, embedding: q })]);
  const vector = repo.vectorSearch.bind(repo);
  const fts = repo.ftsSearch.bind(repo);
  repo.vectorSearch = (...args) => {
    calls.push("vector");
    return vector(...args);
  };
  repo.ftsSearch = (...args) => {
    calls.push("fts");
    return fts(...args);
  };

  await hybridRetrieve(CTX, repo, embedder, query);

  // Retired in the database on 2026-09-04: whole-chunk trigram similarity had
  // to scan every chunk (30-60s) and its 70 MB index was dropped, so calling
  // it would be a guaranteed empty round-trip. Arabic recall is carried by
  // `fatwa.normalize_ar` inside FTS instead (0047).
  assertEquals(calls, ["vector", "fts"]);
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

  const results = await hybridRetrieve(CTX, repo, embedder, "سؤال", { finalTopN: 3 });
  assertEquals(results.length, 3);
});
