import { assert, assertEquals, assertNotEquals } from "jsr:@std/assert@1";
import { route } from "../functions/api/router.ts";
import { InMemoryConfigRepo } from "./in_memory_repo.ts";
import { InMemoryIdentityRepo } from "./in_memory_identity_repo.ts";
import { InMemoryContentRepo } from "./in_memory_content_repo.ts";
import {
  InMemoryAdminAuthRepo,
  InMemoryAdminContentRepo,
  InMemoryAdminUsersRepo,
  InMemoryAuditLogRepo,
} from "./in_memory_admin_repo.ts";
import { InMemoryAdminStringsRepo } from "./in_memory_admin_strings_repo.ts";
import { DevIdentityProviderVerifier } from "../functions/api/auth/provider_verify.ts";
import { InMemoryGamificationRepo } from "./in_memory_gamification_repo.ts";
import { InMemoryAnalyticsRepo } from "./in_memory_analytics_repo.ts";
import { InMemoryLeaderboardRepo } from "./in_memory_leaderboard_repo.ts";
import { InMemorySearchHistoryRepo } from "./in_memory_search_repo.ts";
import { InMemoryDeliveryLogRepo, InMemoryNotificationPrefsRepo } from "./in_memory_notification_repo.ts";
import { InMemoryFatwaSearchRepo, type SeedChunk } from "./in_memory_fatwa_repo.ts";
import {
  DevStubAnswerProvider,
  DevStubEmbeddingProvider,
  UpstreamError,
} from "../functions/api/ai_search/providers.ts";
import type { AnswerProvider } from "../functions/api/ai_search/providers.ts";
import type { AnswerResult, FatwaMode, RetrievedChunk } from "../functions/api/fatwa_types.ts";

const BASE = "https://x.supabase.co/functions/v1/api";
const SECRET = "test-secret";
const DEVICE = { platform: "ios", app_version: "1.0.0", locale: "ar", timezone: "Asia/Riyadh" };

function baseDeps() {
  return {
    repo: new InMemoryConfigRepo(),
    identity: new InMemoryIdentityRepo(),
    content: new InMemoryContentRepo(),
    adminContent: new InMemoryAdminContentRepo(),
    adminUsers: new InMemoryAdminUsersRepo(),
    adminAuth: new InMemoryAdminAuthRepo(),
    adminStrings: new InMemoryAdminStringsRepo(),
    auditLog: new InMemoryAuditLogRepo(),
    jwtSecret: SECRET,
    verifier: new DevIdentityProviderVerifier(),
    gamification: new InMemoryGamificationRepo(),
    analytics: new InMemoryAnalyticsRepo(),
    leaderboard: new InMemoryLeaderboardRepo(),
    searchHistory: new InMemorySearchHistoryRepo(),
    notificationPrefs: new InMemoryNotificationPrefsRepo(),
    deliveryLog: new InMemoryDeliveryLogRepo(),
    fatwaSearch: new InMemoryFatwaSearchRepo(),
  };
}

/** Wraps a fixed handler function as an AnswerProvider — for tests that
 *  need to inject a fabricated citation without going through the real
 *  ClaudeAnswerProvider's SDK client shape. */
class FixedAnswerProvider implements AnswerProvider {
  readonly id = "fixed-test-stub";
  constructor(private readonly handler: (chunks: RetrievedChunk[]) => AnswerResult) {}
  answer(_q: string, _mode: FatwaMode, chunks: RetrievedChunk[]): Promise<AnswerResult> {
    return Promise.resolve(this.handler(chunks));
  }
}

function seedChunk(over: Partial<SeedChunk> = {}): SeedChunk {
  return {
    chunkId: "chunk-1",
    documentId: "doc-1",
    sourceId: "source-1",
    scholarId: "scholar-1",
    text: "الوسط في الدين: أن لا يغلو الإنسان فيه ولا يقصر.",
    pageNumber: 25,
    videoTimestamp: null,
    sourceTitle: "فتاوى أركان الإسلام",
    sourceCategory: "الفتاوى واللقاءات",
    scholarName: { ar: "ابن عثيمين", en: "Ibn Uthaymeen" },
    embedding: [1, 0, 0, 0],
    ...over,
  };
}

