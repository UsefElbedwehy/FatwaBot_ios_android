import { assert, assertAlmostEquals, assertEquals } from "jsr:@std/assert@1";
import {
  hybridRetrieve,
  penalizeShattered,
  reciprocalRankFusion,
  stripQuestionFrame,
} from "../functions/api/ai_search/retrieval.ts";
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
    ocrShattered: false,
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

// --- 0050: question frame, OCR penalty, hadith leg ---

Deno.test("stripQuestionFrame drops the words that frame a question and keeps its subject", () => {
  // Measured on the corpus: the frame words gated «حلق اللحية» to 34 chunks
  // out of the 61 that discuss it, because FTS ANDs every token.
  assertEquals(stripQuestionFrame("ما حكم حلق اللحية؟"), "حلق اللحية؟");
  assertEquals(stripQuestionFrame("هل يجوز للمحرم لبس الكمامة؟"), "للمحرم لبس الكمامة؟");
  assertEquals(stripQuestionFrame("ما صحة حديث الجنة تحت أقدام الأمهات"), "الجنة تحت أقدام الأمهات");
});

Deno.test("stripQuestionFrame falls back to the original when nothing but frame remains", () => {
  assertEquals(stripQuestionFrame("ما حكم؟"), "ما حكم؟");
});

Deno.test("the FTS leg gets the stripped question; the vector leg gets the whole one", async () => {
  const repo = new InMemoryFatwaSearchRepo();
  const embedder = new DevStubEmbeddingProvider(16);
  const seen: string[] = [];
  const fts = repo.ftsSearch.bind(repo);
  repo.ftsSearch = (ctx, query, n) => {
    seen.push(query);
    return fts(ctx, query, n);
  };
  const embedded: string[] = [];
  const embed = embedder.embed.bind(embedder);
  embedder.embed = (texts) => {
    embedded.push(...texts);
    return embed(texts);
  };
  repo.seed([seed({ chunkId: "x", text: "حلق اللحية" })]);
  await hybridRetrieve(CTX, repo, embedder, "ما حكم حلق اللحية؟");
  assertEquals(seen, ["حلق اللحية؟"]);
  assertEquals(
    embedded,
    ["ما حكم حلق اللحية؟"],
    "an embedding model wants the frame — it is what makes it a fatwa question",
  );
});

Deno.test("penalizeShattered ranks a readable chunk above a wrecked one that scored higher", () => {
  const ranked = penalizeShattered(
    [retrieved("wrecked", 0.030, { ocrShattered: true }), retrieved("clean", 0.020)],
    0.5,
  );
  assertEquals(ranked.map((c) => c.chunkId), ["clean", "wrecked"]);
  assertAlmostEquals(ranked[1].score, 0.015);
});

Deno.test("a shattered chunk both legs agree on still beats a readable one only one leg found", () => {
  // 0.5 is calibrated to exactly this: rank-1 in both legs (2/61) halved
  // equals rank-1 in one leg (1/61). Agreement of both legs at rank 1 plus any
  // margin wins; the wrecked chunk is penalised, never excluded.
  const ranked = penalizeShattered(
    [retrieved("wrecked", 2 / 61 + 1e-6, { ocrShattered: true }), retrieved("clean", 1 / 61)],
    0.5,
  );
  assertEquals(ranked[0].chunkId, "wrecked");
});

Deno.test("hadith mode adds the hadith leg and puts its hits first; other modes never call it", async () => {
  const repo = new InMemoryFatwaSearchRepo();
  const embedder = new DevStubEmbeddingProvider(16);
  const query = "الجنة تحت أقدام الأمهات";
  const [q] = await embedder.embed([query]);
  repo.seed([seed({ chunkId: "commentary", text: `شرح حديث ${query}`, embedding: q })]);
  repo.seedHadith([{
    id: "h-1",
    collectionId: "coll",
    collectionName: "سنن النسائي",
    number: 3104,
    arabicText: "الزم رجلها فثم الجنة — وأما اللفظ «الجنة تحت أقدام الأمهات» فلا أصل له",
    grading: "لا أصل له بهذا اللفظ",
  }]);
  const calls: string[] = [];
  const hadith = repo.hadithSearch.bind(repo);
  repo.hadithSearch = (...args) => {
    calls.push("hadith");
    return hadith(...args);
  };

  const inHadithMode = await hybridRetrieve(CTX, repo, embedder, query, { mode: "hadith" });
  assertEquals(calls, ["hadith"]);
  assertEquals(inHadithMode[0].chunkId, "h-1", "the matn and its grading lead; commentary follows");
  assertEquals(inHadithMode[0].sourceCategory, "hadith");
  assert(
    inHadithMode[0].text.includes("الدرجة: لا أصل له بهذا اللفظ"),
    "the grading is part of the quotable text",
  );
  assertEquals(inHadithMode[1].chunkId, "commentary");

  const inFatwaMode = await hybridRetrieve(CTX, repo, embedder, query, { mode: "fatwa" });
  assertEquals(calls, ["hadith"], "fatwa mode issued no hadith search");
  assertEquals(inFatwaMode.map((c) => c.chunkId), ["commentary"]);
});
