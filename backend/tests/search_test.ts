import { assertEquals } from "jsr:@std/assert@1";
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
import { DevStubAnswerProvider, DevStubEmbeddingProvider } from "../functions/api/ai_search/providers.ts";
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