function post(path: string, body?: unknown, headers: HeadersInit = {}): Request {
  return new Request(`${BASE}${path}`, {
    method: "POST",
    headers: { "content-type": "application/json", ...headers },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
}

async function signIn(d: ReturnType<typeof baseDeps>) {
  return await (await route(post("/v1/auth/anonymous", { device: DEVICE }), d)).json();
}

Deno.test("POST /v1/search requires auth", async () => {
  const d = baseDeps();
  const res = await route(post("/v1/search", { question: "ما حكم كذا", mode: "general" }), d);
  assertEquals(res.status, 401);
});

Deno.test("POST /v1/search rejects an invalid mode", async () => {
  const d = baseDeps();
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };
  const res = await route(post("/v1/search", { question: "سؤال", mode: "bogus" }, auth), d);
  assertEquals(res.status, 400);
});

Deno.test("POST /v1/search rejects an empty question", async () => {
  const d = baseDeps();
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };
  const res = await route(post("/v1/search", { question: "   ", mode: "general" }, auth), d);
  assertEquals(res.status, 400);
});

Deno.test("POST /v1/search returns 503 ai_unavailable when providers are not configured", async () => {
  const d = baseDeps();
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };
  const res = await route(post("/v1/search", { question: "سؤال", mode: "general" }, auth), d);
  assertEquals(res.status, 503);
  const json = await res.json();
  assertEquals(json.error.code, "ai_unavailable");
});

Deno.test("POST /v1/search returns a grounded, cited answer on the happy path", async () => {
  const d = {
    ...baseDeps(),
    embeddingProvider: new DevStubEmbeddingProvider(4),
    answerProvider: new DevStubAnswerProvider(),
  };
  d.fatwaSearch.seed([seedChunk()]);
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };

  const res = await route(
    post("/v1/search", { question: "ما معنى الوسط في الدين؟", mode: "fatwa" }, auth),
    d,
  );
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.mode, "fatwa");
  assertEquals(body.refused, false);
  assertEquals(body.citations.length, 1);
  assertEquals(body.citations[0].chunk_id, "chunk-1");
  assertEquals(body.citations[0].page_number, 25);

  // Logged to fatwa.answers_log...
  assertEquals(d.fatwaSearch.loggedAnswers.length, 1);
  assertEquals(d.fatwaSearch.loggedAnswers[0].mode, "fatwa");
  assertEquals(d.fatwaSearch.loggedAnswers[0].refused, false);
  // ...and to the existing per-user search history, under the mode's source.
  const history = await d.searchHistory.list(
    { appId: "app", platform: "all", appVersion: null, locale: "ar" },
    user.user_id,
    null,
    10,
    null,
  );
  assertEquals(history.length, 1);
  assertEquals(history[0].source, "ai_fatwa");
});

Deno.test("POST /v1/search refuses (200, not an error) when retrieval finds nothing", async () => {
  const d = {
    ...baseDeps(),
    embeddingProvider: new DevStubEmbeddingProvider(4),
    answerProvider: new DevStubAnswerProvider(),
  };
  // No chunks seeded — retrieval returns empty, dev-stub answerer refuses.
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };

  const res = await route(post("/v1/search", { question: "سؤال بلا مصدر", mode: "general" }, auth), d);
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.refused, true);
  assertEquals(body.citations.length, 0);
  assertEquals(body.answer.length > 0, true, "a refusal still carries a localized message");
});

Deno.test("POST /v1/search drops a fabricated citation and flips to refused, never shipping it", async () => {
  const fabricatingProvider = new FixedAnswerProvider((chunks) => ({
    answer: "إجابة مبنية على استشهاد ملفّق.",
    refused: false,
    citations: [{
      chunkId: chunks[0].chunkId,
      scholar: "ابن عثيمين",
      sourceTitle: chunks[0].sourceTitle,
      pageNumber: chunks[0].pageNumber ?? undefined,
      quotedText: "نص ملفّق لا يظهر في المصدر إطلاقاً",
    }],
    model: "fixed-test-stub",
  }));
  const d = {
    ...baseDeps(),
    embeddingProvider: new DevStubEmbeddingProvider(4),
    answerProvider: fabricatingProvider,
  };
  d.fatwaSearch.seed([seedChunk()]);
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };

  const res = await route(
    post("/v1/search", { question: "ما معنى الوسط في الدين؟", mode: "general" }, auth),
    d,
  );
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.refused, true, "the only citation failed verification, so the whole answer refuses");
  assertEquals(body.citations.length, 0, "a fabricated citation must never reach the client");
});

Deno.test("POST /v1/search keeps a self-refusal's own message when it carries a verified citation (hadith closest-match)", async () => {
  const closestMatchProvider = new FixedAnswerProvider((chunks) => ({
    answer: "لم يرد الحديث بهذا اللفظ، لكن أقرب لفظ صحيح هو ما يلي.",
    refused: true,
    citations: [{
      chunkId: chunks[0].chunkId,
      scholar: "ابن عثيمين",
      sourceTitle: chunks[0].sourceTitle,
      pageNumber: chunks[0].pageNumber ?? undefined,
      quotedText: chunks[0].text,
    }],
    model: "fixed-test-stub",
  }));
  const d = {
    ...baseDeps(),
    embeddingProvider: new DevStubEmbeddingProvider(4),
    answerProvider: closestMatchProvider,
  };
  d.fatwaSearch.seed([seedChunk()]);
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };

  const res = await route(
    post("/v1/search", { question: "نص حديث بصياغة غير دقيقة", mode: "hadith" }, auth),
    d,
  );
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.refused, true, "the model's own refusal (exact wording not found) is preserved");
  assertEquals(
    body.answer,
    "لم يرد الحديث بهذا اللفظ، لكن أقرب لفظ صحيح هو ما يلي.",
    "a self-refusal's own message must reach the user, not the generic fallback, when it has real support",
  );
  assertEquals(body.citations.length, 1, "the verified closest-match citation must still be shown");
});

Deno.test("POST /v1/search returns a video-sourced citation with its timestamp and a null page", async () => {
  const videoCitingProvider = new FixedAnswerProvider((chunks) => ({
    answer: "الجواب من مادة مرئية.",
    refused: false,
    citations: [{
      chunkId: chunks[0].chunkId,
      scholar: "ابن عثيمين",
      sourceTitle: chunks[0].sourceTitle,
      videoTimestamp: chunks[0].videoTimestamp ?? undefined,
      quotedText: chunks[0].text,
    }],
    model: "fixed-test-stub",
  }));
  const d = {
    ...baseDeps(),
    embeddingProvider: new DevStubEmbeddingProvider(4),
    answerProvider: videoCitingProvider,
  };
  // Exactly one locator, mirroring the DB's chunks_exactly_one_locator check.
  d.fatwaSearch.seed([seedChunk({ pageNumber: null, videoTimestamp: 930 })]);
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };

  const res = await route(
    post("/v1/search", { question: "ما معنى الوسط في الدين؟", mode: "general" }, auth),
    d,
  );
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.refused, false);
  assertEquals(body.citations.length, 1);
  assertEquals(body.citations[0].video_timestamp, 930);
  assertEquals(body.citations[0].page_number, null, "a video source has no page to report");
});

Deno.test("POST /v1/search falls back to the generic refusal message when a self-refusal has no verifiable support", async () => {
  const bareRefusalProvider = new FixedAnswerProvider(() => ({
    answer: "",
    refused: true,
    citations: [],
    model: "fixed-test-stub",
  }));
  const d = {
    ...baseDeps(),
    embeddingProvider: new DevStubEmbeddingProvider(4),
    answerProvider: bareRefusalProvider,
  };
  d.fatwaSearch.seed([seedChunk()]);
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };

  const res = await route(post("/v1/search", { question: "سؤال بلا مطابقة", mode: "hadith" }, auth), d);
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.refused, true);
  assertEquals(
    body.answer.length > 0,
    true,
    "still carries a localized refusal message, not an empty string",
  );
});

// A 500 that says only "internal_error" is undiagnosable from the client, and
// on a deployment whose logs you can't reach, undiagnosable full stop. Each
// stage now reports which one failed.

Deno.test("POST /v1/search reports embedding_failed, naming the upstream status", async () => {
  const d = {
    ...baseDeps(),
    embeddingProvider: {
      embed: () => Promise.reject(new UpstreamError("voyage", 429, "rate limited")),
      id: "broken",
    } as unknown as DevStubEmbeddingProvider,
    answerProvider: new DevStubAnswerProvider(),
  };
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };
  const res = await route(post("/v1/search", { question: "سؤال", mode: "fatwa" }, auth), d);
  assertEquals(res.status, 502);
  const body = await res.json();
  assertEquals(body.error.code, "embedding_failed");
  // The status is the whole point — 429 is a quota problem, 401 a bad key.
  assertEquals(body.error.message.includes("voyage 429"), true);
});

Deno.test("POST /v1/search reports retrieval_failed when the SQL search stage throws", async () => {
  const d = {
    ...baseDeps(),
    embeddingProvider: new DevStubEmbeddingProvider(4),
    answerProvider: new DevStubAnswerProvider(),
  };
  // Every search has to fail for retrieval to be fatal — see the degraded-mode
  // test below.
  // Both legs — there is no third since the trigram leg was retired (0047).
  const dead = () => Promise.reject(new Error("function fatwa.search_vector does not exist"));
  d.fatwaSearch.vectorSearch = dead;
  d.fatwaSearch.ftsSearch = dead;
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };
  const res = await route(post("/v1/search", { question: "سؤال", mode: "fatwa" }, auth), d);
  assertEquals(res.status, 502);
  const body = await res.json();
  assertEquals(body.error.code, "retrieval_failed");
  // Names which searches died, so a production failure says where.
  assertEquals(body.error.message.includes("vector"), true);
});

Deno.test("POST /v1/search reports answer_failed when the model stage throws", async () => {
  const d = {
    ...baseDeps(),
    embeddingProvider: new DevStubEmbeddingProvider(4),
    answerProvider: {
      answer: () => Promise.reject(new Error("anthropic 500")),
      id: "broken",
    } as unknown as DevStubAnswerProvider,
  };
  d.fatwaSearch.seed([seedChunk()]);
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };
  const res = await route(post("/v1/search", { question: "سؤال", mode: "fatwa" }, auth), d);
  assertEquals(res.status, 502);
  assertEquals((await res.json()).error.code, "answer_failed");
});

Deno.test("POST /v1/search still returns the answer when only the audit log write fails", async () => {
  const d = {
    ...baseDeps(),
    embeddingProvider: new DevStubEmbeddingProvider(4),
    answerProvider: new DevStubAnswerProvider(),
  };
  d.fatwaSearch.seed([seedChunk()]);
  d.fatwaSearch.logAnswer = () => Promise.reject(new Error("answers_log insert failed"));
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };
  const res = await route(
    post("/v1/search", { question: "ما معنى الوسط في الدين؟", mode: "fatwa" }, auth),
    d,
  );
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.refused, false);
  assertEquals(body.citations.length, 1);
});

Deno.test("POST /v1/search still answers when only one of the three searches fails", async () => {
  const d = {
    ...baseDeps(),
    embeddingProvider: new DevStubEmbeddingProvider(4),
    answerProvider: new DevStubAnswerProvider(),
  };
  d.fatwaSearch.seed([seedChunk()]);
  // The vector index is the one that times out in production; FTS returns fine.
  // Losing the whole request over that threw away results we already had.
  d.fatwaSearch.vectorSearch = () =>
    Promise.reject(new Error("canceling statement due to statement timeout"));
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };
  const res = await route(
    post("/v1/search", { question: "ما معنى الوسط في الدين؟", mode: "fatwa" }, auth),
    d,
  );
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.refused, false);
  assertEquals(body.citations.length, 1);
});

// --- Whole-answer cache (0046) -------------------------------------------

/** Keyed exactly as the Postgres table is, so a test that passes here is
 *  testing the same key the production repo uses. */
class FakeAnswerCache {
  readonly store = new Map<string, unknown>();
  generation = 1;
  private readonly generationAtWrite = new Map<string, number>();
  failReads = false;

  private key(ctx: { appId: string }, hash: string, mode: string, model: string) {
    return [ctx.appId, hash, mode, model].join("|");
  }

  get(ctx: { appId: string }, hash: string, mode: string, model: string): Promise<unknown | null> {
    if (this.failReads) return Promise.reject(new Error("cache down"));
    const k = this.key(ctx, hash, mode, model);
    if (this.generationAtWrite.get(k) !== this.generation) return Promise.resolve(null);
    return Promise.resolve(this.store.get(k) ?? null);
  }

  put(ctx: { appId: string }, hash: string, mode: string, model: string, response: unknown): Promise<void> {
    const k = this.key(ctx, hash, mode, model);
    this.store.set(k, response);
    this.generationAtWrite.set(k, this.generation);
    return Promise.resolve();
  }
}

function cachingDeps() {
  const answerCache = new FakeAnswerCache();
  const d = {
    ...baseDeps(),
    embeddingProvider: new DevStubEmbeddingProvider(4),
    answerProvider: new DevStubAnswerProvider(),
    answerCache,
  };
  d.fatwaSearch.seed([seedChunk()]);
  return { d, answerCache };
}

Deno.test("a repeated question is served from cache without re-running the pipeline", async () => {
  const { d } = cachingDeps();
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };
  const ask = () =>
    route(post("/v1/search", { question: "ما معنى الوسط في الدين؟", mode: "fatwa" }, auth), d);

  const first = await ask();
  const firstBody = await first.json();
  const second = await ask();

  assertEquals(second.status, 200);
  assertEquals(await second.json(), firstBody, "a hit must be byte-identical to the miss");
  // The expensive stages ran exactly once.
  assertEquals(d.fatwaSearch.loggedAnswers.length, 1);
  assertEquals(second.headers.get("server-timing"), "cache;dur=0");
});

Deno.test("a cache hit still records the ask in search history", async () => {
  const { d } = cachingDeps();
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };
  const ask = () => route(post("/v1/search", { question: "سؤال متكرر", mode: "fatwa" }, auth), d);

  await ask();
  await ask();

  // Two asks, two history rows — a user's history should not have holes in it
  // exactly where they repeated themselves.
  const history = await d.searchHistory.list(
    { appId: "app", platform: "all", appVersion: null, locale: "ar" },
    user.user_id,
    null,
    10,
    null,
  );
  assertEquals(history.length, 2);
});

Deno.test("the same question in another mode is a different cache entry", async () => {
  const { d } = cachingDeps();
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };

  await route(post("/v1/search", { question: "س", mode: "fatwa" }, auth), d);
  await route(post("/v1/search", { question: "س", mode: "hadith" }, auth), d);

  // A different mode is a different prompt, so it must not reuse the answer.
  assertEquals(d.fatwaSearch.loggedAnswers.length, 2);
});

Deno.test("ingesting more corpus invalidates cached answers", async () => {
  const { d, answerCache } = cachingDeps();
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };
  const ask = () => route(post("/v1/search", { question: "س", mode: "fatwa" }, auth), d);

  await ask();
  await ask();
  assertEquals(d.fatwaSearch.loggedAnswers.length, 1);

  // The ingester bumps the generation. A question refused against the old
  // corpus must be re-asked against the new one rather than serving the
  // refusal forever.
  answerCache.generation = 2;
  await ask();
  assertEquals(d.fatwaSearch.loggedAnswers.length, 2);
});

Deno.test("a broken answer cache degrades to slow, never to broken", async () => {
  const { d, answerCache } = cachingDeps();
  answerCache.failReads = true;
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };

  const res = await route(
    post("/v1/search", { question: "ما معنى الوسط في الدين؟", mode: "fatwa" }, auth),
    d,
  );

  assertEquals(res.status, 200);
  assertEquals((await res.json()).citations.length, 1);
});

// --- Structured result contract (M5.1) -----------------------------------

Deno.test("a search returns the structured card fields, not just prose", async () => {
  const d = {
    ...baseDeps(),
    embeddingProvider: new DevStubEmbeddingProvider(4),
    answerProvider: new DevStubAnswerProvider(),
  };
  d.fatwaSearch.seed([seedChunk()]);
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };

  const res = await route(
    post("/v1/search", { question: "ما معنى الوسط في الدين؟", mode: "fatwa" }, auth),
    d,
  );
  const body = await res.json();

  assertEquals(typeof body.summary, "string");
  assertEquals(body.ruling, "halal");
  assertEquals(body.scholar_answers.length, 1);
  assertEquals(body.scholar_answers[0].scholar, "ابن عثيمين");
  // `answer` stays populated so a client built against the old shape still
  // renders something.
  assertEquals(typeof body.answer, "string");
});

Deno.test("resources report every kind, so 'not available' is stated rather than omitted", async () => {
  const d = {
    ...baseDeps(),
    embeddingProvider: new DevStubEmbeddingProvider(4),
    answerProvider: new DevStubAnswerProvider(),
  };
  d.fatwaSearch.seed([seedChunk()]);
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };

  const res = await route(
    post("/v1/search", { question: "ما معنى الوسط في الدين؟", mode: "fatwa" }, auth),
    d,
  );
  const body = await res.json();

  assertEquals(body.resources.map((r: { kind: string }) => r.kind), ["book", "video", "website"]);
  // The corpus is books only, so the honest answer for the other two is "no".
  assertEquals(body.resources.find((r: { kind: string }) => r.kind === "book").available, true);
  assertEquals(body.resources.find((r: { kind: string }) => r.kind === "video").available, false);
  assertEquals(body.resources.find((r: { kind: string }) => r.kind === "website").available, false);
});

Deno.test("a video source makes the video resource available, with its url", async () => {
  const d = {
    ...baseDeps(),
    embeddingProvider: new DevStubEmbeddingProvider(4),
    answerProvider: new DevStubAnswerProvider(),
  };
  d.fatwaSearch.seed([{
    ...seedChunk(),
    pageNumber: null,
    videoTimestamp: 512,
    sourceKind: "video",
    sourceUrl: "https://example.test/lecture",
  }]);
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };

  const res = await route(
    post("/v1/search", { question: "ما معنى الوسط في الدين؟", mode: "fatwa" }, auth),
    d,
  );
  const body = await res.json();

  const video = body.resources.find((r: { kind: string }) => r.kind === "video");
  assertEquals(video.available, true);
  assertEquals(video.url, "https://example.test/lecture");
  // Derived from the source row, never from the model — a model asked whether
  // something is on YouTube will happily say yes.
  assertEquals(body.resources.find((r: { kind: string }) => r.kind === "book").available, false);
});

Deno.test("fabricated evidence blanks the structured fields too, not just the prose", async () => {
  const d = {
    ...baseDeps(),
    embeddingProvider: new DevStubEmbeddingProvider(4),
    answerProvider: {
      id: "fabricator",
      answer: () =>
        Promise.resolve({
          answer: "إجابة مبنية على استشهاد مختلق",
          summary: "خلاصة مبنية على استشهاد مختلق",
          ruling: "haram" as const,
          scholarAnswers: [{ scholar: "ابن عثيمين", answer: "قول منسوب زوراً" }],
          citations: [{
            chunkId: "chunk-1",
            scholar: "ابن عثيمين",
            sourceTitle: "كتاب",
            quotedText: "نص لا وجود له في أي مقطع",
          }],
          refused: false,
          model: "fabricator",
        }),
    } as unknown as DevStubAnswerProvider,
  };
  d.fatwaSearch.seed([seedChunk()]);
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };

  const res = await route(post("/v1/search", { question: "سؤال", mode: "fatwa" }, auth), d);
  const body = await res.json();

  // Keeping the summary or the scholar card would leave the fabrication on
  // screen in a different shape, and `haram` would still colour a status dot.
  assertEquals(body.refused, true);
  assertEquals(body.citations.length, 0);
  assertEquals(body.summary, null);
  assertEquals(body.scholar_answers.length, 0);
  assertEquals(body.ruling, "none");
});

Deno.test("a refusal is never cached — it is more often an accident than a fact", async () => {
  // Built without seeding — `seed` appends, so there is no way to un-seed the
  // chunk cachingDeps() adds. Nothing retrievable means the provider refuses.
  const d = {
    ...baseDeps(),
    embeddingProvider: new DevStubEmbeddingProvider(4),
    answerProvider: new DevStubAnswerProvider(),
    answerCache: new FakeAnswerCache(),
  };
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };
  const ask = () => route(post("/v1/search", { question: "سؤال بلا مصدر", mode: "fatwa" }, auth), d);

  const first = await ask();
  assertEquals((await first.json()).refused, true);
  const second = await ask();

  // Re-run, not served from cache: a truncated generation or a timed-out
  // retrieval leg would otherwise freeze a spurious "no answer" in place for
  // the whole corpus generation.
  assertNotEquals(second.headers.get("server-timing"), "cache;dur=0");
});

// --- 0050: the log says why a refusal happened ---

Deno.test("a refusal caused by the verifier is logged as all_citations_dropped, with the dropped citations", async () => {
  const fabricatingProvider = new FixedAnswerProvider((chunks) => ({
    answer: "إجابة مبنية على استشهاد ملفّق.",
    refused: false,
    citations: [{
      chunkId: chunks[0].chunkId,
      scholar: "ابن عثيمين",
      sourceTitle: chunks[0].sourceTitle,
      quotedText: "نص ملفّق لا يظهر في المصدر إطلاقاً بأي صورة",
    }],
    model: "fixed-test-stub",
  }));
  const d = {
    ...baseDeps(),
    embeddingProvider: new DevStubEmbeddingProvider(4),
    answerProvider: fabricatingProvider,
  };
  d.fatwaSearch.seed([seedChunk()]);
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };
  await route(post("/v1/search", { question: "ما معنى الوسط في الدين؟", mode: "general" }, auth), d);

  const logged = d.fatwaSearch.loggedAnswers[0];
  assertEquals(logged.refused, true);
  assertEquals(logged.refusalReason, "all_citations_dropped");
  assertEquals(logged.droppedCitations.length, 1, "what the model claimed is kept for QA, never shown");
  assertEquals(logged.citations.length, 0);
});

Deno.test("a refusal the model chose itself is logged as model_refused", async () => {
  const d = {
    ...baseDeps(),
    embeddingProvider: new DevStubEmbeddingProvider(4),
    answerProvider: new FixedAnswerProvider(() => ({
      answer: "",
      refused: true,
      citations: [],
      model: "fixed-test-stub",
    })),
  };
  d.fatwaSearch.seed([seedChunk()]);
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };
  await route(post("/v1/search", { question: "سؤال", mode: "general" }, auth), d);
  assertEquals(d.fatwaSearch.loggedAnswers[0].refusalReason, "model_refused");
});

Deno.test("an answered search logs no refusal reason", async () => {
  const d = {
    ...baseDeps(),
    embeddingProvider: new DevStubEmbeddingProvider(4),
    answerProvider: new DevStubAnswerProvider(),
  };
  d.fatwaSearch.seed([seedChunk()]);
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };
  await route(post("/v1/search", { question: "ما معنى الوسط في الدين؟", mode: "general" }, auth), d);
  assertEquals(d.fatwaSearch.loggedAnswers[0].refusalReason, null);
  assertEquals(d.fatwaSearch.loggedAnswers[0].droppedCitations.length, 0);
});

Deno.test("hadith mode answers from the hadith collections, citing the matn and its grading", async () => {
  const d = {
    ...baseDeps(),
    embeddingProvider: new DevStubEmbeddingProvider(4),
    answerProvider: new DevStubAnswerProvider(),
  };
  d.fatwaSearch.seed([seedChunk()]);
  d.fatwaSearch.seedHadith([{
    id: "h-1",
    collectionId: "coll",
    collectionName: "سنن النسائي",
    number: 3104,
    arabicText: "الجنة تحت أقدام الأمهات",
    grading: "لا أصل له بهذا اللفظ",
  }]);
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };
  const res = await route(
    post("/v1/search", { question: "ما صحة حديث الجنة تحت أقدام الأمهات", mode: "hadith" }, auth),
    d,
  );
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.refused, false);
  assertEquals(body.citations[0].source_title, "سنن النسائي");
  assertEquals(body.citations[0].page_number, 3104, "a hadith's locator is its number in the collection");
  assert(body.citations[0].quoted_text.includes("الدرجة: لا أصل له بهذا اللفظ"));
});

Deno.test("citation locators come from the retrieved chunk, not from the model", async () => {
  const forgetfulProvider = new FixedAnswerProvider((chunks) => ({
    answer: "",
    summary: "خلاصة",
    scholarAnswers: [],
    refused: false,
    // No pageNumber at all — the model dropped it, as it did for a hadith
    // entry whose locator the prompt calls «رقم» rather than «صفحة».
    citations: [{
      chunkId: chunks[0].chunkId,
      scholar: "x",
      sourceTitle: chunks[0].sourceTitle,
      quotedText: chunks[0].text,
    }],
    model: "fixed-test-stub",
  }));
  const d = {
    ...baseDeps(),
    embeddingProvider: new DevStubEmbeddingProvider(4),
    answerProvider: forgetfulProvider,
  };
  d.fatwaSearch.seed([seedChunk({ pageNumber: 69 })]);
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };
  const body = await (await route(post("/v1/search", { question: "س", mode: "fatwa" }, auth), d)).json();
  assertEquals(body.citations[0].page_number, 69);
});

Deno.test("hadith mode builds the takhrij card from the cited entry when the model omits it", async () => {
  const cardlessProvider = new FixedAnswerProvider((chunks) => ({
    answer: "",
    summary: "الحديث صحيح.",
    scholarAnswers: [],
    refused: false,
    citations: [{
      chunkId: chunks[0].chunkId,
      scholar: "x",
      sourceTitle: chunks[0].sourceTitle,
      quotedText: "إنما الأعمال بالنيات",
    }],
    model: "fixed-test-stub",
  }));
  const d = {
    ...baseDeps(),
    embeddingProvider: new DevStubEmbeddingProvider(4),
    answerProvider: cardlessProvider,
  };
  d.fatwaSearch.seedHadith([{
    id: "h-1",
    collectionId: "coll",
    collectionName: "صحيح البخاري",
    number: 1,
    arabicText: "إنما الأعمال بالنيات",
    grading: "Sahih",
  }]);
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };
  const body =
    await (await route(post("/v1/search", { question: "إنما الأعمال بالنيات", mode: "hadith" }, auth), d))
      .json();
  assertEquals(body.hadith, {
    text: "إنما الأعمال بالنيات",
    grade: "Sahih",
    source: "صحيح البخاري (رقم 1)",
    scholar_verdicts: null,
  });
});

Deno.test("a non-refusal with nothing to show is returned but never cached", async () => {
  let calls = 0;
  const stoppedShort = new FixedAnswerProvider((chunks) => {
    calls++;
    return {
      answer: "",
      summary: "",
      scholarAnswers: [],
      refused: false,
      citations: [{
        chunkId: chunks[0].chunkId,
        scholar: "x",
        sourceTitle: chunks[0].sourceTitle,
        quotedText: chunks[0].text,
      }],
      model: "fixed-test-stub",
    };
  });
  const d = {
    ...baseDeps(),
    embeddingProvider: new DevStubEmbeddingProvider(4),
    answerProvider: stoppedShort,
    answerCache: new FakeAnswerCache(),
  };
  d.fatwaSearch.seed([seedChunk()]);
  const user = await signIn(d);
  const auth = { authorization: `Bearer ${user.access_token}` };
  const first = await (await route(post("/v1/search", { question: "س", mode: "fatwa" }, auth), d)).json();
  assertEquals(first.refused, false);
  assertEquals(first.citations.length, 1, "what it did find is still handed over");
  await route(post("/v1/search", { question: "س", mode: "fatwa" }, auth), d);
  assertEquals(calls, 2, "the second ask re-ran the model rather than replaying the empty body");
});
